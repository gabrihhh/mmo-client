class_name SlashArc
extends MeshInstance3D
## Clarão do golpe corpo a corpo ([JOGO-08]): meia-lua na frente de quem bate (ou anel inteiro no Giro) que aparece
## no momento do golpe e some rápido. Só visual. Crie com [method spawn].

## Duração na tela (s).
const LIFETIME: float = 0.22
## Abertura da meia-lua (graus) e altura (m) acima do chão.
const ARC_DEGREES: float = 140.0
const HEIGHT: float = 1.0

## Malhas em cache: meia-lua e anel de raio 1 (a escala dá o tamanho).
static var _arc_mesh: ArrayMesh = null
static var _ring_mesh: ArrayMesh = null

var _age: float = 0.0
var _reach: float = 1.0
var _material: StandardMaterial3D = null


## Clarão em [param origin] (pés de quem bate), virado para [param yaw] (rad, igual ao rotation.y do personagem:
## a frente é −Z), com alcance [param reach] m. [param full_ring] = anel inteiro (golpe ao redor).
static func spawn(parent: Node, origin: Vector3, yaw: float, reach: float, full_ring: bool, color: Color) -> void:
	var slash: SlashArc = SlashArc.new()
	slash.mesh = _ring() if full_ring else _arc()
	slash._material = StandardMaterial3D.new()
	slash._material.albedo_color = Color(color, 0.6)
	slash._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slash._material.cull_mode = BaseMaterial3D.CULL_DISABLED
	slash.material_override = slash._material
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(slash)
	slash.global_position = origin + Vector3.UP * HEIGHT
	slash.rotation.y = yaw
	slash._reach = reach
	slash.scale = Vector3(reach, 1.0, reach)


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	_material.albedo_color.a = 0.6 * (1.0 - t)
	var size: float = _reach * (1.0 + 0.15 * t)  # abre um pouco enquanto some
	scale = Vector3(size, 1.0, size)
	if t >= 1.0:
		queue_free()


static func _arc() -> ArrayMesh:
	if _arc_mesh == null:
		_arc_mesh = _band(deg_to_rad(ARC_DEGREES), 12)
	return _arc_mesh


static func _ring() -> ArrayMesh:
	if _ring_mesh == null:
		_ring_mesh = _band(TAU, 24)
	return _ring_mesh


## Faixa plana (raio 0,55 a 1) de [param angle] rad centrada em −Z, em [param segments] pedaços.
static func _band(angle: float, segments: int) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i: int in range(segments):
		var a0: float = -angle * 0.5 + angle * float(i) / float(segments)
		var a1: float = -angle * 0.5 + angle * float(i + 1) / float(segments)
		var inner0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0)) * 0.55
		var outer0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
		var inner1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1)) * 0.55
		var outer1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
		for v: Vector3 in [inner0, outer0, outer1, inner0, outer1, inner1]:
			tool.add_vertex(v)
	return tool.commit()
