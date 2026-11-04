class_name EquipmentView
extends Node
## Mostra no boneco os itens vestidos ([ART-02], [ART-03]): segue o [member PlayerState.look] e troca os modelos.
##
## Cada slot com modelo tem um encaixe ([BoneAttachment3D]) num osso do esqueleto: arma na mão direita
## ("RightHand"), chapéu/capuz na cabeça ("Head"). Os encaixes acompanham as animações.
## Modelos e o jeito de segurar cada item: [ItemModels]. Pegada e offsets são medidos no osso do placeholder;
## [method SkeletonRetarget.mount_fix] converte para o osso de outro modelo (eixos diferentes).
## Item de segurar com direção de descanso ([method ItemModels.hold_direction]): a cada quadro, depois da animação, o
## comprimento é puxado para ela (espada para a frente, cajado em pé), menos durante uma ação ([member animator]).
## Arma de duas mãos ([method ItemModels.is_two_handed]): a mão esquerda vai ao cabo por IK ([TwoBoneIK3D]).
## A arma também escolhe a postura parada do personagem ([method CharacterAnimator.set_idle_animation]).

## Slot → osso do encaixe. Slot fora daqui (peito, pés) ainda não tem modelo.
const MOUNT_BONES: Dictionary[String, String] = {"hand": "RightHand", "head": "Head"}
var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null
## Animador do personagem (ação tocando? postura parada da arma); null = sem isso.
var animator: CharacterAnimator = null
## IK do braço esquerdo (mão no cabo da arma de duas mãos) e o alvo dele.
var _off_hand_ik: TwoBoneIK3D = null
var _off_hand_target: Node3D = null
## A arma atual pede a mão esquerda no cabo (o IK liga assim que o alvo estiver na cena).
var _want_off_hand: bool = false
## Para onde o cotovelo esquerdo aponta no IK (espaço do personagem, m): para fora e para baixo.
const OFF_HAND_POLE: Vector3 = Vector3(0.8, 0.6, -0.2)
## Item de segurar com direção de descanso (null = nenhum), o id dele e a pegada (rotação na mão).
var _held_model: Node3D = null
## Esqueleto do personagem (direção do antebraço durante a ação).
var _skeleton: Skeleton3D = null
var _held_id: String = ""
var _held_grip: Basis = Basis.IDENTITY
## Puxão atual (suavizado entre fora de ação e durante a ação).
var _held_pull: float = 0.0
## Direção de puxão atual (global, suavizada: não pula ao começar/terminar a ação). Zero = ainda não definida.
var _held_direction: Vector3 = Vector3.ZERO
## Rapidez com que a direção de puxão alcança a nova (1/s).
const DIRECTION_BLEND_RATE: float = 18.0
## Rapidez da troca de puxão (unidades de puxão por segundo).
const PULL_BLEND_RATE: float = 20.0


func _ready() -> void:
	process_priority = 100  # depois do AnimationTree, com a pose do quadro já aplicada


func _process(delta: float) -> void:
	if _off_hand_ik != null and _want_off_hand != _off_hand_ik.active:
		_set_off_hand(_want_off_hand)
	if _held_model == null or not is_instance_valid(_held_model):
		return
	var acting: bool = animator != null and animator.is_acting()
	_held_pull = move_toward(_held_pull, ItemModels.hold_pull(_held_id, acting), PULL_BLEND_RATE * delta)
	var body: Node3D = get_parent() as Node3D
	var rest_direction: Vector3 = body.global_basis.orthonormalized() * ItemModels.hold_direction(_held_id)
	if acting and ItemModels.follows_forearm_in_action(_held_id):
		var forearm: Vector3 = _bone_position("RightHand") - _bone_position("RightLowerArm")
		if forearm.length() > 0.001:
			rest_direction = forearm.normalized()
	_held_direction = rest_direction if _held_direction == Vector3.ZERO \
		else _held_direction.slerp(rest_direction, minf(1.0, DIRECTION_BLEND_RATE * delta)).normalized()
	var mount: Node3D = _held_model.get_parent() as Node3D
	# Como ficaria preso ao osso (pegada normal) → comprimento puxado para a direção de descanso.
	var rigid: Basis = mount.global_basis * _held_grip
	var size: float = rigid.get_scale().y
	var length_axis: Vector3 = (rigid.y.normalized() + _held_direction * _held_pull).normalized()
	var side: Vector3 = rigid.z.normalized()
	side = side - length_axis * side.dot(length_axis)
	if side.length() < 0.001:
		return
	side = side.normalized()
	_held_model.global_basis = Basis(length_axis.cross(side), length_axis, side).scaled_local(Vector3.ONE * size)
	if _off_hand_ik != null and _off_hand_ik.active:
		_off_hand_target.global_transform = _held_model.global_transform * Transform3D(Basis.IDENTITY, ItemModels.off_hand_grip(_held_id))


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
	_setup_off_hand_ik(skeleton)
	_refresh()


## Cria o IK do braço esquerdo (desligado até haver arma de duas mãos).
func _setup_off_hand_ik(skeleton: Skeleton3D) -> void:
	if skeleton.find_bone("LeftUpperArm") < 0 or skeleton.find_bone("LeftLowerArm") < 0 or skeleton.find_bone("LeftHand") < 0:
		return
	var body: Node3D = get_parent() as Node3D
	var pole: Node3D = Node3D.new()
	pole.name = "OffHandPole"
	pole.position = OFF_HAND_POLE
	body.add_child.call_deferred(pole)
	_off_hand_target = Node3D.new()
	_off_hand_target.name = "OffHandTarget"
	body.add_child.call_deferred(_off_hand_target)
	_off_hand_ik = TwoBoneIK3D.new()
	_off_hand_ik.name = "OffHandIK"
	_off_hand_ik.set_setting_count(1)
	_off_hand_ik.set_root_bone_name(0, "LeftUpperArm")
	_off_hand_ik.set_middle_bone_name(0, "LeftLowerArm")
	_off_hand_ik.set_end_bone_name(0, "LeftHand")
	_off_hand_ik.active = false
	skeleton.add_child(_off_hand_ik)
	_off_hand_ik.set_target_node(0, _off_hand_ik.get_path_to(_off_hand_target) if _off_hand_target.is_inside_tree() else NodePath())
	_off_hand_ik.set_meta(&"pole", pole)


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
	_set_off_hand(ItemModels.is_two_handed(hand_item))
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
		mount.add_child(model)


## Liga/desliga a mão esquerda no cabo (IK). Os caminhos do alvo e do polo são ligados aqui porque os nós entram na
## cena depois do [method setup].
func _set_off_hand(enabled: bool) -> void:
	_want_off_hand = enabled
	if _off_hand_ik == null:
		return
	if enabled and _off_hand_target.is_inside_tree():
		_off_hand_ik.set_target_node(0, _off_hand_ik.get_path_to(_off_hand_target))
		var pole: Node3D = _off_hand_ik.get_meta(&"pole") as Node3D
		_off_hand_ik.set_pole_node(0, _off_hand_ik.get_path_to(pole))
	_off_hand_ik.active = enabled and _off_hand_target.is_inside_tree()


## Posição global do osso [param bone_name] na pose atual.
func _bone_position(bone_name: String) -> Vector3:
	var bone: int = _skeleton.find_bone(bone_name)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin if bone >= 0 else _skeleton.global_position
