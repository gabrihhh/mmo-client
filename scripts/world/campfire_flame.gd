class_name CampfireFlame
extends Node3D
## Fogo animado de uma fogueira dos acampamentos ([JOGO-18]): três chamas low poly (cones sem luz, cor própria) que
## tremem e giram, e brasas que sobem e somem. A lenha e as pedras vêm do mapa do Blender (objeto `fogueira_*`);
## isto fica em cima delas ([Zone1Scenery] põe uma por fogueira de [ZoneInfo]).
##
## Leve para o celular: sem luz de verdade nem partículas da GPU, malhas e materiais divididos por todas as
## fogueiras, e só anima quando está na tela ([VisibleOnScreenNotifier3D]).

## Cores das chamas (de fora para dentro) e das brasas.
const FLAME_COLORS: Array[Color] = [Color(0.95, 0.35, 0.08), Color(1.0, 0.62, 0.12), Color(1.0, 0.92, 0.45)]
const EMBER_COLOR: Color = Color(1.0, 0.55, 0.15)
## Altura (m) e raio (m) da chama maior, num fogo de tamanho 1.
const FLAME_HEIGHT: float = 1.0
const FLAME_RADIUS: float = 0.42
## Quantas brasas, quanto sobem (m) e em quantos segundos.
const EMBER_COUNT: int = 4
const EMBER_RISE: float = 1.8
const EMBER_SECONDS: float = 1.4

static var _flame_mesh: CylinderMesh = null
static var _ember_mesh: BoxMesh = null
static var _materials: Array[StandardMaterial3D] = []
static var _ember_material: StandardMaterial3D = null

var _flames: Array[Node3D] = []
var _embers: Array[MeshInstance3D] = []
var _time: float = 0.0
## Fase própria (fogueiras vizinhas não tremem iguais).
var _phase: float = 0.0
var _on_screen: bool = false


## Fogo de tamanho [param size] (1 = fogueira comum; ~1,5 = a grande do forte/trono) com fase [param phase] (rad).
func setup(size: float, phase: float) -> void:
	scale = Vector3.ONE * clampf(size, 0.5, 3.0)
	_phase = phase


func _ready() -> void:
	_build_shared()
	for i: int in range(FLAME_COLORS.size()):
		# Pivô no chão: a chama cresce para cima (o CylinderMesh nasce centrado).
		var flame: Node3D = Node3D.new()
		flame.position.y = 0.08
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.mesh = _flame_mesh
		cone.material_override = _materials[i]
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.position.y = FLAME_HEIGHT / 2.0
		flame.add_child(cone)
		add_child(flame)
		_flames.append(flame)
	for i: int in range(EMBER_COUNT):
		var ember: MeshInstance3D = MeshInstance3D.new()
		ember.mesh = _ember_mesh
		ember.material_override = _ember_material
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ember)
		_embers.append(ember)
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 2.2, 1.2))
	notifier.screen_entered.connect(func() -> void: _on_screen = true)
	notifier.screen_exited.connect(func() -> void: _on_screen = false)
	add_child(notifier)
	_animate(0.0)


func _process(delta: float) -> void:
	if not _on_screen:
		return
	_animate(delta)


func _animate(delta: float) -> void:
	_time += delta
	var t: float = _time + _phase
	for i: int in range(_flames.size()):
		var flame: Node3D = _flames[i]
		var base: float = 1.0 - 0.28 * i
		var flicker: float = 1.0 + 0.16 * sin(t * (9.0 + i * 2.3)) + 0.08 * sin(t * (17.0 + i * 3.1))
		flame.scale = Vector3(base * (1.0 - 0.06 * sin(t * 11.0 + i)), base * flicker, base * (1.0 + 0.06 * sin(t * 13.0 + i)))
		flame.rotation.y = t * (0.8 + 0.5 * i) * (1.0 if i % 2 == 0 else -1.0)
	for i: int in range(_embers.size()):
		var ember: MeshInstance3D = _embers[i]
		var life: float = fposmod(t / EMBER_SECONDS + float(i) / EMBER_COUNT, 1.0)
		var angle: float = float(i) * 2.4 + t * 0.7
		ember.position = Vector3(cos(angle) * 0.18 * (1.0 + life), 0.3 + life * EMBER_RISE, sin(angle) * 0.18 * (1.0 + life))
		ember.scale = Vector3.ONE * (1.0 - life)


static func _build_shared() -> void:
	if _flame_mesh != null:
		return
	_flame_mesh = CylinderMesh.new()
	_flame_mesh.top_radius = 0.0
	_flame_mesh.bottom_radius = FLAME_RADIUS
	_flame_mesh.height = FLAME_HEIGHT
	_flame_mesh.radial_segments = 5
	_flame_mesh.rings = 1
	_flame_mesh.cap_bottom = false
	_ember_mesh = BoxMesh.new()
	_ember_mesh.size = Vector3(0.07, 0.07, 0.07)
	for color: Color in FLAME_COLORS:
		_materials.append(_unshaded(color))
	_ember_material = _unshaded(EMBER_COLOR)


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
