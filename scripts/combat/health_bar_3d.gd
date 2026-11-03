class_name HealthBar3D
extends Node3D
## Barra de vida acima da cabeça, sempre de frente para a câmera. Ver mmo-docs [JOGO-05].
## Só visual: chame [method set_ratio] com a fração de vida (0..1).
##
## O nó inteiro copia a rotação da câmera a cada quadro (em vez de billboard no material): assim o
## preenchimento, ancorado na borda esquerda do nó, encolhe para a esquerda da TELA.

## Tamanho da barra no mundo, em metros.
@export var bar_size: Vector2 = Vector2(0.85, 0.13)
@export var fill_color: Color = Color(0.85, 0.2, 0.2)
@export var back_color: Color = Color(0, 0, 0, 0.6)

var _fill: MeshInstance3D = null


func _ready() -> void:
	_make_quad(back_color, Vector3.ZERO, 0)
	# O preenchimento começa na borda esquerda e encolhe para a esquerda.
	_fill = _make_quad(fill_color, Vector3(-bar_size.x / 2.0, 0.0, 0.001), 1)
	set_ratio(1.0)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		global_basis = camera.global_basis


## Fração de vida mostrada (0 = vazia, 1 = cheia).
func set_ratio(ratio: float) -> void:
	if _fill != null:
		_fill.scale.x = maxf(0.001, clampf(ratio, 0.0, 1.0))


func _make_quad(color: Color, offset: Vector3, priority: int) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = bar_size
	# Com o centro deslocado meia barra, a escala X encolhe a partir da borda esquerda.
	quad.center_offset = Vector3(bar_size.x / 2.0, 0.0, 0.0) if priority > 0 else Vector3.ZERO
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = priority
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
