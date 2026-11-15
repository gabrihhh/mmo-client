class_name Network
extends Node
## Única porta de entrada para o servidor do jogo. Acesso: [member Network.instance].
##
## Não é autoload: é criado pelo [GameBoot] depois que o atualizador carrega o pacote do jogo,
## porque autoloads ficam presos no APK e não poderiam ser atualizados (mmo-docs [INFRA-08]).
## Usa o [WebSocketPeer] nativo do Godot (sem SDK de terceiros). O resto do jogo não
## fala com o socket: usa os sinais e métodos daqui.
##
## Fluxo: [method login] / [method register] / [method resume_session] abrem a conexão e autenticam
## ([signal authenticated]); em seguida o Network entra sozinho na zona ([signal joined_zone]).
## Contas: mmo-docs [INFRA-07]. Protocolo: [INFRA-04]. Modelo autoritativo: [INFRA-09].
## Pacote do jogo velho ([constant Protocol.MSG_UPDATE_REQUIRED], ou version_mismatch fora do dev): quando a conexão
## fecha, abre o [LiveUpdater] (baixa a versão nova e reabre o jogo no mesmo processo), [INFRA-08].

## Autenticação aceita. [member username] é o nome exatamente como foi cadastrado.
signal authenticated(username: String)
## Cadastro/login/sessão recusado (ex.: "username_taken", "invalid_credentials"). [param message] já vem
## em português do servidor. A conexão continua aberta para tentar de novo (salvo "too_many_attempts").
signal auth_failed(code: String, message: String)
## Entrou na zona. A partir daqui [member player_id] é válido e [method get_players] tem a lista inicial.
signal joined_zone(player_id: String)
## Um jogador (inclusive o local) está na zona. [param state] é atualizado ao vivo pelo Network.
signal player_added(player_id: String, state: PlayerState)
## Um jogador saiu da zona.
signal player_removed(player_id: String)
## Não foi possível conectar (servidor fora do ar, URL errada...).
signal connection_error(code: int, message: String)
## O servidor recusou algo que não é autenticação (ex.: "zone_full"). Lista em mmo-server/src/net/protocol.ts.
signal server_error(code: String, message: String)
## A conexão fechou depois de aberta (logout, queda, recusa ou outra conexão da mesma conta).
## [param code] é o close code do WebSocket.
signal left_zone(code: int, reason: String)
## Chegou um snapshot do servidor (já aplicado nos [PlayerState]). [param ack] = último input DESTE
## cliente que o servidor aplicou; o [LocalPlayer] usa para reconciliar. Ver mmo-docs [INFRA-09].
signal snapshot_received(tick: int, ack: int)
## O inventário mudou (chegou o primeiro após o login, ou uma troca foi aceita). Ver [member inventory].
signal inventory_changed(inventory: InventoryState)
## Um boneco/monstro está na zona (vem no welcome). [param state] é atualizado ao vivo.
signal npc_added(npc_id: String, state: PlayerState)
## Evento de combate do tick (dano, morte, renascimento). Ver [constant Protocol.MSG_SNAPSHOT].
signal combat_event(event: Dictionary)
## Chegaram os atributos pedidos por [method send_inspect] (tela de Atributos, mmo-docs [SOC-02]).
signal attributes_received(attributes: PlayerAttributes)
## O MEU grupo mudou ([member group]; null = saí/sem grupo). Ver mmo-docs [SOC-03].
signal group_changed(group: GroupState)
## Alguém me convidou para o grupo ([param from_name]); responder com [method send_group_answer] em até
## [param expires_in] s.
signal group_invited(from_id: String, from_name: String, expires_in: float)
## Aviso pequeno do grupo ([param code]: ver [constant Protocol.MSG_GROUP_NOTICE]); [param message] vem pronta.
signal group_notice(code: String, message: String)
## Minha lista de amigos mudou ([member friends]; [SOC-04]).
signal friends_changed(friends: FriendList)
## Alguém pediu minha amizade ([param from_name]); responder com [method send_friend_answer] em até
## [param expires_in] s.
signal friend_requested(from_id: String, from_name: String, expires_in: float)
## Aviso pequeno de amizade ([param code]: ver [constant Protocol.MSG_FRIEND_NOTICE]); [param message] vem pronta.
signal friend_notice(code: String, message: String)
## A Configuração social salva na conta mudou (veio no auth_ok ou o servidor confirmou uma mudança): valores
## [constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE].
signal social_settings_changed(friend_requests: String, group_invites: String)

## Os jogadores remotos são desenhados este número de ticks no passado (2 ticks = 100 ms a 20 Hz),
## para sempre haver dois snapshots reais para interpolar mesmo se um atrasar.
const INTERPOLATION_DELAY_TICKS: float = 2.0
## Se o relógio local se afastar mais que isto (ticks) do servidor, pula direto em vez de ajustar aos poucos.
const _CLOCK_SNAP_TICKS: float = 10.0
## Fração do erro do relógio corrigida a cada snapshot (ajuste suave, sem trancos).
const _CLOCK_CORRECTION: float = 0.1
## Buffer de entrada do socket (bytes). O padrão do Godot (64 KB) enche em ~0,5 s com a zona cheia de NPCs (snapshot
## de ~7 KB a 20 Hz); um quadro travado no celular (ex.: carregar o mapa ao entrar) estourava e a conexão caía
## (código 1006). 4 MB dão dezenas de segundos de folga.
const _INBOUND_BUFFER_BYTES: int = 4 * 1024 * 1024
## Mensagens na fila de entrada do socket antes de ler (padrão do Godot: 4096 = ~3 min de snapshots; folga igual).
const _MAX_QUEUED_PACKETS: int = 8192

## Diagnóstico de queda (vai junto da mensagem "Conexão perdida"): quando chegou o último dado (ms desde o início,
## Time.get_ticks_msec) e o quadro mais demorado desde que a conexão abriu (ms). Quadro longo = o aparelho travou e
## não respondeu ao heartbeat do servidor; último dado antigo = a rede parou de entregar.
var _last_packet_ms: int = 0
var _worst_frame_ms: int = 0
var _worst_frame_at_ms: int = 0
## Autenticou, mas a conta ainda não escolheu o corpo do personagem: mostrar a tela de escolha e chamar
## [method choose_body]. O [code]join[/code] só vai depois da escolha ([signal body_chosen]).
signal body_choice_needed
## O servidor salvou o corpo escolhido; o Network já pediu para entrar na zona.
signal body_chosen(body: String)
## Códigos de erro que são resposta a cadastro/login/sessão (viram [signal auth_failed]).
const _AUTH_ERROR_CODES: Array[String] = [
	"invalid_username", "invalid_email", "invalid_password", "username_taken", "email_taken",
	"invalid_credentials", "invalid_session", "too_many_attempts", "version_mismatch",
]

## Tela que baixa e carrega o pacote novo com o jogo aberto. ATENÇÃO: igual a LiveUpdater.SCENE.
const LIVE_UPDATER_SCENE: String = "res://scenes/boot/live_updater.tscn"
## Versão do pacote do jogo que o servidor mandou instalar ([constant Protocol.MSG_UPDATE_REQUIRED]); 0 = nenhuma.
## [constant UPDATE_UNKNOWN] = recusado por versão de protocolo (version_mismatch) fora do dev: tenta atualizar também.
## Quando a conexão fecha com isso marcado, abre o [LiveUpdater] em vez de voltar ao login ([INFRA-08]).
var _update_version: int = 0
## Valor de [member _update_version] quando a versão nova não é conhecida (version_mismatch).
const UPDATE_UNKNOWN: int = -1

## A instância viva (criada pelo [GameBoot]); null antes do boot.
static var instance: Network = null

## Id do jogador desta conta (estável); vazio enquanto não autenticou.
var player_id: String = ""
## Username desta conta, exatamente como foi cadastrado; vazio enquanto não autenticou.
var username: String = ""
## Corpo do personagem desta conta ([constant Protocol.BODY_MALE]/[constant Protocol.BODY_FEMALE]); vazio = ainda não
## escolheu (ou não autenticou).
var body: String = ""
## Última mensagem de erro/desconexão, em português, para a tela de login mostrar. Vazio = nenhuma.
var last_error: String = ""
## Parâmetros da simulação recebidos no welcome (o servidor manda; o cliente não decide).
var tick_rate: float = 20.0
var move_speed: float = 5.0
var zone_half_size: float = 150.0
## Último inventário recebido (vestido + mochila); null antes do primeiro.
var inventory: InventoryState = null
## Jogadores podem ser atacados nesta zona (vem no welcome).
var pvp: bool = false
## Dados só deste jogador, do último snapshot ("me"): mana, segundos para renascer e alvo fixo.
var mana: float = 0.0
var max_mana: float = 0.0
var respawn_in: float = 0.0
## Nível do personagem, XP juntada dentro dele e XP que o nível pede para subir (o jogo não tem nível máximo; 0 só se um dia tiver), [JOGO-12].
## ATENÇÃO: vem do `me` do snapshot (OwnStatus em mmo-server/src/net/protocol.ts); o cliente não calcula.
var level: int = 0
var xp: float = 0.0
var xp_next: float = 0.0
## Moedas do personagem ([JOGO-15]), do `me` do snapshot; mostradas no Inventário.
var gold: int = 0
## Meu grupo segundo o servidor ([SOC-03]); null = sem grupo. Membros do grupo não se atingem e aparecem com a cor
## de aliado ([RemotePlayer]).
var group: GroupState = null
## Depois de quanto tempo (s) sem [constant Protocol.MSG_GROUP_POSITIONS] a posição de um membro longe deixa de valer
## (3 mensagens perdidas; o mapa volta à última posição conhecida pelo snapshot).
const GROUP_POSITIONS_STALE_SECONDS: float = 3.0 / Protocol.GROUP_POSITIONS_HZ
## Posição no chão (x, z em m) dos membros do grupo LONGE de mim (fora do snapshot), da última
## [constant Protocol.MSG_GROUP_POSITIONS] ([SOC-03], mapa [CLI-11]). Quem volta para a área de interesse sai daqui
## (o snapshot passa a valer).
var _group_far: Dictionary[String, Vector2] = {}
## Quando (Time.get_ticks_msec) chegou a última [constant Protocol.MSG_GROUP_POSITIONS].
var _group_far_ms: int = 0
## Meus amigos segundo o servidor ([SOC-04]); lista vazia antes da primeira mensagem.
var friends: FriendList = FriendList.new()
## Configuração social salva na conta ([SOC-04]): "Solicitações de amizade" e "Convites de grupo"
## ([constant Protocol.SOCIAL_ALWAYS] = mostrar, [constant Protocol.SOCIAL_HIDE] = recusar sozinho).
var social_friend_requests: String = Protocol.SOCIAL_ALWAYS
var social_group_invites: String = Protocol.SOCIAL_ALWAYS
## Alvo fixo do ataque simples segundo o SERVIDOR ("" = nenhum).
var attack_target: String = ""
## Golpe em andamento segundo o servidor: alvo ("" = nenhum) e segundos que faltam.
var casting_target: String = ""
var casting_remaining: float = 0.0

## Estimativa do tick atual do servidor (fracionário), avançada pelo tempo local e ajustada a cada snapshot.
var _clock_tick: float = 0.0

var _socket: WebSocketPeer = null
## A conexão chegou a abrir (diferencia "não conectou" de "caiu depois").
var _was_open: bool = false
## Autenticado nesta conexão.
var _authenticated: bool = false
## Já recebeu o welcome (está dentro da zona).
var _in_zone: bool = false
## Mensagem de autenticação esperando a conexão abrir: { "type": String, "data": Dictionary } ou {}.
var _pending_auth: Dictionary = {}
## Estados vivos dos jogadores da zona, por player id.
var _players: Dictionary[String, PlayerState] = {}
## Bonecos/monstros da zona, por id.
var _npcs: Dictionary[String, PlayerState] = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	set_process(false)


## true se o aparelho tem uma sessão salva (dá para entrar direto com [method resume_session]).
func has_saved_session() -> bool:
	return not AccountStorage.load_session_token().is_empty()


## Entra com a sessão salva no aparelho. Sem sessão salva, não faz nada.
func resume_session() -> void:
	var token: String = AccountStorage.load_session_token()
	if not token.is_empty():
		_request_auth(Protocol.MSG_RESUME, {"version": Protocol.VERSION, "client": PackInfo.client_build(), "sessionToken": token})


## Entra com username OU e-mail + senha.
func login(login_name: String, password: String) -> void:
	_request_auth(Protocol.MSG_LOGIN, {
		"version": Protocol.VERSION, "client": PackInfo.client_build(), "login": login_name.strip_edges(), "password": password,
	})


## Cria a conta e já entra nela. O username fica exatamente como foi digitado (sem espaços nas pontas).
func register(new_username: String, email: String, password: String) -> void:
	_request_auth(Protocol.MSG_REGISTER, {
		"version": Protocol.VERSION,
		"client": PackInfo.client_build(),
		"username": new_username.strip_edges(),
		"email": email.strip_edges(),
		"password": password,
	})


## Sai da conta: o servidor invalida a sessão deste aparelho e fecha a conexão; o token local é apagado.
func logout() -> void:
	AccountStorage.clear_session_token()
	last_error = ""
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send(Protocol.MSG_LOGOUT, {})
	elif _socket != null:
		_socket.close(1000, "logout")


## true enquanto conecta ou está conectado.
## Escolhe o corpo do personagem ([constant Protocol.BODY_MALE] ou [constant Protocol.BODY_FEMALE]). Vale para
## sempre; a resposta vem em [signal body_chosen] (e o Network entra na zona) ou como erro.
func choose_body(new_body: String) -> void:
	_send(Protocol.MSG_CHOOSE_BODY, {"body": new_body})


func is_connecting_or_connected() -> bool:
	return _socket != null


## true quando está dentro da zona com o WebSocket aberto.
func is_in_zone() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _in_zone


## Jogadores atualmente na zona (inclusive o local). Usado por quem entra depois do [signal joined_zone],
## como a cena da zona, que é carregada depois do welcome.
func get_players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	result.assign(_players.values())
	return result


## Duração de um tick de simulação, em segundos.
func tick_seconds() -> float:
	return 1.0 / tick_rate


## Tick (fracionário) em que os jogadores remotos devem ser desenhados agora: o tick estimado do
## servidor menos [constant INTERPOLATION_DELAY_TICKS].
func render_tick() -> float:
	return _clock_tick - INTERPOLATION_DELAY_TICKS


## Bonecos/monstros da zona.
func get_npcs() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	result.assign(_npcs.values())
	return result


## Estado de um jogador OU boneco pelo id, ou null.
func get_entity(id: String) -> PlayerState:
	if _players.has(id):
		return _players[id]
	if _npcs.has(id):
		return _npcs[id]
	return null


## Fixa o alvo do ataque simples ([param target_id] vazio = parar). O servidor confirma em [member attack_target].
func send_attack(target_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_ATTACK, {"targetId": target_id if not target_id.is_empty() else null})


## Lança a habilidade [param ability_id] ([JOGO-06]). [param target_id]: mira "no alvo" ("" = nenhum).
## [param x]/[param z]: direção (mira "direção") ou ponto no chão (mira "área"); NAN = não enviar.
## [param seq]: Investida/Disparada vão na fila de movimento com este número ([JOGO-07]); 0 = não enviar.
func send_cast(ability_id: String, target_id: String = "", x: float = NAN, z: float = NAN, seq: int = 0) -> void:
	if not is_in_zone():
		return
	var data: Dictionary = {"abilityId": ability_id}
	if not target_id.is_empty():
		data["targetId"] = target_id
	if not is_nan(x) and not is_nan(z):
		data["x"] = x
		data["z"] = z
	if seq > 0:
		data["seq"] = seq
	_send(Protocol.MSG_CAST, data)


## Estado vivo de um jogador, ou null.
func get_player(id: String) -> PlayerState:
	if not _players.has(id):
		return null
	return _players[id]


## Envia o input de UM tick: direção desejada no mundo (comprimento até 1) e o número de sequência.
## Ignorado se não estiver na zona.
func send_input(seq: int, direction_x: float, direction_z: float) -> void:
	if not is_in_zone():
		return
	_send(Protocol.MSG_INPUT, {"seq": seq, "x": direction_x, "z": direction_z})


## Distância máxima (m) da lista "Jogadores Próximos" ([SOC-02]): a mesma da área de interesse do servidor
## (VIEW_RADIUS em mmo-server/src/zones/Zone.ts): quem está mais longe não vem no snapshot.
const NEARBY_RADIUS: float = 45.0


## Outros jogadores (sem você) a até [param radius] m de você, vivos ou mortos, do mais perto ao mais longe
## (Menu → Jogadores Próximos, [SOC-02]). Só quem está na área de interesse ([member PlayerState.in_view]).
func get_nearby_players(radius: float = NEARBY_RADIUS) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	var own: PlayerState = get_player(player_id)
	if own == null:
		return result
	var origin: Vector3 = own.position
	for state: PlayerState in _players.values():
		if state.id == player_id or not state.in_view:
			continue
		if Vector2(state.x - origin.x, state.z - origin.z).length() <= radius:
			result.append(state)
	result.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		return Vector2(a.x - origin.x, a.z - origin.z).length_squared() < Vector2(b.x - origin.x, b.z - origin.z).length_squared())
	return result


## Pede os atributos do jogador [param target_id] ([SOC-02]). A resposta vem em [signal attributes_received]
## (ou erro [constant Protocol.ERR_PLAYER_NOT_FOUND] em [signal server_error]).
func send_inspect(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_INSPECT, {"playerId": target_id})


## true se [param id] é OUTRO jogador do meu grupo (aliado: não é alvo de ataque, cor de aliado, [SOC-03]).
func is_group_member(id: String) -> bool:
	return group != null and id != player_id and group.has(id)


## true se sou o líder do meu grupo.
func is_group_leader() -> bool:
	return group != null and group.leader_id == player_id


## true se há posição recente (de [constant Protocol.MSG_GROUP_POSITIONS]) do membro [param id], que está LONGE de mim
## (fora da área de interesse). Perto, a posição vem no snapshot ([method get_players]).
func has_group_far_position(id: String) -> bool:
	return _group_far.has(id) and is_group_member(id) and Time.get_ticks_msec() - _group_far_ms <= int(GROUP_POSITIONS_STALE_SECONDS * 1000.0)


## Posição no chão (x, z em m) do membro longe [param id] (ver [method has_group_far_position]); Vector2.ZERO se não há.
func group_far_position(id: String) -> Vector2:
	return _group_far.get(id, Vector2.ZERO)


## Convida [param target_id] para o grupo ([SOC-03]). Resposta: [signal group_notice] (aceitou/recusou/expirou) ou erro.
func send_group_invite(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_GROUP_INVITE, {"playerId": target_id})


## Responde ao convite de [param from_id] ([param accept] = aceitar).
func send_group_answer(from_id: String, accept: bool) -> void:
	if is_in_zone() and not from_id.is_empty():
		_send(Protocol.MSG_GROUP_ANSWER, {"fromId": from_id, "accept": accept})


## Líder expulsa [param target_id] do grupo.
func send_group_kick(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_GROUP_KICK, {"playerId": target_id})


## Sai do grupo.
func send_group_leave() -> void:
	if is_in_zone():
		_send(Protocol.MSG_GROUP_LEAVE, {})


## true se [param id] é meu amigo ([SOC-04]).
func is_friend(id: String) -> bool:
	return friends.has(id)


## Pede a amizade de [param target_id] ([SOC-04]). Resposta: [signal friend_notice] (aceitou/recusou/expirou) ou erro.
func send_friend_request(target_id: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_FRIEND_REQUEST, {"playerId": target_id})


## Responde ao pedido de amizade de [param from_id] ([param accept] = aceitar).
func send_friend_answer(from_id: String, accept: bool) -> void:
	if _authenticated and not from_id.is_empty():
		_send(Protocol.MSG_FRIEND_ANSWER, {"fromId": from_id, "accept": accept})


## Remove [param target_id] dos amigos (dos dois lados).
func send_friend_remove(target_id: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_FRIEND_REMOVE, {"playerId": target_id})


## Muda a Configuração social ([constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE]); o servidor salva
## na conta e confirma ([signal social_settings_changed]).
func send_social_settings(friend_requests: String, group_invites: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_SOCIAL_SETTINGS, {"friendRequests": friend_requests, "groupInvites": group_invites})


## Pede para vestir o item [param uid] da mochila. A resposta vem em [signal inventory_changed] (ou erro).
func send_equip(uid: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_EQUIP, {"uid": uid})


## Pede para tirar o item do [param slot] ("hand", "head", "chest", "feet") para a mochila: na vaga [param index]
## (arrastado até ela, [CLI-10]) ou, com −1, no fim.
func send_unequip(slot: String, index: int = -1) -> void:
	if not _authenticated:
		return
	var data: Dictionary = {"slot": slot}
	if index >= 0:
		data["index"] = index
	_send(Protocol.MSG_UNEQUIP, data)


## Pede para trocar de lugar os itens das vagas [param from] e [param to] da mochila (vaga livre = leva para o fim).
func send_bag_move(from: int, to: int) -> void:
	if _authenticated:
		_send(Protocol.MSG_BAG_MOVE, {"from": from, "to": to})


func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE) and _socket != null:
		# Fechar o app não é logout: a sessão continua salva para entrar direto da próxima vez.
		_socket.close(1000, "app fechado")


## Manda a mensagem de autenticação agora (conexão aberta) ou guarda e abre a conexão.
func _request_auth(type: String, data: Dictionary) -> void:
	last_error = ""
	if _authenticated:
		return
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send(type, data)
		return
	_pending_auth = {"type": type, "data": data}
	if _socket == null:
		_open_socket()


func _open_socket() -> void:
	_socket = WebSocketPeer.new()
	_worst_frame_ms = 0
	_last_packet_ms = Time.get_ticks_msec()
	_socket.inbound_buffer_size = _INBOUND_BUFFER_BYTES
	_socket.max_queued_packets = _MAX_QUEUED_PACKETS
	var url: String = NetworkConfig.server_url()
	var error: Error = _socket.connect_to_url(url)
	if error != OK:
		_socket = null
		_fail_connection(error, "URL do servidor inválida: %s" % url)
		return
	_was_open = false
	set_process(true)


func _process(delta: float) -> void:
	_clock_tick += delta * tick_rate
	var frame_ms: int = int(delta * 1000.0)
	if frame_ms > _worst_frame_ms:
		_worst_frame_ms = frame_ms
		_worst_frame_at_ms = Time.get_ticks_msec()
	_socket.poll()
	var state: WebSocketPeer.State = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		if not _pending_auth.is_empty():
			_send(Protocol.read_string(_pending_auth, "type"), Protocol.read_dict(_pending_auth, "data"))
			_pending_auth = {}

	# Atenção: o WebSocketPeer DESCARTA o que chega junto com o close (testado em 2026-11-14); por isso o servidor espera
	# CLOSE_DELAY_MS (mmo-server/src/GameServer.ts) entre o "error"/"update_required" e o fechamento.
	while _socket.get_available_packet_count() > 0:
		_last_packet_ms = Time.get_ticks_msec()
		_handle_message(_socket.get_packet().get_string_from_utf8())

	if state == WebSocketPeer.STATE_CLOSED:
		_on_closed()


func _send(type: String, data: Dictionary) -> void:
	_socket.send_text(Protocol.encode(type, data))


func _handle_message(text: String) -> void:
	var message: Dictionary = Protocol.decode(text)
	if message.is_empty():
		push_warning("Network: mensagem fora do protocolo: %s" % text)
		return
	var type: String = Protocol.read_string(message, "type")
	var data: Dictionary = Protocol.read_dict(message, "data")

	match type:
		Protocol.MSG_AUTH_OK:
			_authenticated = true
			player_id = Protocol.read_string(data, "playerId")
			username = Protocol.read_string(data, "username")
			var token: String = Protocol.read_string(data, "sessionToken")
			if not token.is_empty():
				AccountStorage.save_session_token(token)
			body = Protocol.read_string(data, "body")
			_apply_social_settings(Protocol.read_dict(data, "social"))
			authenticated.emit(username)
			# Primeira entrada: escolher o corpo antes de entrar na zona ([INFRA-07]).
			if body.is_empty():
				body_choice_needed.emit()
			else:
				_send(Protocol.MSG_JOIN, {"zone": NetworkConfig.ZONE_ID})
		Protocol.MSG_BODY_CHOSEN:
			body = Protocol.read_string(data, "body")
			body_chosen.emit(body)
			_send(Protocol.MSG_JOIN, {"zone": NetworkConfig.ZONE_ID})
		Protocol.MSG_WELCOME:
			var sim: Dictionary = Protocol.read_dict(data, "sim")
			tick_rate = Protocol.read_float(sim, "tickRate", tick_rate)
			move_speed = Protocol.read_float(sim, "moveSpeed", move_speed)
			zone_half_size = Protocol.read_float(sim, "zoneHalfSize", zone_half_size)
			_clock_tick = float(Protocol.read_int(data, "tick"))
			var pvp_value: Variant = data.get("pvp")
			pvp = pvp_value is bool and pvp_value == true
			_in_zone = true
			for npc: Dictionary in Protocol.read_dict_array(data, "npcs"):
				var npc_state: PlayerState = PlayerState.from_snapshot(npc, int(_clock_tick))
				if npc_state != null and not _npcs.has(npc_state.id):
					_npcs[npc_state.id] = npc_state
					npc_added.emit(npc_state.id, npc_state)
			# Lista primeiro: quem reagir ao joined_zone já encontra os jogadores em get_players().
			for info: Dictionary in Protocol.read_dict_array(data, "players"):
				_add_player(info)
			joined_zone.emit(player_id)
		Protocol.MSG_PLAYER_JOINED:
			_add_player(Protocol.read_dict(data, "player"))
		Protocol.MSG_PLAYER_LEFT:
			_remove_player(Protocol.read_string(data, "id"))
		Protocol.MSG_SNAPSHOT:
			_apply_snapshot(data)
		Protocol.MSG_INVENTORY:
			inventory = InventoryState.from_dict(data)
			inventory_changed.emit(inventory)
		Protocol.MSG_ATTRIBUTES:
			var attributes: PlayerAttributes = PlayerAttributes.from_dict(data)
			if attributes != null:
				attributes_received.emit(attributes)
		Protocol.MSG_GROUP:
			group = GroupState.from_dict(Protocol.read_dict(data, "group"))
			if group == null:
				_group_far.clear()
			group_changed.emit(group)
		Protocol.MSG_GROUP_POSITIONS:
			_apply_group_positions(data)
		Protocol.MSG_GROUP_INVITED:
			group_invited.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"), Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_GROUP_NOTICE:
			group_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_FRIENDS:
			friends = FriendList.from_dict(data)
			friends_changed.emit(friends)
		Protocol.MSG_FRIEND_REQUESTED:
			friend_requested.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"), Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_FRIEND_NOTICE:
			friend_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_SOCIAL_SETTINGS:
			_apply_social_settings(data)
		Protocol.MSG_UPDATE_REQUIRED:
			# Fecha já (o servidor também fecharia, com 4003, um pouco depois); no fechamento abre o LiveUpdater ([INFRA-08]).
			_update_version = maxi(Protocol.read_int(data, "version"), 1)
			print("[rede] pacote novo publicado (versão %d): atualizando" % _update_version)
			_socket.close(1000, "update")
		Protocol.MSG_ERROR:
			_handle_error(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		_:
			push_warning("Network: tipo de mensagem desconhecido: %s" % type)


## Guarda a Configuração social vinda do servidor (valor desconhecido/faltando = mostrar) e avisa.
func _apply_social_settings(data: Dictionary) -> void:
	var friend_requests: String = Protocol.read_string(data, "friendRequests")
	var group_invites: String = Protocol.read_string(data, "groupInvites")
	social_friend_requests = Protocol.SOCIAL_HIDE if friend_requests == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	social_group_invites = Protocol.SOCIAL_HIDE if group_invites == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	social_settings_changed.emit(social_friend_requests, social_group_invites)


func _handle_error(code: String, message: String) -> void:
	push_warning("Network: servidor recusou (%s): %s" % [code, message])
	last_error = message
	if code == Protocol.ERR_VERSION_MISMATCH and not PackInfo.is_dev():
		# Servidor com outro protocolo: quase sempre há pacote novo. O LiveUpdater confere o manifesto e, se não houver
		# versão nova, mostra a mensagem e "Tentar de novo" (sem laço de atualização).
		_update_version = UPDATE_UNKNOWN
		_socket.close(1000, "update")
		return
	if code in _AUTH_ERROR_CODES:
		if code == Protocol.ERR_INVALID_SESSION:
			AccountStorage.clear_session_token()
		auth_failed.emit(code, message)
	else:
		server_error.emit(code, message)


func _add_player(info: Dictionary) -> void:
	var state: PlayerState = PlayerState.from_snapshot(info, int(_clock_tick))
	if state == null or _players.has(state.id):
		return
	_players[state.id] = state
	player_added.emit(state.id, state)


## Guarda as posições dos membros do grupo longe ([constant Protocol.MSG_GROUP_POSITIONS]): a lista substitui a anterior
## (quem não veio está perto, no snapshot, ou saiu do grupo).
func _apply_group_positions(data: Dictionary) -> void:
	_group_far.clear()
	_group_far_ms = Time.get_ticks_msec()
	for entry: Dictionary in Protocol.read_dict_array(data, "members"):
		var id: String = Protocol.read_string(entry, "id")
		if not id.is_empty():
			_group_far[id] = Vector2(Protocol.read_float(entry, "x"), Protocol.read_float(entry, "z"))


## Aplica um snapshot: guarda o estado de cada jogador naquele tick, ajusta o relógio e avisa.
func _apply_snapshot(data: Dictionary) -> void:
	var server_tick: int = Protocol.read_int(data, "tick", -1)
	if server_tick < 0:
		return
	# Área de interesse ([INFRA-04]): só vem quem está perto; quem não veio fica fora de vista até voltar.
	for state: PlayerState in _players.values():
		state.in_view = state.id == player_id
	for state: PlayerState in _npcs.values():
		state.in_view = false
	for snapshot: Dictionary in Protocol.read_dict_array(data, "players"):
		if not Protocol.is_player_snapshot(snapshot):
			continue
		var id: String = Protocol.read_string(snapshot, "id")
		if _players.has(id):
			_players[id].apply_snapshot(snapshot, server_tick)
			_players[id].in_view = true
			# Membro do grupo voltou para perto: vale o snapshot, não a posição de longe (velha).
			_group_far.erase(id)
	for npc: Dictionary in Protocol.read_dict_array(data, "npcs"):
		var npc_id: String = Protocol.read_string(npc, "id")
		if _npcs.has(npc_id) and Protocol.is_player_snapshot(npc):
			_npcs[npc_id].apply_snapshot(npc, server_tick)
			_npcs[npc_id].in_view = true
	var me: Dictionary = Protocol.read_dict(data, "me")
	mana = Protocol.read_float(me, "mana", mana)
	max_mana = Protocol.read_float(me, "maxMana", max_mana)
	respawn_in = Protocol.read_float(me, "respawnIn")
	level = Protocol.read_int(me, "level", level)
	xp = Protocol.read_float(me, "xp", xp)
	xp_next = Protocol.read_float(me, "xpNext", xp_next)
	gold = Protocol.read_int(me, "gold", gold)
	attack_target = Protocol.read_string(me, "target")
	var casting: Dictionary = Protocol.read_dict(me, "casting")
	casting_target = Protocol.read_string(casting, "target")
	casting_remaining = Protocol.read_float(casting, "remaining")
	_sync_clock(server_tick)
	snapshot_received.emit(server_tick, Protocol.read_int(data, "ack"))
	for event: Dictionary in Protocol.read_dict_array(data, "events"):
		if Protocol.read_string(event, "type") == "look":
			# Jogador ou NPC humano (o atirador de teste troca de roupa, [JOGO-11]).
			var who: PlayerState = get_entity(Protocol.read_string(event, "id"))
			if who != null:
				who.set_look(Protocol.read_dict(event, "look"))
			continue
		combat_event.emit(event)


## Puxa o relógio local na direção do tick do servidor: aos poucos, ou de uma vez se estiver longe.
func _sync_clock(server_tick: int) -> void:
	var error: float = float(server_tick) - _clock_tick
	if absf(error) > _CLOCK_SNAP_TICKS:
		_clock_tick = float(server_tick)
	else:
		_clock_tick += error * _CLOCK_CORRECTION


func _remove_player(id: String) -> void:
	if _players.erase(id):
		player_removed.emit(id)


func _on_closed() -> void:
	var code: int = _socket.get_close_code()
	var reason: String = _socket.get_close_reason()
	var was_open: bool = _was_open
	_socket = null
	_was_open = false
	_authenticated = false
	_in_zone = false
	_pending_auth = {}
	player_id = ""
	username = ""
	body = ""
	inventory = null
	group = null
	_group_far.clear()
	friends = FriendList.new()
	social_friend_requests = Protocol.SOCIAL_ALWAYS
	social_group_invites = Protocol.SOCIAL_ALWAYS
	_npcs.clear()
	attack_target = ""
	set_process(false)

	for id: String in _players.keys():
		_remove_player(id)

	if _update_version != 0:
		# Pacote novo: nada de voltar ao login. O LiveUpdater tira este Network da árvore, baixa o pacote, carrega e
		# reabre o jogo (que entra direto com a sessão salva).
		_update_version = 0
		last_error = ""
		get_tree().change_scene_to_file(LIVE_UPDATER_SCENE)
		return
	if not was_open:
		_fail_connection(code, "Não foi possível conectar ao servidor.")
		return
	if code == Protocol.CLOSE_REPLACED:
		last_error = "Sua conta entrou em outro aparelho."
	elif last_error.is_empty() and code != 1000:
		var now: int = Time.get_ticks_msec()
		last_error = "Conexão perdida (código %d). Último dado há %.1f s; pior quadro %d ms (há %.0f s)." % [
			code, (now - _last_packet_ms) / 1000.0, _worst_frame_ms, (now - _worst_frame_at_ms) / 1000.0]
		print("[rede] ", last_error)
	left_zone.emit(code, reason)


func _fail_connection(code: int, message: String) -> void:
	last_error = message
	connection_error.emit(code, message)
