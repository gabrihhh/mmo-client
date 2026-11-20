class_name GroundWarning
extends Node3D
## Aviso no chão durante o lançamento de outro jogador ([JOGO-08]): todos veem onde vai cair e podem sair.
##
## - [method spawn_area]: círculo da área (Meteoro) com um disco de dentro que cresce até o momento do impacto.
## - [method spawn_line]: faixa da direção (Bola de fogo) da posição de quem lança até o alcance.
## - [method spawn_cone]: leque do golpe de monstro ([JOGO-05]) com o preenchimento crescendo até o golpe.
## Some sozinho quando o lançamento termina (o impacto em si é o [ImpactFlash]).

## Altura (m) acima do chão (não brigar com o terreno).
const HEIGHT: float = 0.04

var _duration: float = 0.0
var _age: float = 0.0
var _fill: MeshInstance3D = null
## Leque: alcance (m) do preenchimento quando cheio (o círculo usa escala 1 = raio cheio).
var _fill_reach: float = 1.0


## Círculo de [param radius] m em ([param x], [param z]) por [param duration] s. Devolve o aviso (para tirar antes,
## se o lançamento for cancelado).
static func spawn_area(parent: Node, x: float, z: float, radius: float, duration: float, color: Color) -> GroundWarning:
	var warning: GroundWarning = GroundWarning.new()
	warning._duration = maxf(duration, 0.1)
	warning.add_child(_disc(radius, Color(color, 0.25)))
	warning._fill = _disc(radius, Color(color, 0.35))
	warning._fill.scale = Vector3(0.01, 1.0, 0.01)
	warning.add_child(warning._fill)
	parent.add_child(warning)
	warning.global_position = Vector3(x, ZoneTerrain.height_at(x, z) + HEIGHT, z)
	return warning


## Faixa de [param from] até [param to] (no chão), com meia-largura [param half_width] m, por [param duration] s.
## Devolve o aviso, ou null se a faixa for curta demais.
static func spawn_line(parent: Node, from: Vector3, to: Vector3, half_width: float, duration: float, color: Color) -> GroundWarning:
	var flat: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length() < 0.1:
		return null
	var warning: GroundWarning = GroundWarning.new()
	warning._duration = maxf(duration, 0.1)
	var strip: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(maxf(half_width, 0.2) * 2.0, 0.02, flat.length())
	strip.mesh = box
	strip.material_override = _material(Color(color, 0.3))
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(0.0, 0.0, -flat.length() * 0.5)
	warning.add_child(strip)
	parent.add_child(warning)
	warning.global_position = Vector3(from.x, ZoneTerrain.height_at(from.x, from.z) + HEIGHT, from.z)
	# −Z do aviso aponta para o alvo.
	warning.rotation.y = atan2(-flat.x, -flat.z)
	return warning


## Leque de [param reach] m e abertura total [param arc] rad, saindo de [param from] na direção de [param to] (no chão),
## por [param duration] s (golpe de monstro: dá para sair, [JOGO-05]). O preenchimento cresce até o golpe.
static func spawn_cone(parent: Node, from: Vector3, to: Vector3, reach: float, arc: float, duration: float, color: Color) -> GroundWarning:
	var flat: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length() < 0.05 or reach <= 0.0:
		return null
	var warning: GroundWarning = GroundWarning.new()
	warning._duration = maxf(duration, 0.1)
	var outline: MeshInstance3D = _wedge_instance(arc, Color(color, 0.25))
	outline.scale = Vector3(reach, 1.0, reach)
	warning.add_child(outline)
	warning._fill = _wedge_instance(arc, Color(color, 0.35))
	warning._fill.scale = Vector3(0.01, 1.0, 0.01)
	warning._fill_reach = reach
	warning.add_child(warning._fill)
	parent.add_child(warning)
	warning.global_position = Vector3(from.x, ZoneTerrain.height_at(from.x, from.z) + HEIGHT, from.z)
	# −Z do aviso aponta para a direção do golpe.
	warning.rotation.y = atan2(-flat.x, -flat.z)
	return warning


## Leque plano de raio 1 e abertura total [param arc] rad centrado em −Z (centro na origem), em [param segments] fatias.
## Usado também pela prévia do ⚔ ([AimPreview]).
static func wedge(arc: float, segments: int = 16) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i: int in range(segments):
		var a0: float = -arc * 0.5 + arc * float(i) / float(segments)
		var a1: float = -arc * 0.5 + arc * float(i + 1) / float(segments)
		for v: Vector3 in [Vector3.ZERO, Vector3(sin(a0), 0.0, -cos(a0)), Vector3(sin(a1), 0.0, -cos(a1))]:
			tool.add_vertex(v)
	return tool.commit()


static func _wedge_instance(arc: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = wedge(arc)
	var material: StandardMaterial3D = _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _process(delta: float) -> void:
	_age += delta
	if _fill != null:
		var t: float = clampf(_age / _duration, 0.01, 1.0)
		_fill.scale = Vector3(t * _fill_reach, 1.0, t * _fill_reach)
	if _age >= _duration:
		queue_free()


static func _disc(radius: float, color: Color) -> MeshInstance3D:
	var disc: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 24
	disc.mesh = mesh
	disc.material_override = _material(color)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
