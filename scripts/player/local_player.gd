class_name LocalPlayer
extends CharacterBody3D
## Jogador controlado por este dispositivo. Ver mmo-docs [CLI-04].
##
## Lê o joystick virtual (ou o teclado no desktop), move-se relativo à câmera
## isométrica e envia a posição ao servidor em [constant NetworkConfig.MOVE_SEND_RATE_HZ].

## Velocidade de caminhada, em m/s.
@export var move_speed: float = 5.0
## Quão rápido o personagem gira para a direção do movimento.
@export var turn_speed: float = 12.0

## Joystick de toque; atribuído pela zona ao criar o jogador. Pode ser null.
var joystick: TouchJoystick = null

## Distância mínima (m) para considerar que o jogador se moveu e enviar update.
const _MIN_SEND_DISTANCE: float = 0.01
## Diferença mínima de rotação (rad) para enviar update.
const _MIN_SEND_ANGLE: float = 0.01

@onready var _camera: IsometricCamera = $Camera

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _send_timer: float = 0.0
var _last_sent_position: Vector3 = Vector3.INF
var _last_sent_rot_y: float = INF


func _ready() -> void:
	InputActions.register_defaults()


func _physics_process(delta: float) -> void:
	var input: Vector2 = _read_move_input()
	# Converte o input de tela (relativo à câmera) em direção no mundo.
	var direction: Vector3 = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _camera.get_yaw_radians())

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if direction.length_squared() > 0.0001:
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	move_and_slide()
	_clamp_to_zone()
	_send_network_update(delta)


## Teleporta o jogador (spawn) e cola a câmera nele.
func spawn_at(world_position: Vector3, rot_y: float) -> void:
	global_position = world_position
	rotation.y = rot_y
	_camera.snap_to_target()


func _read_move_input() -> Vector2:
	var touch: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	return (touch + InputActions.get_keyboard_vector()).limit_length(1.0)


## Mantém o jogador dentro da zona (o servidor faz o mesmo; evita divergência).
func _clamp_to_zone() -> void:
	var limit: float = WorldConstants.ZONE_HALF_SIZE
	global_position.x = clampf(global_position.x, -limit, limit)
	global_position.z = clampf(global_position.z, -limit, limit)


func _send_network_update(delta: float) -> void:
	_send_timer += delta
	if _send_timer < 1.0 / NetworkConfig.MOVE_SEND_RATE_HZ:
		return
	_send_timer = 0.0

	var moved: bool = global_position.distance_to(_last_sent_position) > _MIN_SEND_DISTANCE
	var turned: bool = absf(angle_difference(rotation.y, _last_sent_rot_y)) > _MIN_SEND_ANGLE
	if not moved and not turned:
		return

	Network.send_move(global_position, rotation.y)
	_last_sent_position = global_position
	_last_sent_rot_y = rotation.y
