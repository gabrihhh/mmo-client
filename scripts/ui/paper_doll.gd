class_name PaperDoll
extends Control
## Vitrine "vestido" do inventário ([CLI-10]): o **seu personagem em 3D** (o mesmo modelo do jogo, com o corpo e os
## itens vestidos de verdade, [CharacterModel]) no meio, num pedestal, e um quadro ([ItemSlot]) por slot nas laterais:
## Cabeça, Peito e Pés à esquerda (na altura de cada parte do corpo) e a Arma à direita, na altura da mão.
## Arrastar o dedo (ou o mouse) em cima do boneco o gira; tocar num quadro emite [signal slot_pressed]. Os quadros
## e o boneco são alvos de arrastar itens ([InventoryView]).
##
## O 3D é desenhado num [SubViewport] com mundo próprio (não mistura com a zona) e fundo transparente. Só processa
## (animação, desenho) enquanto a vitrine está na tela.

## Tocou no quadro do [param slot] ("hand", "head", "chest", "feet").
signal slot_pressed(slot: String)

## Tamanho dos quadros, em px.
const SLOT_SIZE: float = 104.0
## Espaço (px) entre a borda da vitrine e o conteúdo: o tamanho da moldura pixel art (contorno + dourado).
const FRAME_INSET_PX: float = 34.0
## Espaço (px) entre os quadros e o boneco.
const GAP_PX: float = 10.0
## Altura (fração da área útil, de cima) do centro do quadro de cada slot; à esquerda menos a arma.
const SLOT_HEIGHTS: Dictionary[String, float] = {"head": 0.17, "chest": 0.47, "feet": 0.86, "hand": 0.55}
## Texto pequeno embaixo de cada quadro.
const SLOT_CAPTION_FONT: int = 16
## Moldura pixel art da vitrine (a mesma das molduras da HUD).
const FRAME_TEXTURE: Texture2D = preload("res://assets/ui/pixel/frame.png")
## Fundo da vitrine: degradê do centro (claro, quente) para as bordas (escuro).
const BACKDROP_CENTER: Color = Color(0.36, 0.27, 0.19)
const BACKDROP_EDGE: Color = Color(0.1, 0.07, 0.05)
## Câmera do boneco: altura e distância (m) e campo de visão vertical (graus). O personagem tem ~1,8 m.
const CAMERA_HEIGHT: float = 1.0
const CAMERA_DISTANCE: float = 3.9
const CAMERA_LOOK_HEIGHT: float = 0.88
const CAMERA_FOV: float = 32.0
## Giro inicial do boneco (graus; 0 = de frente) e quanto gira por px arrastado (graus).
const START_TURN_DEGREES: float = -18.0
const TURN_DEGREES_PER_PX: float = 0.6

var _slots: Dictionary[String, ItemSlot] = {}
var _viewport_box: SubViewportContainer = null
var _viewport: SubViewport = null
## Raiz do mundo 3D da vitrine (gira o boneco).
var _turntable: Node3D = null
var _model: CharacterModel = null
var _model_body: String = ""
## Estado seguido pelo boneco (o jogador local); a aparência acompanha [signal PlayerState.look_changed].
var _state: PlayerState = null
var _turn_degrees: float = START_TURN_DEGREES
var _turning: bool = false
var _gradient: GradientTexture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_build_backdrop()
	_build_viewport()
	for slot: String in InventoryState.SLOTS:
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		view.size = view.custom_minimum_size
		view.draggable = true
		view.pressed.connect(slot_pressed.emit.bind(slot))
		add_child(view)
		_slots[slot] = view
	resized.connect(_place)
	_place()


## Mostra o que [param inventory] tem vestido nos quadros.
func show_inventory(inventory: InventoryState) -> void:
	for slot: String in _slots:
		_slots[slot].show_item(inventory.item_in(slot), AbilityView.SLOT_LABELS[slot])


## Boneco 3D de [param state] (o jogador local: corpo e o que veste). Troca o modelo se o corpo mudou.
func show_character(state: PlayerState) -> void:
	_state = state
	if state == null:
		return
	if _model == null or _model_body != state.body:
		if _model != null:
			_model.queue_free()
		_model = CharacterBodies.instantiate(state.body)
		_model_body = state.body
		_turntable.add_child(_model)
		_model.set_shirt_color(Color(0.85, 0.85, 0.85))
	_model.bind_look(state)
	_refresh_processing()


## Quadro do [param slot] (alvo de soltar item).
func slot_view(slot: String) -> ItemSlot:
	return _slots[slot]


## Todos os quadros, por slot.
func slot_views() -> Dictionary[String, ItemSlot]:
	return _slots


## Área do boneco em coordenadas de tela (soltar um item aqui = vestir no slot dele).
func character_global_rect() -> Rect2:
	return _viewport_box.get_global_rect()


## Destaca o boneco como alvo de soltar (1 pode, 0 nenhum).
func set_character_highlight(on: bool) -> void:
	_viewport_box.modulate = Color(1.15, 1.25, 1.1) if on else Color.WHITE


func _build_backdrop() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BACKDROP_CENTER)
	gradient.set_color(1, BACKDROP_EDGE)
	_gradient = GradientTexture2D.new()
	_gradient.gradient = gradient
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.5, 0.42)
	_gradient.fill_to = Vector2(1.05, 1.0)
	_gradient.width = 64
	_gradient.height = 64


func _build_viewport() -> void:
	_viewport_box = SubViewportContainer.new()
	_viewport_box.stretch = true
	_viewport_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_box.gui_input.connect(_on_character_input)
	add_child(_viewport_box)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport_box.add_child(_viewport)

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.82, 0.78)
	environment.ambient_light_energy = 0.55
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.15
	_viewport.add_child(key)
	# Luz de recorte fria por trás: separa o boneco do fundo.
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 0.6
	_viewport.add_child(rim)

	var camera: Camera3D = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, CAMERA_LOOK_HEIGHT, 0.0))

	_turntable = Node3D.new()
	_turntable.rotation_degrees.y = _turn_degrees
	_viewport.add_child(_turntable)


## Arrastar em cima do boneco gira ele (o toque chega como mouse emulado).
func _on_character_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_turning = (event as InputEventMouseButton).pressed
		_viewport_box.accept_event()
	elif event is InputEventMouseMotion and _turning:
		_turn_degrees += (event as InputEventMouseMotion).relative.x * TURN_DEGREES_PER_PX
		_turntable.rotation_degrees.y = _turn_degrees
		_viewport_box.accept_event()


## O mundo 3D só anima enquanto a vitrine está na tela.
func _refresh_processing() -> void:
	if _turntable == null:
		return
	var showing: bool = is_visible_in_tree()
	_turntable.process_mode = Node.PROCESS_MODE_INHERIT if showing else Node.PROCESS_MODE_DISABLED
	if showing:
		# Volta a ficar de frente (meio de lado) a cada vez que abre.
		_turn_degrees = START_TURN_DEGREES
		_turntable.rotation_degrees.y = _turn_degrees


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh_processing()


## Área útil (dentro da moldura).
func _inner() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-FRAME_INSET_PX)


func _place() -> void:
	var inner: Rect2 = _inner()
	var caption_room: float = SLOT_CAPTION_FONT + 4.0
	for slot: String in _slots:
		var view: ItemSlot = _slots[slot]
		var x: float = inner.position.x if slot != "hand" else inner.end.x - SLOT_SIZE
		var center_y: float = inner.position.y + SLOT_HEIGHTS[slot] * (inner.size.y - caption_room)
		var y: float = clampf(center_y - SLOT_SIZE / 2.0, inner.position.y, inner.end.y - SLOT_SIZE - caption_room)
		view.position = Vector2(x, y)
	var left: float = inner.position.x + SLOT_SIZE + GAP_PX
	var right: float = inner.end.x - SLOT_SIZE - GAP_PX
	_viewport_box.position = Vector2(left, inner.position.y)
	_viewport_box.size = Vector2(maxf(1.0, right - left), inner.size.y)
	queue_redraw()


func _draw() -> void:
	var inner: Rect2 = _inner()
	# Fundo em degradê (holofote no boneco) e o pedestal: elipse escura com borda dourada embaixo dos pés.
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size).grow(-8.0), false)
	var pedestal_center: Vector2 = Vector2(size.x / 2.0, inner.end.y - inner.size.y * 0.05)
	var radius: Vector2 = Vector2(minf(inner.size.x * 0.24, 120.0), 22.0)
	_draw_ellipse(pedestal_center + Vector2(0.0, 6.0), radius + Vector2(10.0, 6.0), Color(0, 0, 0, 0.35))
	_draw_ellipse(pedestal_center, radius + Vector2(4.0, 3.0), Color(0.83, 0.62, 0.26))
	_draw_ellipse(pedestal_center, radius, Color(0.2, 0.14, 0.1))
	# Moldura pixel art da HUD (frame.png em 9-slice, margem 24 px), [CLI-08].
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = FRAME_TEXTURE
	box.set_texture_margin_all(24.0)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	# Nome do slot embaixo de cada quadro.
	var font: Font = get_theme_default_font()
	for slot: String in _slots:
		var view: ItemSlot = _slots[slot]
		var text: String = AbilityView.SLOT_LABELS[slot]
		var at: Vector2 = Vector2(view.position.x, view.position.y + SLOT_SIZE + SLOT_CAPTION_FONT + 1.0)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, SLOT_CAPTION_FONT, Color(1, 0.92, 0.8, 0.7))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(32):
		var angle: float = TAU * float(k) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
