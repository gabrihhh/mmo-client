class_name HandGrip
extends SkeletonModifier3D
## Mãos que seguram de verdade ([ART-07]):
## - fecha os dedos (ossos `<Lado>Fingers`/`<Lado>Thumb` criados na importação, tools/characters/finger_bones_import.gd)
##   em direção à palma;
## - gira a mão para o cabo passar pelo **punho** ([method set_hand_rotation]): o [EquipmentView] calcula a rotação
##   com [method fist_frame] e a posição do pulso; este modificador roda depois do IK do braço e aplica a rotação.
##
## Os ossos de dedo nascem com o eixo X como eixo de dobra (girar +X fecha). Nenhuma animação mexe neles (o rig não
## tem dedos), então este modificador escreve a pose a cada quadro. Corpo sem os ossos de dedo = nada acontece.

## Quanto os 4 dedos dobram com a mão fechada (rad): passam do ângulo reto, pontas voltadas para a palma.
const FINGERS_CURL_RAD: float = deg_to_rad(100.0)
## Quanto o polegar dobra (rad): menos, ele fica por fora do cabo.
const THUMB_CURL_RAD: float = deg_to_rad(55.0)
## Rapidez de abrir/fechar (fração por segundo).
const BLEND_RATE: float = 8.0
## Centro do buraco do punho fechado: a partir da linha dos nós dos dedos, quanto (m) para o lado da palma e quanto
## para trás (para o pulso). Medido no corpo masculino: os dedos dobrados a 100° fecham a ~3 cm da palma.
const FIST_PALM_M: float = 0.03
const FIST_BACK_M: float = 0.012

## Quanto cada mão está fechada agora (0 = aberta, 1 = fechada) e o alvo.
var _closed: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
var _target: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
## Rotação global desejada de cada mão e o peso (0 = a da animação/IK).
var _aim: Dictionary[String, Basis] = {}
var _aim_weight: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
## Arma na mão direita: depois de girar a mão, ela é posta no centro do punho (fica sempre "dentro" da mão, mesmo
## na troca entre carregar e seguir a animação). null = nenhuma.
var _held: Node3D = null


## true se o esqueleto tem os ossos de dedo (corpo importado com finger_bones_import.gd).
static func supports(skeleton: Skeleton3D) -> bool:
	return skeleton.find_bone("RightFingers") >= 0


## Fecha (true) ou abre a mão direita e a esquerda. A troca é suave ([constant BLEND_RATE]).
func set_grip(right: bool, left: bool) -> void:
	_target["Right"] = 1.0 if right else 0.0
	_target["Left"] = 1.0 if left else 0.0


## Gira a mão [param side] para a rotação global [param global_basis] (peso [param weight]; 0 = solta).
func set_hand_rotation(side: String, global_basis: Basis, weight: float) -> void:
	_aim[side] = global_basis.orthonormalized()
	_aim_weight[side] = clampf(weight, 0.0, 1.0)


## Arma que a mão direita segura ([param node]; null solta): a posição dela passa a ser o centro do punho, a cada
## quadro, depois do IK e da rotação da mão. A rotação da arma continua a que o [EquipmentView] deu.
func set_held(node: Node3D) -> void:
	_held = node


## Referencial do punho fechado da mão [param side], no espaço do osso da mão: origem = centro do buraco do punho;
## X = eixo do buraco, apontando para o lado do polegar (por onde sai a lâmina); Y = dos nós para a ponta dos dedos
## (mão aberta); Z = para a palma. Identidade se o corpo não tem os ossos de dedo.
func fist_frame(side: String) -> Transform3D:
	var skeleton: Skeleton3D = get_skeleton()
	var fingers: int = skeleton.find_bone(side + "Fingers") if skeleton != null else -1
	if fingers < 0:
		return Transform3D.IDENTITY
	var rest: Transform3D = skeleton.get_bone_rest(fingers)
	var bend: Vector3 = rest.basis.x.normalized()
	var along: Vector3 = rest.basis.y.normalized()
	var palm: Vector3 = rest.basis.z.normalized()
	var thumb: int = skeleton.find_bone(side + "Thumb")
	if thumb >= 0 and (skeleton.get_bone_rest(thumb).origin - rest.origin).dot(bend) < 0.0:
		bend = -bend
	palm = bend.cross(along).normalized()
	var center: Vector3 = rest.origin + palm * FIST_PALM_M - along * FIST_BACK_M
	return Transform3D(Basis(bend, along, palm), center)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for side: String in _closed:
		if _aim_weight[side] > 0.0 and _aim.has(side):
			_rotate_hand(skeleton, side)
		_closed[side] = move_toward(_closed[side], _target[side], BLEND_RATE * delta)
		_bend(skeleton, side + "Fingers", FINGERS_CURL_RAD * _closed[side])
		_bend(skeleton, side + "Thumb", THUMB_CURL_RAD * _closed[side])
	if _held != null and is_instance_valid(_held) and _aim_weight["Right"] > 0.0:
		var hand: int = skeleton.find_bone("RightHand")
		if hand >= 0:
			_held.global_position = skeleton.global_transform * (skeleton.get_bone_global_pose(hand) * fist_frame("Right").origin)


## Leva a mão [param side] para a rotação global pedida (mantém a posição que a animação/IK deu ao pulso).
func _rotate_hand(skeleton: Skeleton3D, side: String) -> void:
	var bone: int = skeleton.find_bone(side + "Hand")
	if bone < 0:
		return
	var parent: int = skeleton.get_bone_parent(bone)
	var current: Transform3D = skeleton.get_bone_global_pose(bone)
	var wanted: Basis = (skeleton.global_basis.orthonormalized().inverse() * _aim[side]).orthonormalized()
	var blended: Quaternion = current.basis.get_rotation_quaternion().slerp(wanted.get_rotation_quaternion(), _aim_weight[side])
	var parent_rotation: Quaternion = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, parent_rotation.inverse() * blended)


## Pose do osso [param bone_name] = repouso girado [param angle] rad no eixo X dele.
func _bend(skeleton: Skeleton3D, bone_name: String, angle: float) -> void:
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, angle))
