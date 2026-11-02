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
## Para onde voltar quando a conexão cai.
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"

@onready var _players_root: Node3D = $Players
@onready var _hud: Hud = $Hud

var _local_player: LocalPlayer = null
var _remote_players: Dictionary[String, RemotePlayer] = {}
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
	_update_online_status()


## Jogadores remotos presentes (para mira e alvo).
func get_remote_players() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	result.assign(_remote_players.values())
	return result


## Jogador remoto pelo id, ou null.
func get_remote_player(player_id: String) -> RemotePlayer:
	if not _remote_players.has(player_id):
		return null
	return _remote_players[player_id]


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
