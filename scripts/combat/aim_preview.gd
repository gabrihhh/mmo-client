class_name AimPreview
extends Node3D
## Prévia translúcida da mira no chão, a partir do personagem ([JOGO-02]): linha (direção/alvo),
## círculo num ponto (área), anel ao redor (área própria) e o marcador do alvo fixo.
## Só visual: não decide nada.

## Altura acima do chão para não piscar com ele (z-fighting), em metros.
const _GROUND_OFFSET: float = 0.04
## Cor da prévia (mesmo dourado da UI), com opacidade reduzida.
const _COLOR: Color = Color(1.0, 0.85, 0.6, 0.35)
const _TARGET_COLOR: Color = Color(1.0, 0.35, 0.3, 0.6)

var _line: MeshInstance3D = null
var _circle: MeshInstance3D = null
var _target_ring: MeshInstance3D = null


func _ready() -> void:
	top_level = true
	_line = _make_mesh(_quad(), _COLOR)
	_circle = _make_mesh(_disc(1.0), _COLOR)
	_target_ring = _make_mesh(_disc(0.8), _TARGET_COLOR)
	hide_aim()
	hide_target()


## Linha de [param origin] na [param direction] (XZ, normalizada), com [param length] e [param width] em metros.
func show_line(origin: Vector3, direction: Vector3, length: float, width: float) -> void:
	_circle.visible = false
	_line.visible = true
	_line.scale = Vector3(width, 1.0, maxf(0.01, length))
	_line.global_position = origin + direction * (length / 2.0) + Vector3.UP * _GROUND_OFFSET
	_line.rotation = Vector3(0.0, atan2(direction.x, direction.z), 0.0)


## Círculo de [param radius] m centrado em [param center]; com [param line_from] != INF, também a linha até ele.
func show_circle(center: Vector3, radius: float, line_from: Vector3 = Vector3.INF) -> void:
	_circle.visible = true
	_circle.scale = Vector3(radius, 1.0, radius)
	_circle.global_position = center + Vector3.UP * _GROUND_OFFSET
	if line_from == Vector3.INF:
		_line.visible = false
	else:
		var flat: Vector3 = Vector3(center.x - line_from.x, 0.0, center.z - line_from.z)
		if flat.length() > 0.05:
			show_line(line_from, flat.normalized(), flat.length(), 0.15)
			_circle.visible = true


func hide_aim() -> void:
	_line.visible = false
	_circle.visible = false


## Marcador do alvo fixo embaixo de [param position].
func show_target(target_position: Vector3) -> void:
	_target_ring.visible = true
	_target_ring.global_position = target_position + Vector3.UP * (_GROUND_OFFSET * 2.0)


func hide_target() -> void:
	_target_ring.visible = false


func _make_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Plano 1x1 deitado (escala vira largura x comprimento).
func _quad() -> PlaneMesh:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	return plane


## Disco de raio [param radius] (escala multiplica o raio).
func _disc(radius: float) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.01
	cylinder.radial_segments = 32
	return cylinder
