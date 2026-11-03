class_name ProjectileVisual
extends Node3D
## Projétil na tela ([JOGO-08]): bola brilhante low poly com um rastro curto. Só visual — quem acerta é o servidor.
##
## Dois jeitos:
## - [method spawn_linear]: projétil de verdade do servidor (evento "projectile"): anda em linha reta na mesma
##   velocidade que lá; some no "projectile_end" ([method finish]) ou ao chegar no alcance.
## - [method spawn_homing]: efeito das habilidades de alvo: voa até o alvo em [param seconds] e some.

## Raio da bola (m).
const RADIUS: float = 0.16
## Quantas bolinhas no rastro e o espaço (s de voo) entre elas.
const TRAIL_COUNT: int = 3
const TRAIL_SPACING: float = 0.03

## Materiais por cor (iguais para todos os projéteis da mesma cor: menos trocas de estado na GPU).
static var _materials: Dictionary[Color, StandardMaterial3D] = {}
static var _mesh: SphereMesh = null

var _velocity: Vector3 = Vector3.ZERO
var _distance_left: float = 0.0
var _target: Node3D = null
var _target_height: float = 1.2
var _from: Vector3 = Vector3.ZERO
var _flight: float = 0.0
var _age: float = 0.0
var _trail: Array[Node3D] = []
var _history: Array[Vector3] = []


## Projétil em linha reta de [param from] na direção [param direction] (unitária, no plano XZ), [param speed] m/s,
## até [param distance] m.
static func spawn_linear(parent: Node, from: Vector3, direction: Vector3, speed: float, distance: float, color: Color) -> ProjectileVisual:
	var projectile: ProjectileVisual = _create(color)
	projectile._velocity = direction * speed
	projectile._distance_left = distance
	parent.add_child(projectile)
	projectile.global_position = from
	for piece: Node3D in projectile._trail:
		piece.global_position = from  # o rastro nasce junto da bola (não na origem do mundo)
	return projectile


## Projétil que sai de [param from] e chega em [param target] (à altura do peito) em [param seconds].
static func spawn_homing(parent: Node, from: Vector3, target: Node3D, seconds: float, color: Color) -> ProjectileVisual:
	var projectile: ProjectileVisual = _create(color)
	projectile._target = target
	projectile._from = from
	projectile._flight = maxf(seconds, 0.05)
	parent.add_child(projectile)
	projectile.global_position = from
	for piece: Node3D in projectile._trail:
		piece.global_position = from  # o rastro nasce junto da bola (não na origem do mundo)
	return projectile


## Acabou (acertou ou chegou ao fim) em [param at].
func finish(at: Vector3) -> void:
	global_position = Vector3(at.x, global_position.y, at.z)
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	if _target != null:
		if not is_instance_valid(_target):
			queue_free()
			return
		var to: Vector3 = _target.global_position + Vector3.UP * _target_height
		var t: float = clampf(_age / _flight, 0.0, 1.0)
		# Arco leve para cima no meio do caminho.
		global_position = _from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.4
		if t >= 1.0:
			queue_free()
	else:
		var step: Vector3 = _velocity * delta
		global_position += step
		_distance_left -= step.length()
		if _distance_left <= 0.0:
			queue_free()
	_update_trail()


func _update_trail() -> void:
	_history.push_front(global_position)
	var keep: int = TRAIL_COUNT * 3 + 1
	if _history.size() > keep:
		_history.resize(keep)
	for i: int in range(_trail.size()):
		var index: int = mini((i + 1) * 3, _history.size() - 1)
		_trail[i].global_position = _history[index]


static func _create(color: Color) -> ProjectileVisual:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = RADIUS
		_mesh.height = RADIUS * 2.0
		_mesh.radial_segments = 8
		_mesh.rings = 4
	if not _materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color.lightened(0.35)
		_materials[color] = material
	var projectile: ProjectileVisual = ProjectileVisual.new()
	var core: MeshInstance3D = MeshInstance3D.new()
	core.mesh = _mesh
	core.material_override = _materials[color]
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	projectile.add_child(core)
	for i: int in range(TRAIL_COUNT):
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.mesh = _mesh
		piece.material_override = _materials[color]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var size: float = 0.75 - 0.2 * float(i)
		piece.scale = Vector3.ONE * size
		piece.top_level = true  # o rastro fica para trás no mundo, não segue a bola
		projectile.add_child(piece)
		projectile._trail.append(piece)
	return projectile
