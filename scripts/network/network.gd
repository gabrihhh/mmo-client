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
		_request_auth(Protocol.MSG_RESUME, {"version": Protocol.VERSION, "sessionToken": token})


## Entra com username OU e-mail + senha.
func login(login_name: String, password: String) -> void:
	_request_auth(Protocol.MSG_LOGIN, {"version": Protocol.VERSION, "login": login_name.strip_edges(), "password": password})


## Cria a conta e já entra nela. O username fica exatamente como foi digitado (sem espaços nas pontas).
func register(new_username: String, email: String, password: String) -> void:
	_request_auth(Protocol.MSG_REGISTER, {
		"version": Protocol.VERSION,
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


## Pede para vestir o item [param uid] da mochila. A resposta vem em [signal inventory_changed] (ou erro).
func send_equip(uid: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_EQUIP, {"uid": uid})


## Pede para tirar o item do [param slot] ("hand", "head", "chest", "feet") para a mochila.
func send_unequip(slot: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_UNEQUIP, {"slot": slot})


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
	_socket.poll()
	var state: WebSocketPeer.State = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		if not _pending_auth.is_empty():
			_send(Protocol.read_string(_pending_auth, "type"), Protocol.read_dict(_pending_auth, "data"))
			_pending_auth = {}

	# Lê também depois de fechado: o "error" que precede uma recusa pode ainda estar na fila.
	while _socket.get_available_packet_count() > 0:
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
		Protocol.MSG_ERROR:
			_handle_error(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		_:
			push_warning("Network: tipo de mensagem desconhecido: %s" % type)


func _handle_error(code: String, message: String) -> void:
	push_warning("Network: servidor recusou (%s): %s" % [code, message])
	last_error = message
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


## Aplica um snapshot: guarda o estado de cada jogador naquele tick, ajusta o relógio e avisa.
func _apply_snapshot(data: Dictionary) -> void:
	var server_tick: int = Protocol.read_int(data, "tick", -1)
	if server_tick < 0:
		return
	for snapshot: Dictionary in Protocol.read_dict_array(data, "players"):
		if not Protocol.is_player_snapshot(snapshot):
			continue
		var id: String = Protocol.read_string(snapshot, "id")
		if _players.has(id):
			_players[id].apply_snapshot(snapshot, server_tick)
	for npc: Dictionary in Protocol.read_dict_array(data, "npcs"):
		var npc_id: String = Protocol.read_string(npc, "id")
		if _npcs.has(npc_id) and Protocol.is_player_snapshot(npc):
			_npcs[npc_id].apply_snapshot(npc, server_tick)
	var me: Dictionary = Protocol.read_dict(data, "me")
	mana = Protocol.read_float(me, "mana", mana)
	max_mana = Protocol.read_float(me, "maxMana", max_mana)
	respawn_in = Protocol.read_float(me, "respawnIn")
	level = Protocol.read_int(me, "level", level)
	xp = Protocol.read_float(me, "xp", xp)
	xp_next = Protocol.read_float(me, "xpNext", xp_next)
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
	_npcs.clear()
	attack_target = ""
	set_process(false)

	for id: String in _players.keys():
		_remove_player(id)

	if not was_open:
		_fail_connection(code, "Não foi possível conectar ao servidor.")
		return
	if code == Protocol.CLOSE_REPLACED:
		last_error = "Sua conta entrou em outro aparelho."
	elif last_error.is_empty() and code != 1000:
		last_error = "Conexão perdida (código %d)." % code
	left_zone.emit(code, reason)


func _fail_connection(code: int, message: String) -> void:
	last_error = message
	connection_error.emit(code, message)
