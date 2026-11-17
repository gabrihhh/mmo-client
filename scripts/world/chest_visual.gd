class_name ChestVisual
extends Node3D
## Baú de um acampamento no mundo ([JOGO-19]): flutua acima da fogueira, balançando devagar. Fechado: só a caixa de
## madeira com faixas de metal. Aberto (o acampamento foi derrotado): a tampa abre e sai um brilho dourado de dentro.
## O do acampamento com chefe é maior e tem as faixas douradas. Feito por código (caixas low poly, sem luz de verdade:
## leve no celular) e só anima quando está na tela.
## Também é o **baú grande do Armazém** na praça ([JOGO-26], [method setup_storage]): no chão, parado, fechado, maior,
## faixas douradas e o nome em cima.

## Altura (m) do fundo do baú acima do chão da fogueira, e quanto ele sobe e desce (m) e em quantos segundos.
const HOVER_HEIGHT: float = 1.7
const BOB_AMPLITUDE: float = 0.08
const BOB_SECONDS: float = 2.4
## Tamanho (m) da caixa: largura, altura do corpo, profundidade, altura da tampa.
const BODY_SIZE: Vector3 = Vector3(0.9, 0.42, 0.6)
const LID_HEIGHT: float = 0.18
## Quanto a tampa gira ao abrir (rad) e quão rápido.
const LID_OPEN_ANGLE: float = -1.9
const LID_SPEED: float = 4.0
## Escala do baú de acampamento com chefe.
const BOSS_SCALE: float = 1.3
## Escala do baú do Armazém ([JOGO-26]) e giro em Y (graus, quase de frente para a câmera isométrica).
const STORAGE_SCALE: float = 2.2
const STORAGE_FACING_DEGREES: float = 35.0
const WOOD: Color = Color(0.48, 0.3, 0.16)
const WOOD_DARK: Color = Color(0.33, 0.2, 0.1)
const METAL: Color = Color(0.32, 0.33, 0.36)
const GOLD: Color = Color(1.0, 0.8, 0.3)

var _lid_pivot: Node3D = null
var _glow: MeshInstance3D = null
var _open: bool = false
var _lid_angle: float = 0.0
var _time: float = 0.0
var _on_screen: bool = true
var _base_y: float = 0.0
## Baú do Armazém: no chão e sem balançar.
var _still: bool = false


## Baú de [param chest] posto no chão em [param ground_y] (m).
func setup(chest: ChestInfo, ground_y: float) -> void:
	position = Vector3(chest.x, ground_y, chest.z)
	_base_y = HOVER_HEIGHT
	_open = chest.open
	_lid_angle = LID_OPEN_ANGLE if _open else 0.0
	if chest.boss:
		scale = Vector3.ONE * BOSS_SCALE
	set_meta("boss", chest.boss)


## Baú do Armazém ([JOGO-26]) no lugar do NPC `storage` do servidor ([param state]), no chão da zona, com o nome.
func setup_storage(state: PlayerState) -> void:
	name = "Storage_%s" % state.id
	position = Vector3(state.x, ZoneTerrain.height_at(state.x, state.z), state.z)
	rotation_degrees.y = STORAGE_FACING_DEGREES
	scale = Vector3.ONE * STORAGE_SCALE
	_still = true
	set_meta("boss", true)
	var label: Label3D = Label3D.new()
	label.text = state.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0065 / STORAGE_SCALE
	label.font_size = 40
	label.outline_size = 10
	label.position = Vector3(0.0, 1.0, 0.0)
	label.modulate = Color(1.0, 0.85, 0.45)
	add_child(label)


func _ready() -> void:
	var boss: bool = get_meta("boss", false)
	var band: Color = GOLD if boss else METAL
	var body: Node3D = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.add_child(_box(BODY_SIZE, Vector3(0.0, BODY_SIZE.y / 2.0, 0.0), WOOD))
	# Faixas de metal nas laterais e a fechadura na frente.
	for side: float in [-1.0, 1.0]:
		body.add_child(_box(Vector3(0.07, BODY_SIZE.y + 0.02, BODY_SIZE.z + 0.02), Vector3(side * BODY_SIZE.x * 0.32, BODY_SIZE.y / 2.0, 0.0), band))
	body.add_child(_box(Vector3(0.12, 0.14, 0.04), Vector3(0.0, BODY_SIZE.y * 0.75, BODY_SIZE.z / 2.0 + 0.02), band))
	# Tampa: gira em volta da aresta de trás de cima.
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0.0, BODY_SIZE.y, -BODY_SIZE.z / 2.0)
	body.add_child(_lid_pivot)
	_lid_pivot.add_child(_box(Vector3(BODY_SIZE.x + 0.02, LID_HEIGHT, BODY_SIZE.z + 0.02), Vector3(0.0, LID_HEIGHT / 2.0, BODY_SIZE.z / 2.0), WOOD_DARK))
	for side: float in [-1.0, 1.0]:
		_lid_pivot.add_child(_box(Vector3(0.07, LID_HEIGHT + 0.02, BODY_SIZE.z + 0.04), Vector3(side * BODY_SIZE.x * 0.32, LID_HEIGHT / 2.0, BODY_SIZE.z / 2.0), band))
	# Brilho de dentro (aparece aberto).
	_glow = _box(Vector3(BODY_SIZE.x * 0.85, 0.05, BODY_SIZE.z * 0.8), Vector3(0.0, BODY_SIZE.y - 0.02, 0.0), GOLD, true)
	body.add_child(_glow)
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, HOVER_HEIGHT + 1.2, 1.6))
	notifier.screen_entered.connect(func() -> void: _on_screen = true)
	notifier.screen_exited.connect(func() -> void: _on_screen = false)
	add_child(notifier)
	_animate(0.0)


## Abre ou fecha (a tampa gira aos poucos).
func set_open(open: bool) -> void:
	_open = open


func _process(delta: float) -> void:
	if _on_screen:
		_animate(delta)


func _animate(delta: float) -> void:
	_time += delta
	var body: Node3D = get_node_or_null("Body") as Node3D
	if body == null:
		return
	if _still:
		body.position.y = 0.0
	else:
		body.position.y = _base_y + sin(_time * TAU / BOB_SECONDS) * BOB_AMPLITUDE
		body.rotation.y = sin(_time * 0.4) * 0.25
	_lid_angle = move_toward(_lid_angle, LID_OPEN_ANGLE if _open else 0.0, LID_SPEED * delta)
	_lid_pivot.rotation.x = _lid_angle
	_glow.visible = _open
	if _open:
		_glow.scale = Vector3.ONE * (1.0 + 0.08 * sin(_time * 6.0))


func _box(size: Vector3, at: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	return instance
