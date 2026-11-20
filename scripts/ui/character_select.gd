class_name CharacterSelect
extends Node3D
## Escolha do personagem ([CLI-09], [INFRA-07]): aparece UMA vez, na primeira entrada da conta (o servidor manda
## `body: null` no auth_ok). Dois passos:
##
## 1. **Corpo:** a mulher fica à esquerda e o homem à direita, em pé, com a câmera perto na altura dos olhos e um campo
##    florido, uma casa e montanhas ao fundo ([MeadowScenery]). Tocar num personagem (ou no botão embaixo dele) leva
##    ao passo 2.
## 2. **Classe:** só o corpo escolhido fica na tela, no meio e mais para cima; embaixo, uma linha por classe com o
##    ícone da arma ao lado do nome da classe e do perfil ("Pouco dano · Muita vida"). Tocar numa linha põe a arma na
##    mão do personagem; "Começar" abre a confirmação ("é para sempre"). Uma arma só, e a do Curandeiro não entra
##    ([constant STARTER_CLASSES]). "Voltar" volta para o passo 1.
##
## Confirmar manda `choose_body` com o corpo e a arma → o servidor salva, veste a arma, e o [Network] entra na zona →
## abre a zona. Se a conexão cair, volta para o login.

## Tela de login (se a conexão cair).
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"
## Distância (m) de cada personagem ao centro, em X.
const SIDE_OFFSET: float = 0.55
## Quanto cada um gira para dentro (graus), para ficarem de frente um pouco um para o outro.
const INWARD_TURN: float = 12.0
## Nome de cada corpo na tela.
const BODY_TITLES: Dictionary[String, String] = {Protocol.BODY_FEMALE: "Mulher", Protocol.BODY_MALE: "Homem"}
## Classes que dá para escolher na primeira entrada, na ordem da tela: arma (itemId), classe (= `set` do item, dá a
## cor), nome da arma, perfil ([JOGO-09]) em palavras simples e quanto girar o personagem (graus) para a pose parada
## daquela arma ficar de frente para a câmera (a da espada longa é de lado). O Curandeiro fica de fora (pedido do dono).
## ATENÇÃO: espelho de STARTER_WEAPONS em mmo-server/src/items/catalog.ts (o servidor recusa arma fora da lista).
const STARTER_CLASSES: Array[Dictionary] = [
	{"weapon": "knight_sword", "class": "Cavaleiro", "weapon_name": "Espada longa",
		"profile": "Pouco dano · Muita vida", "idea": "Aguenta a pancada na frente do grupo", "turn": 40.0},
	{"weapon": "arcane_staff", "class": "Mago", "weapon_name": "Cajado arcano",
		"profile": "Dano médio · Pouca vida", "idea": "Ataca de longe, com magias em área", "turn": 0.0},
	{"weapon": "ranger_crossbow", "class": "Atirador", "weapon_name": "Besta de caça",
		"profile": "Dano médio · Pouca vida", "idea": "O alcance mais longo de todos", "turn": 0.0},
	{"weapon": "assassin_daggers", "class": "Assassino", "weapon_name": "Adagas gêmeas",
		"profile": "Muito dano · Pouca vida", "idea": "Golpes fortíssimos, mas que demoram a voltar", "turn": 0.0},
]
## Altura (px, na tela de 720×1280) de cada linha de classe.
const CLASS_ROW_HEIGHT: float = 100.0
## Lado (px) do ícone da arma em cada linha (pixel art 48×48 ampliada).
const CLASS_ICON_SIZE: float = 76.0
## Deslocamento vertical da câmera (m) no passo 2: sobe a imagem para o personagem ficar acima da lista de classes.
const CLASS_STEP_CAMERA_V_OFFSET: float = -1.15
## Quanto a câmera recua (m) no passo 2, para caber o corpo inteiro na parte de cima da tela.
const CLASS_STEP_CAMERA_BACK: float = 0.3

@onready var _camera: Camera3D = $Camera
@onready var _characters: Node3D = $Characters
@onready var _title: Label = $UI/Root/Title
@onready var _body_buttons: HBoxContainer = $UI/Root/Buttons
@onready var _female_button: Button = %FemaleButton
@onready var _male_button: Button = %MaleButton
@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _confirm_label: Label = %ConfirmLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _status_label: Label = %StatusLabel
@onready var _hint_label: Label = %HintLabel
@onready var _ui_root: Control = $UI/Root

## Modelo de cada corpo (para destacar o escolhido).
var _models: Dictionary[String, CharacterModel] = {}
## Posição/rotação original de cada modelo (passo 1).
var _model_homes: Dictionary[String, Transform3D] = {}
## O que cada modelo veste na prévia (só a arma da classe escolhida).
var _preview_states: Dictionary[String, PlayerState] = {}
## Corpo escolhido no passo 1 ("" = ainda no passo 1).
var _body: String = ""
## Arma escolhida no passo 2 ("" = nenhuma ainda).
var _weapon: String = ""
## Passo 2: lista de classes + botões.
var _class_step: VBoxContainer = null
## Linha de cada classe, por arma (para destacar a escolhida).
var _class_rows: Dictionary[String, Button] = {}
## "Começar" (habilitado depois de escolher a classe).
var _start_button: Button = null
## Câmera do passo 1 (para voltar).
var _camera_home: Transform3D = Transform3D.IDENTITY
## Texto original do título e da dica (passo 1).
var _title_body_step: String = ""
var _hint_body_step: String = ""


func _ready() -> void:
	if Network.instance == null:
		get_tree().change_scene_to_file.call_deferred(GameBoot.SCENE)
		return
	var network: Network = Network.instance
	network.joined_zone.connect(_on_joined_zone)
	network.server_error.connect(_on_server_error)
	network.connection_error.connect(_on_disconnected)
	network.left_zone.connect(_on_disconnected)

	_camera_home = _camera.transform
	_title_body_step = _title.text
	_hint_body_step = _hint_label.text
	_add_character(Protocol.BODY_FEMALE, -SIDE_OFFSET, INWARD_TURN)
	_add_character(Protocol.BODY_MALE, SIDE_OFFSET, -INWARD_TURN)
	_female_button.pressed.connect(_choose_body.bind(Protocol.BODY_FEMALE))
	_male_button.pressed.connect(_choose_body.bind(Protocol.BODY_MALE))
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_close_confirm)
	_confirm_panel.visible = false
	_status_label.text = ""
	_build_class_step()


func _add_character(body: String, x: float, turn_degrees: float) -> void:
	var model: CharacterModel = CharacterBodies.instantiate(body)
	model.position = Vector3(x, 0.0, 0.0)
	model.rotation.y = deg_to_rad(turn_degrees)
	_characters.add_child(model)
	model.set_shirt_color(Color(0.85, 0.85, 0.85))
	var state: PlayerState = PlayerState.new()
	state.body = body
	model.bind_look(state)
	_models[body] = model
	_model_homes[body] = model.transform
	_preview_states[body] = state


## Monta o passo 2 (escondido até escolher o corpo): uma linha por classe e, embaixo, "Voltar" e "Começar".
func _build_class_step() -> void:
	_class_step = VBoxContainer.new()
	_class_step.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_class_step.offset_left = 24.0
	_class_step.offset_right = -24.0
	_class_step.offset_bottom = -40.0
	_class_step.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_class_step.add_theme_constant_override("separation", 10)
	_class_step.visible = false
	_ui_root.add_child(_class_step)
	for entry: Dictionary in STARTER_CLASSES:
		var row: Button = _make_class_row(entry)
		_class_step.add_child(row)
		_class_rows[str(entry["weapon"])] = row
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	_class_step.add_child(buttons)
	var back: Button = Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(0.0, 88.0)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_back_to_body_step)
	buttons.add_child(back)
	_start_button = Button.new()
	_start_button.text = "Começar"
	_start_button.custom_minimum_size = Vector2(0.0, 88.0)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.size_flags_stretch_ratio = 1.6
	_start_button.add_theme_font_size_override("font_size", 30)
	_start_button.disabled = true
	_start_button.pressed.connect(_ask_confirm)
	buttons.add_child(_start_button)


## Uma linha de classe: ícone da arma (na moldura da cor do conjunto) e, ao lado, classe, arma, perfil e a ideia.
func _make_class_row(entry: Dictionary) -> Button:
	var weapon: String = str(entry["weapon"])
	var set_color: Color = ItemIcons.set_color(str(entry["class"]))
	var row: Button = Button.new()
	row.toggle_mode = true
	row.custom_minimum_size = Vector2(0.0, CLASS_ROW_HEIGHT)
	row.pressed.connect(_choose_class.bind(weapon))

	var box: HBoxContainer = HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_right = -12.0
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)

	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	frame_style.border_color = set_color
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(8)
	frame_style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", frame_style)
	box.add_child(frame)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemIcons.item(weapon)
	icon.custom_minimum_size = Vector2(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(texts)
	var title: Label = _make_label("%s  ·  %s" % [entry["class"], entry["weapon_name"]], 28, set_color.lightened(0.25))
	texts.add_child(title)
	texts.add_child(_make_label(str(entry["profile"]), 23, Color(1.0, 0.92, 0.75)))
	texts.add_child(_make_label(str(entry["idea"]), 19, Color(1.0, 1.0, 1.0, 0.75)))
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("outline_size", 4)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Toque na tela fora dos botões (só no passo 1): escolhe o personagem do lado tocado (esquerda = mulher).
func _unhandled_input(event: InputEvent) -> void:
	if not _body.is_empty() or not _status_label.text.is_empty():
		return
	var position: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		position = (event as InputEventMouseButton).position
	if position == Vector2.INF:
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5
	_choose_body(Protocol.BODY_FEMALE if position.x < half else Protocol.BODY_MALE)
	get_viewport().set_input_as_handled()


## Passo 1 → 2: só [param body] fica na tela, no meio e de frente, com a lista de classes embaixo.
func _choose_body(body: String) -> void:
	_body = body
	for other: String in _models:
		var model: CharacterModel = _models[other]
		model.visible = other == body
		if other == body:
			model.position = Vector3.ZERO
			model.rotation = Vector3.ZERO
	var camera: Transform3D = _camera_home
	camera.origin.z += CLASS_STEP_CAMERA_BACK
	_camera.transform = camera
	_camera.v_offset = CLASS_STEP_CAMERA_V_OFFSET
	_body_buttons.visible = false
	_class_step.visible = true
	_title.text = "Escolha sua classe"
	_hint_label.text = "Você ganha uma arma. As outras saem dos baús."
	if not _weapon.is_empty():
		_choose_class(_weapon)


## Passo 2 → 1: os dois corpos de volta, sem arma.
func _back_to_body_step() -> void:
	_close_confirm()
	if not _body.is_empty():
		_preview_states[_body].set_look({})
	_body = ""
	_weapon = ""
	for body: String in _models:
		_models[body].visible = true
		_models[body].transform = _model_homes[body]
	_camera.transform = _camera_home
	_camera.v_offset = 0.0
	for row: Button in _class_rows.values():
		row.button_pressed = false
	_start_button.disabled = true
	_class_step.visible = false
	_body_buttons.visible = true
	_title.text = _title_body_step
	_hint_label.text = _hint_body_step


## Escolhe a classe da arma [param weapon]: destaca a linha e põe a arma na mão do personagem.
func _choose_class(weapon: String) -> void:
	_weapon = weapon
	for other: String in _class_rows:
		_class_rows[other].button_pressed = other == weapon
	_preview_states[_body].set_look({"hand": weapon})
	_models[_body].rotation.y = deg_to_rad(float(_class_entry(weapon).get("turn", 0.0)))
	_start_button.disabled = false


func _class_entry(weapon: String) -> Dictionary:
	for entry: Dictionary in STARTER_CLASSES:
		if entry["weapon"] == weapon:
			return entry
	return {}


## "Começar": confirmação final (corpo e arma valem para sempre).
func _ask_confirm() -> void:
	if _body.is_empty() or _weapon.is_empty():
		return
	var entry: Dictionary = _class_entry(_weapon)
	_confirm_label.text = "%s · %s (%s)\nO personagem não poderá ser mudado depois." % [
		BODY_TITLES[_body], entry["class"], entry["weapon_name"]]
	_class_step.visible = false
	_confirm_panel.visible = true


func _close_confirm() -> void:
	_confirm_panel.visible = false
	if not _body.is_empty():
		_class_step.visible = true


func _on_confirm() -> void:
	if _body.is_empty() or _weapon.is_empty():
		return
	_confirm_panel.visible = false
	_status_label.text = "Entrando..."
	Network.instance.choose_body(_body, _weapon)


func _on_joined_zone(_player_id: String) -> void:
	# Dois welcome seguidos (voltou para a arena e a partida acabou na hora): o segundo chega com esta tela já saindo.
	if not is_inside_tree():
		return
	# A zona comum ou, voltando para uma partida em andamento, a arena do Coliseu ([JOGO-28]). A cena aberta confere
	# de novo o tipo da zona ao abrir (Zone._ready).
	get_tree().change_scene_to_file.call_deferred(Network.instance.zone_scene())


## Recusa do servidor: mostra a mensagem no lugar da dica e deixa escolher de novo (no passo 2).
func _on_server_error(_code: String, message: String) -> void:
	_status_label.text = ""
	_close_confirm()
	_hint_label.text = message


func _on_disconnected(_code: int, _message: String) -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)
