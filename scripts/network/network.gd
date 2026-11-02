extends Node
## Autoload "Network": única porta de entrada para o servidor do jogo.
##
## Usa o [WebSocketPeer] nativo do Godot (sem SDK de terceiros). O resto do jogo não
## fala com o socket: usa os sinais e métodos daqui.
## Login: conta de convidado (token guardado por [AccountStorage]). Ver mmo-docs [INFRA-04], [INFRA-07].

## Entrou na zona. A partir daqui [member player_id] é válido e [method get_players] tem a lista inicial.
signal joined_zone(player_id: String)
## Um jogador (inclusive o local) está na zona. [param state] é atualizado ao vivo pelo Network.
signal player_added(player_id: String, state: PlayerState)
## Um jogador saiu da zona.
signal player_removed(player_id: String)
## Não foi possível conectar (servidor fora do ar, URL errada...).
signal connection_error(code: int, message: String)
## O servidor recusou um pedido ou uma mensagem. [param code] é um código de erro do protocolo
## (ex.: "version_mismatch", "zone_full"); a lista está em mmo-server/src/net/protocol.ts.
signal server_error(code: String, message: String)
## A conexão fechou depois de aberta (saída, queda ou recusa). [param code] é o close code do WebSocket.
signal left_zone(code: int, reason: String)

## Id público do jogador deste aparelho (estável entre sessões); vazio enquanto não entrou.
var player_id: String = ""
## Última mensagem de erro/desconexão, em português, para a tela de login mostrar. Vazio = nenhuma.
var last_error: String = ""

var _socket: WebSocketPeer = null
## A conexão chegou a abrir (diferencia "não conectou" de "caiu depois").
var _was_open: bool = false
## Estados vivos dos jogadores da zona, por player id.
var _players: Dictionary[String, PlayerState] = {}


func _ready() -> void:
	set_process(false)


## Conecta ao servidor e entra na zona [constant NetworkConfig.ZONE_ID] com a conta de convidado
## deste aparelho (criada no primeiro acesso). Chamadas repetidas são ignoradas.
func connect_to_zone() -> void:
	if _socket != null:
		return
	last_error = ""
	_socket = WebSocketPeer.new()
	var url: String = NetworkConfig.server_url()
	var error: Error = _socket.connect_to_url(url)
	if error != OK:
		_socket = null
		_fail_connection(error, "URL do servidor inválida: %s" % url)
		return
	_was_open = false
	set_process(true)


## true enquanto conecta ou está conectado.
func is_connecting_or_connected() -> bool:
	return _socket != null


## true quando está dentro da zona com o WebSocket aberto.
func is_in_zone() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not player_id.is_empty()


## Jogadores atualmente na zona (inclusive o local). Usado por quem entra depois do [signal joined_zone],
## como a cena da zona, que é carregada depois do welcome.
func get_players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	result.assign(_players.values())
	return result


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


## Sai da zona fechando a conexão (o servidor salva a posição e remove o jogador).
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
		var token: String = AccountStorage.load_guest_token()
		_send(Protocol.MSG_JOIN, {
			"zone": NetworkConfig.ZONE_ID,
			"version": Protocol.VERSION,
			"guestToken": token if not token.is_empty() else null,
		})

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
			player_id = Protocol.read_string(data, "playerId")
			var token: String = Protocol.read_string(data, "guestToken")
			if not token.is_empty():
				AccountStorage.save_guest_token(token)
			# Lista primeiro: quem reagir ao joined_zone já encontra os jogadores em get_players().
			for snapshot: Dictionary in Protocol.read_dict_array(data, "players"):
				_add_player(snapshot)
			joined_zone.emit(player_id)
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
			last_error = "Servidor recusou: %s" % reason
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
	if id == player_id or not _players.has(id):
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
	player_id = ""
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
