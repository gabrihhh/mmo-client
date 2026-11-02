class_name Zone
extends Node3D
## Cena de uma zona do mundo: cria/remove os jogadores conforme o servidor e monta a HUD.
##
## É aberta pela tela de login depois do welcome (já conectado). Fluxo: cria quem já está em
## [method Network.get_players] e depois segue [signal Network.player_added] / [signal Network.player_removed].
## O próprio player id vira o [LocalPlayer]; os outros, [RemotePlayer].
## Se a conexão cair (ou o jogador sair pelo menu), volta para a tela de login, que mostra o motivo.

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
var _aim_preview: AimPreview = null
var _combat: CombatController = null


func _ready() -> void:
	if Network.instance == null or not Network.instance.is_in_zone():
		# Aberta sem passar pelo login (ex.: F6 no editor): volta para lá.
		_back_to_login.call_deferred()
		return
	Network.instance.player_added.connect(_on_player_added)
	Network.instance.player_removed.connect(_on_player_removed)
	Network.instance.left_zone.connect(_on_left_zone)
	_hud.logout_requested.connect(_on_logout_requested)
	_hud.equip_requested.connect(Network.instance.send_equip)
	_hud.unequip_requested.connect(Network.instance.send_unequip)
	# Recusas que não são de login (ex.: mochila cheia) viram aviso na tela.
	Network.instance.server_error.connect(func(_code: String, message: String) -> void: _hud.show_toast(message))

	_aim_preview = AimPreview.new()
	_aim_preview.name = "AimPreview"
	add_child(_aim_preview)

	for state: PlayerState in Network.instance.get_players():
		_on_player_added(state.id, state)
	for npc: PlayerState in Network.instance.get_npcs():
		_spawn_npc(npc)
	Network.instance.combat_event.connect(_on_combat_event)
	Network.instance.snapshot_received.connect(_on_snapshot)
	_update_online_status()


## Quem pode ser alvo agora: bonecos/monstros vivos e, se a zona tem PvP ([JOGO-02]), jogadores vivos.
func get_targetables() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	for npc: RemotePlayer in _npcs.values():
		if npc.is_alive():
			result.append(npc)
	if Network.instance.pvp:
		for remote: RemotePlayer in _remote_players.values():
			if remote.is_alive():
				result.append(remote)
	return result


## Jogador remoto ou boneco pelo id (para o marcador do alvo), ou null.
func get_target_node(entity_id: String) -> RemotePlayer:
	if _remote_players.has(entity_id):
		return _remote_players[entity_id]
	if _npcs.has(entity_id):
		return _npcs[entity_id]
	return null


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
	_update_online_status()


func _on_player_removed(player_id: String) -> void:
	if _remote_players.has(player_id):
		# Subscript de Dictionary tipado já devolve RemotePlayer (get() devolveria Variant).
		var remote: RemotePlayer = _remote_players[player_id]
		remote.queue_free()
		_remote_players.erase(player_id)
	_update_online_status()


func _spawn_npc(state: PlayerState) -> void:
	if _npcs.has(state.id):
		return
	var npc: RemotePlayer = DUMMY_SCENE.instantiate() as RemotePlayer
	npc.setup(state.id, state)
	npc.name = "Npc_%s" % state.id
	_players_root.add_child(npc)
	_npcs[state.id] = npc


## Eventos de combate: números de dano e avisos de morte ([JOGO-05]).
func _on_combat_event(event: Dictionary) -> void:
	var type: String = Protocol.read_string(event, "type")
	var me: String = Network.instance.player_id
	match type:
		"damage":
			var target_id: String = Protocol.read_string(event, "target")
			var node: Node3D = get_entity_node(target_id)
			if node == null:
				return
			# Vermelho: dano em mim. Amarelo: dano que eu dei. Branco: entre outros.
			var color: Color = Color(1, 0.35, 0.3) if target_id == me else (Color(1, 0.85, 0.4) if Protocol.read_string(event, "source") == me else Color(1, 1, 1, 0.85))
			FloatingText.spawn(self, node.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT, "-%d" % roundi(Protocol.read_float(event, "amount")), color)
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


## A cada snapshot: barras de vida/mana do jogador local e o aviso de morte.
func _on_snapshot(_tick: int, _ack: int) -> void:
	var network: Network = Network.instance
	var own: PlayerState = network.get_player(network.player_id)
	if own == null:
		return
	_hud.set_health(own.hp, own.max_hp)
	_hud.set_mana(network.mana, network.max_mana)
	if own.dead:
		_hud.show_toast("Você morreu · renasce em %d s" % ceili(network.respawn_in))


func _on_left_zone(_code: int, _reason: String) -> void:
	_back_to_login()


## "Sair da conta" (menu > Configuração): encerra a sessão; a queda da conexão traz de volta ao login.
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

	_combat = CombatController.new()
	_combat.name = "CombatController"
	add_child(_combat)
	_combat.setup(self, _local_player, _hud, _aim_preview)


func _update_online_status() -> void:
	var online: int = _remote_players.size() + (1 if _local_player != null else 0)
	_hud.set_status("%s · Online: %d" % [Network.instance.username, online])
