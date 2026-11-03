class_name CharacterSelect
extends Node3D
## Escolha do personagem ([CLI-09], [INFRA-07]): aparece UMA vez, na primeira entrada da conta (o servidor manda
## `body: null` no auth_ok). A mulher fica à esquerda e o homem à direita, em pé, com a câmera perto na altura dos
## olhos e um campo florido, uma casa e montanhas ao fundo ([MeadowScenery]).
##
## Só sai daqui escolhendo: tocar num personagem (ou no botão embaixo dele) abre a confirmação ("é para sempre");
## confirmar manda `choose_body` → o servidor salva e o [Network] entra na zona → abre a zona.
## Se a conexão cair, volta para o login.

## Cena da zona (aberta quando o Network entra).
const ZONE_SCENE: String = "res://scenes/world/zone_1.tscn"
## Tela de login (se a conexão cair).
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"
## Distância (m) de cada personagem ao centro, em X.
const SIDE_OFFSET: float = 0.55
## Quanto cada um gira para dentro (graus), para ficarem de frente um pouco um para o outro.
const INWARD_TURN: float = 12.0
## Nome de cada corpo na tela.
const BODY_TITLES: Dictionary[String, String] = {Protocol.BODY_FEMALE: "Mulher", Protocol.BODY_MALE: "Homem"}

@onready var _camera: Camera3D = $Camera
@onready var _characters: Node3D = $Characters
@onready var _female_button: Button = %FemaleButton
@onready var _male_button: Button = %MaleButton
@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _confirm_label: Label = %ConfirmLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _status_label: Label = %StatusLabel
@onready var _hint_label: Label = %HintLabel

## Modelo de cada corpo (para destacar o escolhido).
var _models: Dictionary[String, CharacterModel] = {}
## Corpo aguardando confirmação ("" = nenhum).
var _pending: String = ""


func _ready() -> void:
	if Network.instance == null:
		get_tree().change_scene_to_file.call_deferred(GameBoot.SCENE)
		return
	var network: Network = Network.instance
	network.joined_zone.connect(_on_joined_zone)
	network.server_error.connect(_on_server_error)
	network.connection_error.connect(_on_disconnected)
	network.left_zone.connect(_on_disconnected)

	_add_character(Protocol.BODY_FEMALE, -SIDE_OFFSET, INWARD_TURN)
	_add_character(Protocol.BODY_MALE, SIDE_OFFSET, -INWARD_TURN)
	_female_button.pressed.connect(_ask.bind(Protocol.BODY_FEMALE))
	_male_button.pressed.connect(_ask.bind(Protocol.BODY_MALE))
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_close_confirm)
	_confirm_panel.visible = false
	_status_label.text = ""


func _add_character(body: String, x: float, turn_degrees: float) -> void:
	var model: CharacterModel = CharacterBodies.instantiate(body)
	model.position = Vector3(x, 0.0, 0.0)
	model.rotation.y = deg_to_rad(turn_degrees)
	_characters.add_child(model)
	model.set_shirt_color(Color(0.85, 0.85, 0.85))
	_models[body] = model


## Toque na tela fora dos botões: escolhe o personagem do lado tocado (esquerda = mulher, direita = homem).
func _unhandled_input(event: InputEvent) -> void:
	if _confirm_panel.visible or not _status_label.text.is_empty():
		return
	var position: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		position = (event as InputEventMouseButton).position
	if position == Vector2.INF:
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5
	_ask(Protocol.BODY_FEMALE if position.x < half else Protocol.BODY_MALE)
	get_viewport().set_input_as_handled()


## Abre a confirmação para [param body] (a escolha é para sempre).
func _ask(body: String) -> void:
	_pending = body
	_confirm_label.text = "Jogar com %s?\nEssa escolha não poderá ser mudada depois." % BODY_TITLES[body].to_lower()
	_confirm_panel.visible = true
	# Só o escolhido fica na tela enquanto confirma (destaque).
	for other: String in _models:
		_models[other].visible = other == body


func _close_confirm() -> void:
	_pending = ""
	_confirm_panel.visible = false
	for model: CharacterModel in _models.values():
		model.visible = true


func _on_confirm() -> void:
	if _pending.is_empty():
		return
	_confirm_panel.visible = false
	_female_button.disabled = true
	_male_button.disabled = true
	_status_label.text = "Entrando..."
	Network.instance.choose_body(_pending)


func _on_joined_zone(_player_id: String) -> void:
	get_tree().change_scene_to_file(ZONE_SCENE)


## Recusa do servidor: mostra a mensagem no lugar da dica e deixa escolher de novo.
func _on_server_error(_code: String, message: String) -> void:
	_status_label.text = ""
	_female_button.disabled = false
	_male_button.disabled = false
	_close_confirm()
	_hint_label.text = message


func _on_disconnected(_code: int, _message: String) -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)
