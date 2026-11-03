class_name ShieldBubble
extends MeshInstance3D
## Bolha translúcida em volta de quem está com escudo ([JOGO-06]). Só visual: quem decide o escudo é o
## servidor (campo `shield` do snapshot). Chame [method set_active].

## Cor da bolha (azul claro, bem transparente).
const _COLOR: Color = Color(0.45, 0.75, 1.0, 0.28)


func _ready() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 2.2
	mesh = sphere
	position = Vector3(0.0, 0.95, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Mostra a bolha enquanto houver escudo.
func set_active(active: bool) -> void:
	visible = active
