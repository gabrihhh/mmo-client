class_name FloatingText
extends Label3D
## Número que sobe e some (dano, cura). Ver mmo-docs [JOGO-05]. Crie com [method spawn].

## Duração na tela, em segundos.
const LIFETIME: float = 0.9
## Quanto sobe no total, em metros.
const RISE: float = 1.2

var _age: float = 0.0
var _start: Vector3 = Vector3.ZERO


## Cria o texto em [param world_position] (acima do alvo) dentro de [param parent].
static func spawn(parent: Node, world_position: Vector3, text_value: String, color: Color) -> void:
	var label: FloatingText = FloatingText.new()
	label.text = text_value
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.0065
	label.font_size = 64
	label.outline_size = 16
	label.render_priority = 5
	parent.add_child(label)
	# Leve espalhamento lateral para números seguidos não se sobreporem.
	label._start = world_position + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)
	label.global_position = label._start


func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / LIFETIME
	global_position = _start + Vector3.UP * RISE * t
	modulate.a = 1.0 - t * t
	if _age >= LIFETIME:
		queue_free()
