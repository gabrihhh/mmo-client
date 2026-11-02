class_name LoginScreen
extends Control
## Tela de login (primeira cena do jogo). Ver mmo-docs [CLI-05].
##
## Por enquanto só existe o botão "Entrar": conecta com a conta de convidado deste aparelho
## (criada no primeiro acesso) e, quando o servidor responde o welcome, abre a zona.
## Se a conexão falhar ou cair, o jogo volta para cá e mostra [member Network.last_error].

## Cena aberta depois de entrar.
const ZONE_SCENE: String = "res://scenes/world/zone_1.tscn"
## Dev/testes automáticos: `godot --path . -- --autologin` aperta "Entrar" sozinho ao abrir.
const AUTOLOGIN_ARG: String = "--autologin"

@onready var _enter_button: Button = %EnterButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_enter_button.pressed.connect(_on_enter_pressed)
	Network.joined_zone.connect(_on_joined_zone)
	Network.connection_error.connect(_on_connection_failed)
	Network.left_zone.connect(_on_left_zone)
	# Volta de uma desconexão: mostra o motivo.
	_status_label.text = Network.last_error
	_set_busy(Network.is_connecting_or_connected())
	# Só na primeira abertura: se voltou por desconexão, espera o jogador apertar.
	if AUTOLOGIN_ARG in OS.get_cmdline_user_args() and Network.last_error.is_empty():
		_on_enter_pressed()


func _on_enter_pressed() -> void:
	_set_busy(true)
	_status_label.text = "Conectando..."
	Network.connect_to_zone()


func _on_joined_zone(_player_id: String) -> void:
	get_tree().change_scene_to_file(ZONE_SCENE)


func _on_connection_failed(_code: int, _message: String) -> void:
	_show_error()


func _on_left_zone(_code: int, _reason: String) -> void:
	_show_error()


func _show_error() -> void:
	_set_busy(false)
	_status_label.text = Network.last_error


## Desabilita o botão enquanto conecta, para não abrir duas conexões.
func _set_busy(busy: bool) -> void:
	_enter_button.disabled = busy
