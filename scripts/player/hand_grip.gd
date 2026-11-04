class_name HandGrip
extends SkeletonModifier3D
## Fecha as mãos do personagem quando ele segura algo ([ART-07]): dobra os ossos de dedo criados na importação
## (`<Lado>Fingers` e `<Lado>Thumb`, tools/characters/finger_bones_import.gd) em direção à palma.
##
## Os ossos de dedo nascem com o eixo X como eixo de dobra (girar +X fecha). Nenhuma animação mexe neles (o rig não
## tem dedos), então este modificador escreve a pose a cada quadro, depois da animação. Quem diz quais mãos fecham é
## o [EquipmentView] ([method set_grip]); corpo sem os ossos de dedo = nada acontece.

## Quanto os 4 dedos dobram com a mão fechada (rad): passam do ângulo reto, pontas voltadas para a palma.
const FINGERS_CURL_RAD: float = deg_to_rad(100.0)
## Quanto o polegar dobra (rad): menos, ele fica por fora do cabo.
const THUMB_CURL_RAD: float = deg_to_rad(55.0)
## Rapidez de abrir/fechar (fração por segundo).
const BLEND_RATE: float = 8.0

## Quanto cada mão está fechada agora (0 = aberta, 1 = fechada) e o alvo.
var _closed: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
var _target: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}


## true se o esqueleto tem os ossos de dedo (corpo importado com finger_bones_import.gd).
static func supports(skeleton: Skeleton3D) -> bool:
	return skeleton.find_bone("RightFingers") >= 0


## Fecha (true) ou abre a mão direita e a esquerda. A troca é suave ([constant BLEND_RATE]).
func set_grip(right: bool, left: bool) -> void:
	_target["Right"] = 1.0 if right else 0.0
	_target["Left"] = 1.0 if left else 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for side: String in _closed:
		_closed[side] = move_toward(_closed[side], _target[side], BLEND_RATE * delta)
		_bend(skeleton, side + "Fingers", FINGERS_CURL_RAD * _closed[side])
		_bend(skeleton, side + "Thumb", THUMB_CURL_RAD * _closed[side])


## Pose do osso [param bone_name] = repouso girado [param angle] rad no eixo X dele.
func _bend(skeleton: Skeleton3D, bone_name: String, angle: float) -> void:
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, angle))
