class_name Zone
extends Node3D
## Cena de uma zona do mundo: conecta ao servidor e cria/remove os jogadores.
##
## Fluxo: conecta → servidor adiciona o jogador → [signal Network.player_added]
## → se for o próprio session id cria o [LocalPlayer], senão um [RemotePlayer].

const LOCAL_PLAYER_SCENE: PackedScene = preload("res://scenes/player/local_player.tscn")
const REMOTE_PLAYER_SCENE: PackedScene = preload("res://scenes/player/remote_player.tscn")

@onready var _players_root: Node3D = $Players
@onready var _joystick: TouchJoystick = $HUD/TouchJoystick
@onready var _status_label: Label = $HUD/StatusLabel

var _local_player: LocalPlayer = null
var _remote_players: Dictionary[String, RemotePlayer] = {}


func _ready() -> void:
	Network.joined_zone.connect(_on_joined_zone)
	Network.player_added.connect(_on_player_added)
	Network.player_removed.connect(_on_player_removed)
	Network.connection_error.connect(_on_connection_error)
	Network.server_error.connect(_on_server_error)
	Network.left_zone.connect(_on_left_zone)

	_set_status("Conectando a %s..." % NetworkConfig.server_url())
	Network.connect_to_zone()


func _on_joined_zone(_session_id: String) -> void:
	_update_online_status()


func _on_player_added(session_id: String, state: PlayerState) -> void:
	if session_id == Network.session_id:
		_spawn_local_player(state)
	elif not _remote_players.has(session_id):
		var remote: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
		remote.setup(session_id, state)
		remote.name = "Remote_%s" % session_id
		_players_root.add_child(remote)
		_remote_players[session_id] = remote
	_update_online_status()


func _on_player_removed(session_id: String) -> void:
	if _remote_players.has(session_id):
		# Subscript de Dictionary tipado já devolve RemotePlayer (get() devolveria Variant).
		var remote: RemotePlayer = _remote_players[session_id]
		remote.queue_free()
		_remote_players.erase(session_id)
	_update_online_status()


func _on_connection_error(code: int, message: String) -> void:
	_set_status("Erro de conexão (%d): %s" % [code, message])


func _on_server_error(code: String, message: String) -> void:
	_set_status("Servidor recusou (%s): %s" % [code, message])


func _on_left_zone(code: int, reason: String) -> void:
	_set_status("Desconectado (%d) %s" % [code, reason])


func _spawn_local_player(state: PlayerState) -> void:
	if _local_player != null:
		return
	_local_player = LOCAL_PLAYER_SCENE.instantiate() as LocalPlayer
	_local_player.name = "LocalPlayer"
	_local_player.joystick = _joystick
	_players_root.add_child(_local_player)
	_local_player.spawn_at(state.position, state.rot_y)


func _update_online_status() -> void:
	var online: int = _remote_players.size() + (1 if _local_player != null else 0)
	_set_status("Online: %d jogador(es)" % online)


func _set_status(text: String) -> void:
	_status_label.text = text
