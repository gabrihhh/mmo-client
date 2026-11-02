extends Node
## Autoload "Network": única porta de entrada para o servidor Colyseus.
##
## O resto do jogo não fala com o SDK diretamente: usa os sinais e métodos daqui.
## Contrato de mensagens e estado: mmo-docs [INFRA-04].

## Entrou na zona. A partir daqui [member session_id] é válido.
signal joined_zone(session_id: String)
## Um jogador (inclusive o local) apareceu no estado da zona.
signal player_added(session_id: String, state: ZoneSchema.PlayerState)
## Um jogador saiu da zona.
signal player_removed(session_id: String)
## Falha ao conectar ou erro da room.
signal connection_error(code: int, message: String)
## Saiu da room (desconexão ou saída voluntária).
signal left_zone(code: int, reason: String)

## Tipo da mensagem de movimento (mmo-server/src/rooms/messages.ts → MessageType.Move).
const MSG_MOVE: String = "move"

## Id da sessão deste cliente na room; vazio enquanto não conectado.
var session_id: String = ""

var _client: Colyseus.Client = null
var _room: Colyseus.Room = null
var _callbacks: Colyseus.Callbacks = null


## Conecta (ou cria) a room de zona. Chamadas repetidas são ignoradas.
func connect_to_zone() -> void:
	if _room != null:
		return

	_client = Colyseus.Client.new(NetworkConfig.server_url())
	_room = _client.join_or_create(NetworkConfig.ZONE_ROOM_NAME)
	if _room == null:
		connection_error.emit(-1, "Não foi possível criar a conexão. O SDK do Colyseus está instalado?")
		return

	# Precisa ser chamado antes do "joined" para o estado vir tipado.
	_room.set_state_type(ZoneSchema.State)
	_room.joined.connect(_on_joined)
	_room.error.connect(_on_error)
	_room.left.connect(_on_left)

	# Registros feitos antes de entrar valem após o "joined" e repetem o que já existe.
	_callbacks = Colyseus.Callbacks.of(_room)
	_callbacks.on_add("players", _on_player_add)
	_callbacks.on_remove("players", _on_player_remove)


## true quando está dentro da room com o WebSocket aberto.
func is_in_zone() -> bool:
	return _room != null and _room.connected


## Envia a posição/rotação do jogador local. Ignorado se não estiver conectado.
func send_move(world_position: Vector3, rot_y: float) -> void:
	if not is_in_zone():
		return
	_room.send_message(MSG_MOVE, {
		"x": world_position.x,
		"y": world_position.y,
		"z": world_position.z,
		"rotY": rot_y,
	})


## Sai da room (o servidor remove o jogador na hora).
func leave_zone() -> void:
	if is_in_zone():
		_room.leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		leave_zone()


func _on_joined() -> void:
	session_id = _room.get_session_id()
	joined_zone.emit(session_id)


func _on_player_add(state: Variant, key: String) -> void:
	var player_state: ZoneSchema.PlayerState = state as ZoneSchema.PlayerState
	if player_state == null:
		push_error("Network: estado de jogador sem tipo; set_state_type falhou?")
		return
	player_added.emit(key, player_state)


func _on_player_remove(_state: Variant, key: String) -> void:
	player_removed.emit(key)


func _on_error(code: int, message: String) -> void:
	push_warning("Network: erro %d: %s" % [code, message])
	connection_error.emit(code, message)


func _on_left(code: int, reason: String) -> void:
	session_id = ""
	_room = null
	_callbacks = null
	left_zone.emit(code, reason)
