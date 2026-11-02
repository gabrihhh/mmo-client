extends Node
## Autoload "Network": única porta de entrada para o servidor do jogo.
##
## Usa o [WebSocketPeer] nativo do Godot (sem SDK de terceiros). O resto do jogo não
## fala com o socket: usa os sinais e métodos daqui.
## Contrato de mensagens: [Protocol] e mmo-docs [INFRA-04].

## Entrou na zona. A partir daqui [member session_id] é válido.
signal joined_zone(session_id: String)
## Um jogador (inclusive o local) está na zona. [param state] é atualizado ao vivo pelo Network.
signal player_added(session_id: String, state: PlayerState)
## Um jogador saiu da zona.
signal player_removed(session_id: String)
## Não foi possível conectar (servidor fora do ar, URL errada...).
signal connection_error(code: int, message: String)
## O servidor recusou um pedido ou uma mensagem. [param code] é um código de erro do protocolo
## (ex.: "version_mismatch", "zone_full"); a lista está em mmo-server/src/net/protocol.ts.
signal server_error(code: String, message: String)
## A conexão fechou depois de aberta (saída, queda ou recusa). [param code] é o close code do WebSocket.
signal left_zone(code: int, reason: String)

## Id da sessão deste cliente na zona; vazio enquanto não entrou.
var session_id: String = ""

var _socket: WebSocketPeer = null
## A conexão chegou a abrir (diferencia "não conectou" de "caiu depois").
var _was_open: bool = false
## Estados vivos dos jogadores da zona, por session id.
var _players: Dictionary[String, PlayerState] = {}


func _ready() -> void:
	set_process(false)


## Conecta ao servidor e entra na zona [constant NetworkConfig.ZONE_ID]. Chamadas repetidas são ignoradas.
func connect_to_zone() -> void:
	if _socket != null:
		return
	_socket = WebSocketPeer.new()
	var url: String = NetworkConfig.server_url()
	var error: Error = _socket.connect_to_url(url)
	if error != OK:
		_socket = null
		connection_error.emit(error, "URL do servidor inválida: %s" % url)
		return
	_was_open = false
	set_process(true)


## true quando está dentro da zona com o WebSocket aberto.
func is_in_zone() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not session_id.is_empty()


## Envia a posição/rotação do jogador local. Ignorado se não estiver na zona.
func send_move(world_position: Vector3, rot_y: float) -> void:
	if not is_in_zone():
		return
	_send(Protocol.MSG_MOVE, {
		"x": world_position.x,
		"y": world_position.y,
		"z": world_position.z,
		"rotY": rot_y,
	})


## Sai da zona fechando a conexão (o servidor remove o jogador na hora).
func leave_zone() -> void:
	if _socket != null:
		_socket.close(1000, "leave")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		leave_zone()


func _process(_delta: float) -> void:
	_socket.poll()
	var state: WebSocketPeer.State = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		_send(Protocol.MSG_JOIN, {"zone": NetworkConfig.ZONE_ID, "version": Protocol.VERSION})

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
		Protocol.MSG_WELCOME:
			session_id = Protocol.read_string(data, "sessionId")
			joined_zone.emit(session_id)
			for snapshot: Dictionary in Protocol.read_dict_array(data, "players"):
				_add_player(snapshot)
		Protocol.MSG_PLAYER_JOINED:
			_add_player(Protocol.read_dict(data, "player"))
		Protocol.MSG_PLAYER_LEFT:
			_remove_player(Protocol.read_string(data, "id"))
		Protocol.MSG_POSITIONS:
			for snapshot: Dictionary in Protocol.read_dict_array(data, "players"):
				_update_player(snapshot)
		Protocol.MSG_ERROR:
			var code: String = Protocol.read_string(data, "code")
			var reason: String = Protocol.read_string(data, "message")
			push_warning("Network: servidor recusou (%s): %s" % [code, reason])
			server_error.emit(code, reason)
		_:
			push_warning("Network: tipo de mensagem desconhecido: %s" % type)


func _add_player(snapshot: Dictionary) -> void:
	var state: PlayerState = PlayerState.from_snapshot(snapshot)
	if state == null or _players.has(state.id):
		return
	_players[state.id] = state
	player_added.emit(state.id, state)


func _update_player(snapshot: Dictionary) -> void:
	if not Protocol.is_player_snapshot(snapshot):
		return
	var id: String = Protocol.read_string(snapshot, "id")
	# O próprio jogador é autoritativo sobre a posição dele: ignora o eco do servidor.
	if id == session_id or not _players.has(id):
		return
	_players[id].apply_snapshot(snapshot)


func _remove_player(id: String) -> void:
	if _players.erase(id):
		player_removed.emit(id)


func _on_closed() -> void:
	var code: int = _socket.get_close_code()
	var reason: String = _socket.get_close_reason()
	var was_open: bool = _was_open
	_socket = null
	_was_open = false
	session_id = ""
	set_process(false)

	for id: String in _players.keys():
		_remove_player(id)

	if was_open:
		left_zone.emit(code, reason)
	else:
		connection_error.emit(code, "Não foi possível conectar a %s" % NetworkConfig.server_url())
