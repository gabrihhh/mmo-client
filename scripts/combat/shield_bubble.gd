class_name ShieldBubble
extends MeshInstance3D
## Bolha translúcida em volta de quem está com escudo ([JOGO-06]) ou com redução de dano ([JOGO-09]). Só visual:
## quem decide é o servidor (campos `shield` e `guard` do snapshot). Chame [method set_active].

## Cor da bolha de escudo (azul claro, bem transparente).
const _COLOR: Color = Color(0.45, 0.75, 1.0, 0.28)
## Cor da bolha de redução de dano sem escudo (dourada).
const _GUARD_COLOR: Color = Color(1.0, 0.8, 0.3, 0.26)

var _material: StandardMaterial3D = null


func _ready() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 2.2
	mesh = sphere
	position = Vector3(0.0, 0.95, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	_material = material
	material.albedo_color = _COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Mostra a bolha enquanto houver escudo ([param shielded], azul) ou redução de dano ([param guarded], dourada).
func set_active(shielded: bool, guarded: bool = false) -> void:
	visible = shielded or guarded
	if _material != null:
		_material.albedo_color = _COLOR if shielded else _GUARD_COLOR
