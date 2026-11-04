class_name EquipmentView
extends Node
## Mostra no boneco os itens vestidos ([ART-02], [ART-03]): segue o [member PlayerState.look] e troca os modelos.
##
## Cada slot com modelo tem um encaixe ([BoneAttachment3D]) num osso do esqueleto: arma na mão direita
## ("RightHand"), chapéu/capuz na cabeça ("Head"). Os encaixes acompanham as animações.
## Modelos e o jeito de segurar cada item: [ItemModels]. Pegada e offsets são medidos no osso do placeholder;
## [method SkeletonRetarget.mount_fix] converte para o osso de outro modelo (eixos diferentes).
##
## Arma na mão (as animações do Meshy são de mão vazia, então a arma é posta "à moda dos jogos"):
## - **parado/correndo**: a arma fica numa posição de carregar à frente do corpo ([method ItemModels.carry]) e as
##   mãos vão até ela por IK ([TwoBoneIK3D]): a direita no cabo; a esquerda também, se for de duas mãos;
## - **durante uma ação** (ataque, magia): a arma volta a seguir a mão animada, com o comprimento puxado para a
##   direção de descanso ou para o antebraço ([method ItemModels.hold_direction]); ao terminar, volta suave para a
##   posição de carregar.
## A arma também escolhe a postura parada do personagem ([method CharacterAnimator.set_idle_animation]).

## Slot → osso do encaixe. Slot fora daqui (peito, pés) ainda não tem modelo.
const MOUNT_BONES: Dictionary[String, String] = {"hand": "RightHand", "head": "Head"}
## Para onde cada cotovelo aponta no IK (espaço do personagem, m): para fora e para baixo. Lado direito = −X.
const POLES: Dictionary[String, Vector3] = {"Left": Vector3(0.8, 0.6, -0.2), "Right": Vector3(-0.8, 0.6, -0.2)}
## Pulso em relação ao ponto de pegada (espaço do personagem, m): a pegada fica na palma, o pulso um pouco atrás.
const WRIST_FROM_GRIP: Vector3 = Vector3(0.0, 0.0, -0.06)
## Rapidez com que a direção de puxão alcança a nova (1/s).
const DIRECTION_BLEND_RATE: float = 18.0
## Rapidez da troca de puxão (unidades de puxão por segundo).
const PULL_BLEND_RATE: float = 20.0
## Rapidez da entrada/saída da posição de carregar (fração por segundo): sai rápido ao atacar, volta mais devagar.
const CARRY_OUT_RATE: float = 10.0
const CARRY_IN_RATE: float = 4.0

## Animador do personagem (ação tocando? postura parada da arma); null = sem isso.
var animator: CharacterAnimator = null

var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null
## Esqueleto do personagem (direção do antebraço durante a ação).
var _skeleton: Skeleton3D = null
## IK de cada braço ("Left"/"Right") e o alvo do pulso.
var _arm_ik: Dictionary[String, TwoBoneIK3D] = {}
var _arm_target: Dictionary[String, Node3D] = {}
## Item de segurar com direção de descanso (null = nenhum), o id dele e a pegada (rotação na mão).
var _held_model: Node3D = null
var _held_id: String = ""
var _held_grip: Basis = Basis.IDENTITY
## Puxão atual (suavizado entre fora de ação e durante a ação).
var _held_pull: float = 0.0
## Direção de puxão atual (global, suavizada: não pula ao começar/terminar a ação). Zero = ainda não definida.
var _held_direction: Vector3 = Vector3.ZERO
## Quanto a arma está na posição de carregar (0 = segue a mão animada, 1 = carregada à frente com IK).
var _carry_weight: float = 0.0


func _ready() -> void:
	process_priority = 100  # depois do AnimationTree, com a pose do quadro já aplicada


func _process(delta: float) -> void:
	if _held_model == null or not is_instance_valid(_held_model):
		_set_arm_weight("Right", 0.0)
		_set_arm_weight("Left", 0.0)
		return
	var body: Node3D = get_parent() as Node3D
	var body_basis: Basis = body.global_basis.orthonormalized()
	var acting: bool = animator != null and animator.is_acting()

	# 1) Arma seguindo a mão animada (comprimento puxado para a direção de descanso ou para o antebraço).
	_held_pull = move_toward(_held_pull, ItemModels.hold_pull(_held_id, acting), PULL_BLEND_RATE * delta)
	var want_direction: Vector3 = body_basis * ItemModels.hold_direction(_held_id)
	if acting and ItemModels.follows_forearm_in_action(_held_id):
		var forearm: Vector3 = _bone_position("RightHand") - _bone_position("RightLowerArm")
		if forearm.length() > 0.001:
			want_direction = forearm.normalized()
	_held_direction = want_direction if _held_direction == Vector3.ZERO \
		else _held_direction.slerp(want_direction, minf(1.0, DIRECTION_BLEND_RATE * delta)).normalized()
	var mount: Node3D = _held_model.get_parent() as Node3D
	var rigid: Basis = mount.global_basis * _held_grip
	var size: float = rigid.get_scale().y
	var follow_basis: Basis = _basis_along((rigid.y.normalized() + _held_direction * _held_pull).normalized(), rigid.z)
	var follow_origin: Vector3 = mount.global_position

	# 2) Posição de carregar à frente do corpo (parado/correndo), misturada pelo peso.
	var carry: Transform3D = ItemModels.carry(_held_id)
	var has_carry: bool = carry != Transform3D()
	var target_weight: float = 1.0 if has_carry and not acting else 0.0
	_carry_weight = move_toward(_carry_weight, target_weight, (CARRY_IN_RATE if target_weight > _carry_weight else CARRY_OUT_RATE) * delta)
	var final_basis: Basis = follow_basis
	var final_origin: Vector3 = follow_origin
	if has_carry and _carry_weight > 0.0:
		var carry_origin: Vector3 = body.global_transform * carry.origin
		var carry_basis: Basis = _basis_along((body_basis * carry.basis.y).normalized(), body_basis.x)
		final_basis = Basis(follow_basis.get_rotation_quaternion().slerp(carry_basis.get_rotation_quaternion(), _carry_weight))
		final_origin = follow_origin.lerp(carry_origin, _carry_weight)
	_held_model.global_transform = Transform3D(final_basis.scaled_local(Vector3.ONE * size), final_origin)

	# 3) Mãos: a direita vai ao cabo só carregando (na ação quem manda é a animação); a esquerda, sempre que a arma
	#    for de duas mãos.
	_place_arm("Right", final_origin + body_basis * WRIST_FROM_GRIP, _carry_weight)
	if ItemModels.is_two_handed(_held_id):
		var off_grip: Vector3 = _held_model.global_transform * ItemModels.off_hand_grip(_held_id)
		_place_arm("Left", off_grip + body_basis * WRIST_FROM_GRIP, 1.0)
	else:
		_set_arm_weight("Left", 0.0)


## Cria os encaixes nos ossos de [param skeleton]. Item de segurar: pegada em [param hand_offset] (m, a partir do
## pulso, no osso do placeholder). Item de cabeça: em [param head_offset] (m, a partir do início
## do osso da cabeça) com escala [param head_scale] (cada modelo tem um tamanho de cabeça). [param show_head] false =
## sem encaixe de cabeça (o item não aparece).
func setup(skeleton: Skeleton3D, hand_offset: Vector3, head_offset: Vector3, head_scale: float, show_head: bool = true) -> void:
	_skeleton = skeleton
	for slot: String in MOUNT_BONES:
		if slot == "head" and not show_head:
			continue
		var bone_name: String = MOUNT_BONES[slot]
		if skeleton.find_bone(bone_name) < 0:
			continue
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = bone_name + "Mount"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		var mount: Node3D = Node3D.new()
		var fix: Transform3D = SkeletonRetarget.mount_fix(skeleton, bone_name)
		if slot == "head":
			mount.transform = fix * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * head_scale), head_offset)
		else:
			mount.transform = fix * Transform3D(Basis.IDENTITY, hand_offset)
		attachment.add_child(mount)
		_mounts[slot] = mount
	for side: String in POLES:
		_setup_arm_ik(skeleton, side)
	_refresh()


## Cria o IK de um braço ([param side] = "Left"/"Right"), desligado. O alvo e o polo entram na cena depois
## (call_deferred); os caminhos são ligados em [method _place_arm].
func _setup_arm_ik(skeleton: Skeleton3D, side: String) -> void:
	for bone: String in ["UpperArm", "LowerArm", "Hand"]:
		if skeleton.find_bone(side + bone) < 0:
			return
	var body: Node3D = get_parent() as Node3D
	var pole: Node3D = Node3D.new()
	pole.name = side + "ArmPole"
	pole.position = POLES[side]
	body.add_child.call_deferred(pole)
	var target: Node3D = Node3D.new()
	target.name = side + "WristTarget"
	body.add_child.call_deferred(target)
	var ik: TwoBoneIK3D = TwoBoneIK3D.new()
	ik.name = side + "ArmIK"
	ik.set_setting_count(1)
	ik.set_root_bone_name(0, side + "UpperArm")
	ik.set_middle_bone_name(0, side + "LowerArm")
	ik.set_end_bone_name(0, side + "Hand")
	ik.active = false
	ik.set_meta(&"pole", pole)
	skeleton.add_child(ik)
	_arm_ik[side] = ik
	_arm_target[side] = target


## Leva o pulso do braço [param side] até [param wrist] (global) com peso [param weight] (0 = só a animação).
func _place_arm(side: String, wrist: Vector3, weight: float) -> void:
	if not _arm_ik.has(side):
		return
	var target: Node3D = _arm_target[side]
	if not target.is_inside_tree():
		return
	var ik: TwoBoneIK3D = _arm_ik[side]
	if ik.get_target_node(0).is_empty():
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(ik.get_meta(&"pole") as Node3D))
	target.global_position = wrist
	_set_arm_weight(side, weight)


## Peso do IK do braço [param side] (0 desliga).
func _set_arm_weight(side: String, weight: float) -> void:
	if not _arm_ik.has(side):
		return
	var ik: TwoBoneIK3D = _arm_ik[side]
	ik.influence = clampf(weight, 0.0, 1.0)
	ik.active = weight > 0.001


## Passa a seguir a aparência de [param state] (troca na hora e a cada [signal PlayerState.look_changed]).
func bind(state: PlayerState) -> void:
	if _state != null and _state.look_changed.is_connected(_refresh):
		_state.look_changed.disconnect(_refresh)
	_state = state
	if _state != null:
		_state.look_changed.connect(_refresh)
	_refresh()


## Recria os modelos de todos os slots a partir do look atual.
func _refresh() -> void:
	_held_model = null
	var hand_item: String = _state.look.get("hand", "") if _state != null else ""
	if animator != null:
		animator.set_idle_animation(ItemModels.idle_animation(hand_item))
	for slot: String in _mounts:
		var mount: Node3D = _mounts[slot]
		for child: Node in mount.get_children():
			child.queue_free()
		var item_id: String = _state.look.get(slot, "") if _state != null else ""
		if item_id.is_empty():
			continue
		var model: Node3D = ItemModels.instantiate(item_id)
		if model == null:
			continue
		if slot == "hand":
			model.basis = ItemModels.grip(item_id)
			if ItemModels.hold_direction(item_id) != Vector3.ZERO:
				_held_model = model
				_held_id = item_id
				_held_grip = model.basis
				_held_pull = ItemModels.hold_pull(item_id, false)
				_held_direction = Vector3.ZERO
				_carry_weight = 1.0
		mount.add_child(model)


## Base com o eixo Y em [param length_axis] e o Z o mais perto possível de [param side_hint].
func _basis_along(length_axis: Vector3, side_hint: Vector3) -> Basis:
	var side: Vector3 = side_hint.normalized() - length_axis * side_hint.normalized().dot(length_axis)
	if side.length() < 0.001:
		side = length_axis.cross(Vector3.RIGHT if absf(length_axis.x) < 0.9 else Vector3.FORWARD)
	side = side.normalized()
	return Basis(length_axis.cross(side), length_axis, side)


## Posição global do osso [param bone_name] na pose atual.
func _bone_position(bone_name: String) -> Vector3:
	var bone: int = _skeleton.find_bone(bone_name)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin if bone >= 0 else _skeleton.global_position
