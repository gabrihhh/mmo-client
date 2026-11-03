class_name ImpactFlash
extends MeshInstance3D
## Círculo no chão que aparece e some rápido onde uma área/projétil bateu ([JOGO-06]). Crie com [method spawn].

## Duração na tela, em segundos.
const LIFETIME: float = 0.45

var _age: float = 0.0
var _material: StandardMaterial3D = null


## Cria o círculo de [param radius] metros em ([param x], 0, [param z]) dentro de [param parent].
static func spawn(parent: Node, x: float, z: float, radius: float) -> void:
	var flash: ImpactFlash = ImpactFlash.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = maxf(radius, 0.6)
	disc.bottom_radius = disc.top_radius
	disc.height = 0.02
	disc.radial_segments = 32
	flash.mesh = disc
	flash._material = StandardMaterial3D.new()
	flash._material.albedo_color = Color(1.0, 0.55, 0.2, 0.55)
	flash._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = flash._material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = Vector3(x, 0.06, z)


func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / LIFETIME
	_material.albedo_color.a = 0.55 * (1.0 - t)
	scale = Vector3.ONE * (1.0 + 0.15 * t)
	if _age >= LIFETIME:
		queue_free()
