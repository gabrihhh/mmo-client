class_name Zone
extends Node3D
## Cena de uma zona do mundo: cria/remove os jogadores conforme o servidor e monta a HUD.
##
## É aberta pela tela de login depois do welcome (já conectado). Fluxo: cria quem já está em
## [method Network.get_players] e depois segue [signal Network.player_added] / [signal Network.player_removed].
## O próprio player id vira o [LocalPlayer]; os outros, [RemotePlayer].
## Se a conexão cair (ou o jogador sair pelo menu), volta para a tela de login, que mostra o motivo.
## Ao entrar numa zona de nível ([JOGO-18], [ZoneInfo]) mostra "Entrando em Nome (nv a-b)" no aviso do topo.

const LOCAL_PLAYER_SCENE: PackedScene = preload("res://scenes/player/local_player.tscn")
const REMOTE_PLAYER_SCENE: PackedScene = preload("res://scenes/player/remote_player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/world/training_dummy.tscn")
## Altura (m) acima da origem da entidade onde nascem os números de dano.
const _FLOATING_TEXT_HEIGHT: float = 2.9
## Para onde voltar quando a conexão cai.
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"

@onready var _players_root: Node3D = $Players
@onready var _hud: Hud = $Hud

var _local_player: LocalPlayer = null
var _remote_players: Dictionary[String, RemotePlayer] = {}
## Bonecos/monstros da zona (usam o mesmo script de desenho dos jogadores remotos).
var _npcs: Dictionary[String, RemotePlayer] = {}
## NPCs de serviço desenhados como cena fixa (o Ferreiro, [JOGO-16]), por id.
var _stations: Dictionary[String, Node3D] = {}
var _aim_preview: AimPreview = null
var _combat: CombatController = null
## Projéteis do servidor na tela, por id do evento "projectile" ([JOGO-08]).
var _projectiles: Dictionary[int, ProjectileVisual] = {}
## Lançamento atual de cada personagem (id → número que sobe a cada início/cancelamento): efeitos agendados
## para o fim do lançamento (clarão, projétil visual) só saem se o lançamento ainda for o mesmo ([JOGO-06]).
var _cast_serial: Dictionary[String, int] = {}
## Aviso no chão do lançamento atual de cada personagem (some na hora se for cancelado).
var _cast_warnings: Dictionary[String, GroundWarning] = {}
## Nível e XP do último snapshot (para mostrar "+20 XP" quando a XP sobe; −1 = ainda não recebeu).
var _last_level: int = -1
var _last_xp: float = 0.0
## Moedas no snapshot anterior (−1 = ainda nenhum): subiu → "+N moedas" acima de você ([JOGO-15]).
var _last_gold: int = -1
## Zona de nível onde o jogador estava no último snapshot ([JOGO-18]); "" = nenhuma (praça). "?" = ainda não sabe
## (a primeira vez não avisa: quem entra no jogo já está na praça).
var _last_region: String = "?"

## Altura (m) de onde os projéteis voam (mais ou menos a mão de quem lança).
const _PROJECTILE_HEIGHT: float = 1.3


func _ready() -> void:
	if Network.instance == null or not Network.instance.is_in_zone():
		# Aberta sem passar pelo login (ex.: F6 no editor): volta para lá.
		_back_to_login.call_deferred()
		return
	# A zona mudou enquanto esta cena carregava (ex.: voltou para a arena e a partida acabou na hora, [JOGO-28]):
	# abre a cena do tipo certo.
	if not scene_file_path.is_empty() and scene_file_path != Network.instance.zone_scene():
		_on_zone_changed(Network.instance.player_id)
		return
	# Modelos dos itens em segundo plano: sem engasgo quando alguém (ou o atirador de teste) veste um item novo.
	ItemModels.preload_all()
	Network.instance.player_added.connect(_on_player_added)
	Network.instance.player_removed.connect(_on_player_removed)
	# Outro welcome = o servidor trocou de zona (entrou/saiu da arena do Coliseu, [JOGO-28]): abre a cena certa.
	Network.instance.joined_zone.connect(_on_zone_changed)
	Network.instance.left_zone.connect(_on_left_zone)
	_hud.logout_requested.connect(_on_logout_requested)
	_hud.equip_requested.connect(Network.instance.send_equip)
	_hud.unequip_requested.connect(Network.instance.send_unequip)
	_hud.bag_move_requested.connect(Network.instance.send_bag_move)
	_hud.item_destroy_requested.connect(Network.instance.send_item_destroy)
	# Ferreiro ([JOGO-16]): melhorar vai ao servidor; o resultado volta para a tela dele.
	_hud.upgrade_requested.connect(Network.instance.send_upgrade)
	Network.instance.upgrade_result.connect(_hud.show_upgrade_result)
	# Tela de morte ([JOGO-21]): o relatório começa a roleta; "Renascer" vai ao servidor.
	Network.instance.death_report_received.connect(_hud.show_death)
	_hud.respawn_requested.connect(Network.instance.send_respawn)
	# Fusão no ferreiro ([JOGO-20]).
	_hud.fuse_requested.connect(Network.instance.send_fuse)
	Network.instance.fuse_result.connect(_hud.show_fuse_result)
	# Loja do Ferreiro ([JOGO-23]).
	_hud.shop_open_requested.connect(Network.instance.send_shop_open)
	_hud.shop_buy_requested.connect(Network.instance.send_shop_buy)
	_hud.shop_sell_requested.connect(Network.instance.send_shop_sell)
	Network.instance.shop_received.connect(_hud.show_shop)
	Network.instance.shop_result.connect(_hud.show_shop_result)
	# Mercado ([JOGO-25]).
	_hud.market_list_requested.connect(Network.instance.send_market_list)
	_hud.market_mine_requested.connect(Network.instance.send_market_mine)
	_hud.market_sell_requested.connect(Network.instance.send_market_sell)
	_hud.market_buy_requested.connect(Network.instance.send_market_buy)
	_hud.market_cancel_requested.connect(Network.instance.send_market_cancel)
	Network.instance.market_page_received.connect(_hud.show_market_page)
	Network.instance.market_mine_received.connect(_hud.show_market_mine)
	Network.instance.market_result.connect(_hud.show_market_result)
	Network.instance.market_sold.connect(_hud.show_market_sold)
	# Chat ([SOC-09]): mensagens para a HUD; as do Geral também viram balão em cima de quem falou (se está na tela).
	_hud.chat_send_requested.connect(Network.instance.send_chat)
	Network.instance.chat_received.connect(_on_chat_message)
	Network.instance.chat_refused.connect(_hud.show_chat_refused)
	# Armazém ([JOGO-26]): o armazém volta no próprio inventory.
	_hud.storage_put_requested.connect(Network.instance.send_storage_put)
	_hud.storage_take_requested.connect(Network.instance.send_storage_take)
	_hud.storage_buy_tab_requested.connect(Network.instance.send_storage_buy_tab)
	# Baús dos acampamentos ([JOGO-19]): abrir/pegar vão ao servidor; o que sobrou volta para a janela do baú.
	_hud.chest_open_requested.connect(Network.instance.send_chest_open)
	_hud.chest_take_requested.connect(Network.instance.send_chest_take)
	Network.instance.chest_loot_received.connect(_on_chest_loot)
	Network.instance.chest_changed.connect(_on_chest_changed)
	# Atributos de outro jogador (Menu → Jogadores Próximos, [SOC-02]).
	_hud.inspect_requested.connect(Network.instance.send_inspect)
	Network.instance.attributes_received.connect(_hud.show_attributes)
	# Grupo ([SOC-03]): convidar/responder/expulsar/sair vão ao servidor; estado, convites e avisos voltam para a HUD.
	_hud.group_invite_requested.connect(Network.instance.send_group_invite)
	_hud.group_answered.connect(Network.instance.send_group_answer)
	_hud.group_kick_requested.connect(Network.instance.send_group_kick)
	_hud.group_leave_requested.connect(Network.instance.send_group_leave)
	Network.instance.group_changed.connect(_on_group_changed)
	Network.instance.group_invited.connect(_hud.show_group_invite)
	Network.instance.group_notice.connect(_on_group_notice)
	# Amizade e Configuração social ([SOC-04]): pedir/responder/remover/configurar vão ao servidor; lista, pedidos,
	# avisos e a Configuração salva voltam para a HUD.
	_hud.friend_request_requested.connect(Network.instance.send_friend_request)
	_hud.friend_answered.connect(Network.instance.send_friend_answer)
	_hud.friend_remove_requested.connect(Network.instance.send_friend_remove)
	_hud.social_settings_requested.connect(Network.instance.send_social_settings)
	Network.instance.friends_changed.connect(_hud.set_friends)
	Network.instance.friend_requested.connect(_hud.show_friend_request)
	Network.instance.friend_notice.connect(_on_group_notice)
	Network.instance.social_settings_changed.connect(_hud.set_social_settings)
	# Guilda ([SOC-06]): criar/convidar/responder/sair/expulsar/cargo vão ao servidor; estado, convites e avisos voltam
	# para a HUD; a tag/cor de cada jogador acompanha (player_guild).
	_hud.guild_create_requested.connect(Network.instance.send_guild_create)
	_hud.guild_invite_requested.connect(Network.instance.send_guild_invite)
	_hud.guild_answered.connect(Network.instance.send_guild_answer)
	_hud.guild_leave_requested.connect(Network.instance.send_guild_leave)
	_hud.guild_kick_requested.connect(Network.instance.send_guild_kick)
	_hud.guild_role_requested.connect(Network.instance.send_guild_role)
	Network.instance.guild_changed.connect(_on_guild_changed)
	Network.instance.guild_invited.connect(_hud.show_guild_invite)
	Network.instance.guild_notice.connect(_on_group_notice)
	Network.instance.player_guild_changed.connect(_on_player_guild_changed)
	_hud.guild_list_requested.connect(Network.instance.send_guild_list)
	_hud.guild_info_requested.connect(Network.instance.send_guild_info)
	_hud.guild_join_requested.connect(Network.instance.send_guild_request)
	_hud.guild_request_answered.connect(Network.instance.send_guild_request_answer)
	_hud.guild_description_saved.connect(Network.instance.send_guild_description)
	Network.instance.guild_list_received.connect(_hud.show_guild_list)
	Network.instance.guild_info_received.connect(_hud.show_guild_info)
	# Ranking ([SOC-07]): a HUD pede a tabela; a resposta volta para ela.
	_hud.ranking_requested.connect(Network.instance.send_ranking_request)
	Network.instance.ranking_received.connect(_hud.show_ranking)
	# Loja premium ([JOGO-27]): a HUD pede/compra; estado, resultado e histórico voltam para ela.
	_hud.premium_open_requested.connect(Network.instance.send_premium_open)
	_hud.premium_buy_requested.connect(Network.instance.send_premium_buy)
	_hud.premium_pack_requested.connect(Network.instance.send_premium_pack)
	_hud.premium_history_requested.connect(Network.instance.send_premium_history)
	Network.instance.premium_received.connect(_hud.show_premium)
	Network.instance.premium_result.connect(_hud.show_premium_result)
	Network.instance.premium_history_received.connect(_hud.show_premium_history)
	if Network.instance.premium != null:
		_hud.show_premium(Network.instance.premium)
	# Troca ([SOC-05]): pedir/responder/oferta/confirmar/cancelar vão ao servidor; pedido, estado e fim voltam para a HUD.
	_hud.trade_request_requested.connect(Network.instance.send_trade_request)
	_hud.trade_answered.connect(Network.instance.send_trade_answer)
	_hud.trade_offer_changed.connect(Network.instance.send_trade_offer)
	_hud.trade_confirm_requested.connect(Network.instance.send_trade_confirm)
	_hud.trade_cancel_requested.connect(Network.instance.send_trade_cancel)
	Network.instance.trade_requested.connect(_hud.show_trade_request)
	Network.instance.trade_changed.connect(_hud.show_trade)
	Network.instance.trade_done.connect(func(partner_name: String) -> void: _hud.end_trade("Troca com %s feita!" % partner_name))
	Network.instance.trade_notice.connect(func(_code: String, message: String) -> void: _hud.end_trade(message))
	# Recusas que não são de login (ex.: mochila cheia) viram aviso na tela.
	Network.instance.server_error.connect(_on_server_error)
	# Coliseu ([JOGO-28]): Menu → Coliseu, fila, partida encontrada, placar e fim; na arena a HUD entra no modo arena
	# e as cores de aliado seguem o time.
	_hud.colosseum_open_requested.connect(Network.instance.send_colosseum_open)
	_hud.colosseum_queue_requested.connect(Network.instance.send_colosseum_queue)
	_hud.colosseum_leave_requested.connect(Network.instance.send_colosseum_leave)
	_hud.colosseum_answered.connect(Network.instance.send_colosseum_answer)
	_hud.colosseum_leave_match_requested.connect(Network.instance.send_colosseum_leave_match)
	Network.instance.colosseum_info_received.connect(_hud.show_colosseum_info)
	Network.instance.colosseum_found.connect(_hud.show_colosseum_found)
	Network.instance.colosseum_accept_status.connect(_hud.show_colosseum_accept_status)
	Network.instance.colosseum_cancelled.connect(_hud.show_colosseum_cancelled)
	Network.instance.colosseum_state_changed.connect(_on_colosseum_state)
	Network.instance.colosseum_result_received.connect(_hud.show_colosseum_result)
	_hud.set_arena_mode(Network.instance.is_arena())
	_hud.set_colosseum_state(Network.instance.colosseum_state)
	_start_colosseum_bot()

	_aim_preview = AimPreview.new()
	_aim_preview.name = "AimPreview"
	add_child(_aim_preview)

	for state: PlayerState in Network.instance.get_players():
		_on_player_added(state.id, state)
	_on_group_changed(Network.instance.group)
	_on_guild_changed(Network.instance.guild)
	_hud.set_friends(Network.instance.friends)
	_hud.set_social_settings(Network.instance.social_friend_requests, Network.instance.social_group_invites,
			Network.instance.social_guild_invites, Network.instance.social_profile, Network.instance.social_trade_requests)
	# NPCs: só o ferreiro agora; os outros nascem quando entram na vista ([INFRA-11], _spawn_npcs_in_view).
	_spawn_npcs_in_view(-1)
	for chest: ChestInfo in Network.instance.chests.values():
		_spawn_chest(chest)
	Network.instance.combat_event.connect(_on_combat_event)
	Network.instance.snapshot_received.connect(_on_snapshot)
	_update_online_status()


## Quem pode ser alvo agora: bonecos/monstros vivos (menos os que o servidor marca como não-alvo: atirador de teste
## invulnerável e o saco de pancadas, que é aliado, [JOGO-11]) e, se a zona tem PvP ([JOGO-02]), jogadores vivos que
## não são do meu grupo ([SOC-03]: o servidor recusa membro como alvo).
func get_targetables() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	for npc_id: String in _npcs:
		var npc: RemotePlayer = _npcs[npc_id]
		var state: PlayerState = Network.instance.get_entity(npc_id)
		if npc.is_alive() and (state == null or state.targetable):
			result.append(npc)
	if Network.instance.is_arena():
		# Arena do Coliseu ([JOGO-28]): o outro time, sem regra de nível nem de praça.
		for remote: RemotePlayer in _remote_players.values():
			if remote.is_alive() and Network.instance.is_arena_enemy(remote.session_id):
				result.append(remote)
	elif Network.instance.pvp:
		# PvP ([JOGO-22]): só até 10 níveis de diferença e ninguém em cima das pedras da praça.
		var me: PlayerState = Network.instance.get_player(Network.instance.player_id)
		for remote: RemotePlayer in _remote_players.values():
			if remote.is_alive() and not Network.instance.is_group_member(remote.session_id) \
					and not Network.instance.is_guild_member(remote.session_id) \
					and PvpRules.can_attack(me, Network.instance.get_player(remote.session_id)):
				result.append(remote)
	return result


## Aliados que dá para curar/proteger ([JOGO-09]): outros jogadores vivos (do meu grupo ou não, todo jogador é
## aliado, mesmo com PvP) e NPCs aliados (saco de pancadas, [JOGO-11]). ATENÇÃO: mesma regra de Zone.isAlly em
## mmo-server/src/zones/Zone.ts.
func get_allies() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	for remote: RemotePlayer in _remote_players.values():
		# Na arena do Coliseu ([JOGO-28]) só o meu time é aliado.
		if remote.is_alive() and (not Network.instance.is_arena() or Network.instance.is_teammate(remote.session_id)):
			result.append(remote)
	for npc_id: String in _npcs:
		var npc: RemotePlayer = _npcs[npc_id]
		var state: PlayerState = Network.instance.get_entity(npc_id)
		if npc.is_alive() and state != null and state.ally:
			result.append(npc)
	return result


## Jogador remoto ou boneco pelo id (para o marcador do alvo), ou null.
func get_target_node(entity_id: String) -> RemotePlayer:
	if _remote_players.has(entity_id):
		return _remote_players[entity_id]
	if _npcs.has(entity_id):
		return _npcs[entity_id]
	return null


## Mensagem do chat: vai para a HUD; a do Geral vira balão em cima de quem falou ([ChatBubble]), se ele está aqui.
func _on_chat_message(message: ChatMessage) -> void:
	_hud.add_chat_message(message)
	if message.channel != "zone":
		return
	var speaker: Node3D = get_entity_node(message.from_id)
	if speaker != null:
		ChatBubble.show_on(speaker, message.text)


## Nó de qualquer entidade (inclusive o jogador local), para efeitos visuais; ou null.
func get_entity_node(entity_id: String) -> Node3D:
	if _local_player != null and entity_id == Network.instance.player_id:
		return _local_player
	return get_target_node(entity_id)


func _on_player_added(player_id: String, state: PlayerState) -> void:
	if player_id == Network.instance.player_id:
		_spawn_local_player(state)
	elif not _remote_players.has(player_id):
		var remote: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
		remote.setup(player_id, state)
		remote.name = "Remote_%s" % player_id
		_players_root.add_child(remote)
		_remote_players[player_id] = remote
		remote.set_ally(Network.instance.is_group_member(player_id))
		remote.set_guildmate(Network.instance.is_guild_member(player_id))
	_update_online_status()


## Dev/testes do Coliseu ([JOGO-28]): `-- --colosseum=1x1` (ou 2x2/3x3; `--colosseum-healer` = mão Curandeiro) entra na
## fila sozinho ao chegar na zona comum (nas pedras da praça) e aceita a partida encontrada. Duas janelas com isso
## jogam uma partida sem clicar.
const COLOSSEUM_BOT_ARG: String = "--colosseum="
const COLOSSEUM_BOT_HEALER_ARG: String = "--colosseum-healer"


func _start_colosseum_bot() -> void:
	var mode: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(COLOSSEUM_BOT_ARG):
			mode = arg.substr(COLOSSEUM_BOT_ARG.length())
	if mode.is_empty() or Network.instance.is_arena():
		return
	var hand: String = ColosseumData.HEALER_SET if COLOSSEUM_BOT_HEALER_ARG in OS.get_cmdline_user_args() else "Mago"
	var build: Dictionary[String, String] = {"hand": hand, "head": "Cavaleiro", "chest": "Cavaleiro", "feet": "Atirador"}
	Network.instance.colosseum_found.connect(func(_mode: String, _seconds: int, _total: int) -> void:
		Network.instance.send_colosseum_answer(true))
	# Um pouco depois de entrar (o servidor já pôs o jogador na praça).
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_inside_tree():
			print("[coliseu-bot] entrando na fila %s" % mode)
			Network.instance.send_colosseum_queue(mode, build))


## Placar novo do Coliseu ([JOGO-28]): a HUD mostra; os jogadores remotos pegam a cor de aliado do meu time.
func _on_colosseum_state(state: ColosseumData.MatchState) -> void:
	_hud.set_colosseum_state(state)
	for remote_id: String in _remote_players:
		_remote_players[remote_id].set_ally(Network.instance.is_group_member(remote_id))


## O servidor mandou outro welcome (entrou/saiu da arena do Coliseu, [JOGO-28]): troca para a cena da zona nova, que
## cria tudo de novo a partir do [Network].
func _on_zone_changed(_player_id: String) -> void:
	if not is_inside_tree():
		return
	print("[zona] trocando de cena: %s" % Network.instance.zone_scene())
	get_tree().change_scene_to_file.call_deferred(Network.instance.zone_scene())


func _on_player_removed(player_id: String) -> void:
	if _remote_players.has(player_id):
		# Subscript de Dictionary tipado já devolve RemotePlayer (get() devolveria Variant).
		var remote: RemotePlayer = _remote_players[player_id]
		remote.queue_free()
		_remote_players.erase(player_id)
	_update_online_status()


## Quantos NPCs no máximo nascem por snapshot (30 por segundo, [INFRA-12]): criar o boneco (modelo, esqueleto) custa;
## vários entrando juntos na vista (um acampamento) ficam espalhados em alguns quadros, sem engasgo.
const _NPC_SPAWNS_PER_SNAPSHOT: int = 3


## Cria o nó dos NPCs que estão na área de interesse e ainda não têm nó ([INFRA-11]): o servidor manda os ~100 NPCs
## da zona no [code]welcome[/code], mas o boneco de cada um só nasce quando ele entra na vista (45 m), não ao entrar
## no mapa. Uma vez criado, fica (fora da vista ele some e dorme, [method RemotePlayer._sync_view]). O ferreiro é
## cenário fixo e nasce sempre. [param limit] = máximo a criar agora (-1 = sem limite).
func _spawn_npcs_in_view(limit: int) -> void:
	var created: int = 0
	for npc: PlayerState in Network.instance.get_npcs():
		if limit >= 0 and created >= limit:
			return
		if _npcs.has(npc.id) or _stations.has(npc.id):
			continue
		if not npc.in_view and npc.service.is_empty():
			continue
		_spawn_npc(npc)
		created += 1


func _spawn_npc(state: PlayerState) -> void:
	if _npcs.has(state.id) or _stations.has(state.id):
		return
	# Ferreiro ([JOGO-16]): a cena fixa (ferreiro + fornalha + bigorna) no lugar do NPC; não é alvo nem anda.
	if state.service == "blacksmith":
		var station: BlacksmithStation = BlacksmithStation.new()
		station.setup(state)
		_players_root.add_child(station)
		_stations[state.id] = station
		return
	# Mercador ([JOGO-25]): a tenda cheia de ouro no lugar do NPC.
	if state.service == "market":
		var tent: MarketTent = MarketTent.new()
		tent.setup(state)
		_players_root.add_child(tent)
		_stations[state.id] = tent
		return
	# Armazém ([JOGO-26]): o baú grande fixo no lugar do NPC.
	if state.service == "storage":
		var chest: ChestVisual = ChestVisual.new()
		chest.setup_storage(state)
		_players_root.add_child(chest)
		_stations[state.id] = chest
		return
	# NPC humano ([JOGO-11]): personagem vestido, como um jogador; os outros: boneco de palha.
	var scene: PackedScene = REMOTE_PLAYER_SCENE if state.has_body else DUMMY_SCENE
	var npc: RemotePlayer = scene.instantiate() as RemotePlayer
	npc.setup(state.id, state)
	npc.name = "Npc_%s" % state.id
	_players_root.add_child(npc)
	_npcs[state.id] = npc


## Eventos de combate: animações, projéteis, avisos no chão ([JOGO-08]), números de dano e mortes ([JOGO-05]).
func _on_combat_event(event: Dictionary) -> void:
	var type: String = Protocol.read_string(event, "type")
	var me: String = Network.instance.player_id
	match type:
		"cast_start":
			_on_cast_start(event)
		"cast_cancel":
			_on_cast_cancel(Protocol.read_string(event, "source"))
		"projectile":
			_on_projectile(event)
		"projectile_end":
			var ended: int = Protocol.read_int(event, "id", -1)
			if _projectiles.has(ended):
				var visual: ProjectileVisual = _projectiles[ended]
				if is_instance_valid(visual):
					visual.finish(Vector3(Protocol.read_float(event, "x"), 0.0, Protocol.read_float(event, "z")))
				_projectiles.erase(ended)
		"damage":
			var target_id: String = Protocol.read_string(event, "target")
			var node: Node3D = get_entity_node(target_id)
			if node == null:
				return
			var hurt: RemotePlayer = get_target_node(target_id)
			if hurt != null:
				hurt.react_to_hit()
			elif target_id == me and _local_player != null:
				_local_player.model.flinch()
			# Vermelho: dano em mim. Amarelo: dano que eu dei. Branco: entre outros.
			var color: Color = Color(1, 0.35, 0.3) if target_id == me else (Color(1, 0.85, 0.4) if Protocol.read_string(event, "source") == me else Color(1, 1, 1, 0.85))
			var above: Vector3 = node.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT
			var amount: int = roundi(Protocol.read_float(event, "amount"))
			var absorbed: int = roundi(Protocol.read_float(event, "absorbed"))
			if amount > 0:
				# Crítico ([JOGO-16]): laranja com "!".
				var crit_value: Variant = event.get("crit")
				if crit_value is bool and crit_value == true:
					FloatingText.spawn(self, above + Vector3.UP * 0.2, "-%d!" % amount, Color(1.0, 0.55, 0.1))
				else:
					FloatingText.spawn(self, above, "-%d" % amount, color)
			# Parte do golpe que o escudo segurou, em azul claro.
			if absorbed > 0:
				FloatingText.spawn(self, above + Vector3.UP * 0.4, "-%d escudo" % absorbed, Color(0.55, 0.8, 1.0))
		"heal":
			var healed: Node3D = get_entity_node(Protocol.read_string(event, "target"))
			var heal_amount: int = roundi(Protocol.read_float(event, "amount"))
			if healed != null and heal_amount > 0:
				FloatingText.spawn(self, healed.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT, "+%d" % heal_amount, Color(0.4, 1.0, 0.45))
		"impact":
			# Onde a área/projétil bateu ([JOGO-06]).
			ImpactFlash.spawn(self, Protocol.read_float(event, "x"), Protocol.read_float(event, "z"), Protocol.read_float(event, "radius"))
		"miss":
			# Golpe terminou com o alvo fora do alcance ([JOGO-05]).
			var missed: Node3D = get_entity_node(Protocol.read_string(event, "target"))
			if missed != null and Protocol.read_string(event, "source") == me:
				FloatingText.spawn(self, missed.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT, "Errou", Color(0.85, 0.85, 0.85))
		"death":
			var dead_id: String = Protocol.read_string(event, "id")
			if Protocol.read_string(event, "killer") == me and dead_id != me:
				var victim: RemotePlayer = get_target_node(dead_id)
				_hud.show_toast("Você derrotou %s" % (victim.display_name if victim != null else dead_id))
		"level_up":
			# Todos veem quem subiu ([JOGO-12]); quem subiu também ganha o aviso no topo.
			var leveled_id: String = Protocol.read_string(event, "id")
			var new_level: int = Protocol.read_int(event, "level")
			var leveled: Node3D = get_entity_node(leveled_id)
			if leveled != null:
				FloatingText.spawn(self, leveled.global_position + Vector3.UP * (_FLOATING_TEXT_HEIGHT + 0.5), "Nível %d!" % new_level, Color(0.0, 0.9, 1.0))
			if leveled_id == me:
				_hud.show_toast("Você subiu para o nível %d!" % new_level)


## Alguém começou a lançar: o personagem anima (golpe no fim do lançamento), aparece o aviso no chão das
## áreas/linhas e, nas habilidades de alvo, um projétil visual que chega junto com o dano ([JOGO-08]).
func _on_cast_start(event: Dictionary) -> void:
	var source_id: String = Protocol.read_string(event, "source")
	var ability: String = Protocol.read_string(event, "ability")
	var duration: float = Protocol.read_float(event, "duration")
	# Monstro: barra de lançamento acima da vida ([JOGO-13]).
	var npc_node: RemotePlayer = get_target_node(source_id)
	if npc_node != null:
		npc_node.show_cast(duration)
	var model: CharacterModel = _character_of(source_id)
	var serial: int = _cast_serial.get(source_id, 0) + 1
	_cast_serial[source_id] = serial
	var already_animated: bool = _local_player != null and source_id == Network.instance.player_id and _local_player.consume_prediction(ability)
	if model != null and not already_animated:
		model.play_ability(ability, duration)
	var color: Color = AbilityVisuals.color(ability)
	if model != null and duration > 0.0 and AbilityVisuals.has_cast_glow(ability):
		model.show_cast_glow(color, duration)
	var radius: float = Protocol.read_float(event, "radius")
	var has_point: bool = event.has("x") and event.has("z")
	var caster: Node3D = get_entity_node(source_id)
	if has_point and radius > 0.0 and duration > 0.0 and caster != null:
		var point: Vector3 = Vector3(Protocol.read_float(event, "x"), 0.0, Protocol.read_float(event, "z"))
		if Protocol.read_string(event, "aim") == "direction":
			_cast_warnings[source_id] = GroundWarning.spawn_line(self, caster.global_position, point, radius, duration, color)
		else:
			_cast_warnings[source_id] = GroundWarning.spawn_area(self, point.x, point.z, radius, duration, color)
	var reach: float = AbilityVisuals.slash_reach(ability)
	if reach != 0.0 and caster != null:
		get_tree().create_timer(maxf(duration, 0.0)).timeout.connect(_slash.bind(source_id, serial, caster, reach, color))
	# Quando o tiro sai da mão: o servidor manda ("release", s antes do fim); depois disso andar não cancela mais.
	var flight: float = Protocol.read_float(event, "release") if event.has("release") else AbilityVisuals.homing_flight(ability)
	var target: Node3D = get_entity_node(Protocol.read_string(event, "target"))
	if flight > 0.0 and target != null and model != null:
		# Sai antes do fim do lançamento para chegar junto com o dano.
		var delay: float = maxf(duration - flight, 0.0)
		get_tree().create_timer(delay).timeout.connect(_launch_homing.bind(source_id, serial, model, target, minf(flight, duration), color))


## [param source_id] andou durante o lançamento e o servidor cancelou ([JOGO-06]): para a animação e o brilho,
## tira o aviso do chão e invalida os efeitos agendados (clarão, projétil visual).
func _on_cast_cancel(source_id: String) -> void:
	_cast_serial[source_id] = _cast_serial.get(source_id, 0) + 1
	var npc_node: RemotePlayer = get_target_node(source_id)
	if npc_node != null:
		npc_node.hide_cast()
	var model: CharacterModel = _character_of(source_id)
	if model != null:
		model.stop_action()
		model.hide_cast_glow()
	# O aviso pode já ter sumido sozinho (liberado): checar antes de pôr numa variável tipada.
	var entry: Variant = _cast_warnings.get(source_id, null)
	if is_instance_valid(entry):
		(entry as GroundWarning).queue_free()
	_cast_warnings.erase(source_id)


## true se o lançamento [param serial] de [param source_id] ainda é o atual (não foi cancelado nem substituído).
func _is_current_cast(source_id: String, serial: int) -> bool:
	return _cast_serial.get(source_id, 0) == serial


## Clarão do golpe corpo a corpo no momento do golpe, na frente de [param caster] ([JOGO-08]).
func _slash(source_id: String, serial: int, caster: Node3D, reach: float, color: Color) -> void:
	if not _is_current_cast(source_id, serial) or not is_instance_valid(caster) or not caster.is_visible_in_tree():
		return
	SlashArc.spawn(self, caster.global_position, caster.global_rotation.y, absf(reach), reach < 0.0, Color(1, 1, 1) if color == AbilityVisuals.DEFAULT_COLOR else color)


## Projétil de alvo (visual): sai da mão de [param model] e chega em [param target] em [param seconds].
func _launch_homing(source_id: String, serial: int, model: CharacterModel, target: Node3D, seconds: float, color: Color) -> void:
	if not _is_current_cast(source_id, serial) or not is_instance_valid(model) or not is_instance_valid(target) or not model.is_visible_in_tree():
		return
	ProjectileVisual.spawn_homing(self, model.cast_point(), target, seconds, color)


## Projétil de verdade saiu ([JOGO-08]): desenha o voo na mesma velocidade do servidor.
func _on_projectile(event: Dictionary) -> void:
	var id: int = Protocol.read_int(event, "id", -1)
	var start_x: float = Protocol.read_float(event, "x")
	var start_z: float = Protocol.read_float(event, "z")
	var from: Vector3 = Vector3(start_x, ZoneTerrain.height_at(start_x, start_z) + _PROJECTILE_HEIGHT, start_z)
	var direction: Vector3 = Vector3(Protocol.read_float(event, "dirX"), 0.0, Protocol.read_float(event, "dirZ"))
	if direction.length() < 0.01:
		return
	var ability: String = Protocol.read_string(event, "ability")
	var visual: ProjectileVisual = ProjectileVisual.spawn_linear(self, from, direction.normalized(),
		Protocol.read_float(event, "speed"), Protocol.read_float(event, "range"), AbilityVisuals.color(ability))
	_projectiles[id] = visual
	# Limpa entradas de projéteis que já sumiram sozinhos (fim do alcance antes do "projectile_end").
	for old: int in _projectiles.keys():
		if not is_instance_valid(_projectiles[old]):
			_projectiles.erase(old)


## Meu grupo mudou ([SOC-03]): a HUD (botão/painel "Grupo") e a cor de aliado de cada jogador.
func _on_group_changed(group: GroupState) -> void:
	_hud.set_group(group, Network.instance.player_id)
	for remote: RemotePlayer in _remote_players.values():
		remote.set_ally(Network.instance.is_group_member(remote.session_id))


## Minha guilda mudou ([SOC-06]): o painel da HUD e a cor azul de cada guildeiro.
func _on_guild_changed(guild: GuildState) -> void:
	_hud.set_guild(guild, Network.instance.player_id)
	for remote: RemotePlayer in _remote_players.values():
		remote.set_guildmate(Network.instance.is_guild_member(remote.session_id))


## A guilda de um jogador da zona mudou: a cor azul dele (a tag no nome muda sozinha, [method RemotePlayer._refresh_level]).
func _on_player_guild_changed(player_id: String) -> void:
	if _remote_players.has(player_id):
		var remote: RemotePlayer = _remote_players[player_id]
		remote.set_guildmate(Network.instance.is_guild_member(player_id))
	elif player_id == Network.instance.player_id:
		# A MINHA guilda mudou na zona: os outros podem ter virado (ou deixado de ser) guildeiros.
		for remote: RemotePlayer in _remote_players.values():
			remote.set_guildmate(Network.instance.is_guild_member(remote.session_id))


## Aviso do grupo ou da amizade ("X aceitou o convite", "X recusou o pedido de amizade"...): o aviso pequeno do topo.
func _on_group_notice(_code: String, message: String) -> void:
	_hud.show_toast(message)


## Recusa do servidor (ex.: mochila cheia, recarga): aviso na tela; se era uma carta animada no toque, para.
func _on_server_error(code: String, message: String) -> void:
	_hud.show_toast(message)
	if code == Protocol.ERR_PLAYER_NOT_FOUND:
		_hud.show_attributes_error(message)
	elif code == Protocol.ERR_NOT_ENOUGH_DIAMONDS:
		_hud.show_premium_not_enough()
	elif code.begins_with("colosseum_"):
		_hud.show_colosseum_error(message)
	if _local_player != null:
		_local_player.cancel_prediction()


## Boneco animado de [param id] (você ou outro jogador); null para bonecos de treino e desconhecidos.
func _character_of(id: String) -> CharacterModel:
	if _local_player != null and id == Network.instance.player_id:
		return _local_player.model
	if _remote_players.has(id):
		return _remote_players[id].model
	return null


## A cada snapshot: barras de vida/mana/XP do jogador local e o aviso de morte.
func _on_snapshot(_tick: int, _ack: int) -> void:
	var network: Network = Network.instance
	_spawn_npcs_in_view(_NPC_SPAWNS_PER_SNAPSHOT)
	var own: PlayerState = network.get_player(network.player_id)
	if own == null:
		return
	_hud.set_health(own.hp, own.max_hp, own.shield)
	_hud.set_mana(network.mana, network.max_mana)
	_hud.set_experience(network.level, network.xp, network.xp_next)
	# XP subiu no mesmo nível (matou um monstro): "+20 XP" em ciano acima de você. Subir de nível tem o aviso próprio.
	if _last_level == network.level and network.xp > _last_xp + 0.05 and _local_player != null:
		FloatingText.spawn(self, _local_player.global_position + Vector3.UP * (_FLOATING_TEXT_HEIGHT + 0.5),
			"+%s XP" % _format_xp(network.xp - _last_xp), Color(0.0, 0.9, 1.0))
	_last_level = network.level
	_last_xp = network.xp
	# Moedas subiram (matou um monstro): "+10 moedas" dourado, um pouco acima do "+XP" ([JOGO-15]).
	if _last_gold >= 0 and network.gold > _last_gold and _local_player != null:
		FloatingText.spawn(self, _local_player.global_position + Vector3.UP * (_FLOATING_TEXT_HEIGHT + 1.0),
			"+%d moedas" % (network.gold - _last_gold), Color(1.0, 0.82, 0.25))
	_last_gold = network.gold
	_hud.set_gold(network.gold)
	_hud.set_blacksmith_near(not own.dead and _near_service(network, own, "blacksmith"))
	_hud.set_storage_near(not own.dead and _near_service(network, own, "storage"))
	_hud.set_market_near(not own.dead and _near_service(network, own, "market"))
	_hud.set_chest_near("" if own.dead else _near_open_chest(network, own))
	# Jogadores Próximos aberto: a lista acompanha quem chega, sai ou sobe de nível ([SOC-02]).
	if _hud.is_nearby_open():
		_hud.set_nearby_players(network.get_nearby_players())
	# Tela de morte ([JOGO-21]): aparece morto, some ao renascer.
	_hud.set_dead(own.dead, network.respawn_in)
	if not own.dead:
		_check_region(own)


## Trocou de zona de nível ([JOGO-18]): aviso "Entrando em Nome (nv a-b)"; subiu nas pedras da praça: "área segura"
## ([JOGO-22]).
func _check_region(own: PlayerState) -> void:
	var region: ZoneInfo.Region = ZoneInfo.region_at(own.x, own.z)
	var safe: bool = PvpRules.in_safe_zone(own.x, own.z)
	var key: String = region.name if region != null else ("praça" if safe else "")
	if key == _last_region:
		return
	var first: bool = _last_region == "?"
	_last_region = key
	if first:
		return
	if region != null:
		_hud.show_toast("Entrando em %s · PvP liberado (até %d níveis de diferença)" % [region.title(), PvpRules.MAX_LEVEL_GAP])
	elif safe:
		_hud.show_toast("Praça: área segura (sem PvP)")


## Distância máxima (m) do baú aberto para o botão "Abrir baú" aparecer ([JOGO-19]). ATENÇÃO: = CHEST_RANGE em
## mmo-server/src/zones/Zone.ts (lá soma o corpo, 0,4 m: o botão aparece antes do limite do servidor, nunca depois).
const CHEST_RANGE: float = 3.0

## Baús no mundo ([ChestVisual]), por id.
var _chests: Dictionary[String, ChestVisual] = {}


## Põe o baú [param chest] em cima da fogueira do acampamento dele.
func _spawn_chest(chest: ChestInfo) -> void:
	var visual: ChestVisual = ChestVisual.new()
	visual.name = "Chest_%s" % chest.id
	visual.setup(chest, ZoneTerrain.height_at(chest.x, chest.z))
	add_child(visual)
	_chests[chest.id] = visual


## Baú abriu/fechou: a tampa acompanha; fechou com a janela dele aberta, a janela some (o botão some no snapshot).
func _on_chest_changed(chest_id: String, open: bool) -> void:
	if _chests.has(chest_id):
		_chests[chest_id].set_open(open)
	if not open and chest_id == _near_chest_id():
		_hud.set_chest_near("")


func _near_chest_id() -> String:
	var network: Network = Network.instance
	var own: PlayerState = network.get_player(network.player_id)
	return "" if own == null else _near_open_chest(network, own)


## O que sobrou para mim no baú: abre/atualiza a janela dele.
func _on_chest_loot(chest_id: String, entries: Array[LootEntry]) -> void:
	var chest: ChestInfo = Network.instance.chests.get(chest_id)
	if chest != null:
		_hud.show_chest_loot(chest, entries)


## Baú ABERTO a até [constant CHEST_RANGE] m de [param own] ("" = nenhum).
static func _near_open_chest(network: Network, own: PlayerState) -> String:
	for chest: ChestInfo in network.chests.values():
		if chest.open and Vector2(chest.x - own.x, chest.z - own.z).length() <= CHEST_RANGE:
			return chest.id
	return ""


## Distância máxima (m) do ferreiro para o botão aparecer. ATENÇÃO: = BLACKSMITH_RANGE em mmo-server/src/zones/Zone.ts
## (lá ainda soma o raio do corpo, 0,4 m: o botão aparece um pouco antes do limite do servidor, nunca depois).
const _BLACKSMITH_RANGE: float = 4.0


## Há um NPC do serviço [param service] ([member PlayerState.service]: ferreiro, armazém) a até
## [constant _BLACKSMITH_RANGE] m de [param own]? (mesmo alcance para todos, como no servidor)
static func _near_service(network: Network, own: PlayerState, service: String) -> bool:
	for npc: PlayerState in network.get_npcs():
		if npc.service == service and Vector2(npc.x - own.x, npc.z - own.z).length() <= _BLACKSMITH_RANGE:
			return true
	return false


## XP com no máximo 1 casa, sem ",0" ("20", "20.2").
static func _format_xp(value: float) -> String:
	var rounded: float = snappedf(value, 0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded


func _on_left_zone(_code: int, _reason: String) -> void:
	_back_to_login()


## "Sair da conta" (Menu): encerra a sessão; a queda da conexão traz de volta ao login.
func _on_logout_requested() -> void:
	Network.instance.logout()


func _back_to_login() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _spawn_local_player(state: PlayerState) -> void:
	if _local_player != null:
		return
	_local_player = LOCAL_PLAYER_SCENE.instantiate() as LocalPlayer
	_local_player.name = "LocalPlayer"
	_local_player.joystick = _hud.joystick
	_players_root.add_child(_local_player)
	_local_player.spawn_at(state)
	# Boneco no meio do espaço livre entre as molduras da HUD, não no centro da tela ([CLI-02]).
	_hud.play_area_changed.connect(_center_camera_on_play_area)
	_center_camera_on_play_area()
	BotFight.attach_if_requested(self, _local_player)

	_combat = CombatController.new()
	_combat.name = "CombatController"
	add_child(_combat)
	_combat.setup(self, _local_player, _hud, _aim_preview)


func _center_camera_on_play_area() -> void:
	if _local_player != null:
		_local_player.get_camera().screen_focus_y = _hud.play_area_center_ratio()


func _update_online_status() -> void:
	var online: int = _remote_players.size() + (1 if _local_player != null else 0)
	_hud.set_status("%s · Online: %d" % [Network.instance.username, online])
