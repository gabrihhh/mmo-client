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

## Slot → osso do encaixe. Slot fora daqui (peito, pés) ainda não tem modelo.
const MOUNT_BONES: Dictionary[String, String] = {"hand": "RightHand", "head": "Head"}
var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null
## Animador do personagem (para saber se há ação tocando); null = sempre "fora de ação".
var animator: CharacterAnimator = null
## Item de segurar com direção de descanso (null = nenhum), o id dele e a pegada (rotação na mão).
var _held_model: Node3D = null
var _held_id: String = ""
var _held_grip: Basis = Basis.IDENTITY
## Puxão atual (suavizado entre fora de ação e durante a ação).
var _held_pull: float = 0.0
## Rapidez da troca de puxão (unidades de puxão por segundo).
const PULL_BLEND_RATE: float = 20.0


func _ready() -> void:
	process_priority = 100  # depois do AnimationTree, com a pose do quadro já aplicada


func _process(delta: float) -> void:
	if _held_model == null or not is_instance_valid(_held_model):
		return
	var acting: bool = animator != null and animator.is_acting()
	_held_pull = move_toward(_held_pull, ItemModels.hold_pull(_held_id, acting), PULL_BLEND_RATE * delta)
	var body: Node3D = get_parent() as Node3D
	var rest_direction: Vector3 = body.global_basis.orthonormalized() * ItemModels.hold_direction(_held_id)
	var mount: Node3D = _held_model.get_parent() as Node3D
	# Como ficaria preso ao osso (pegada normal) → comprimento puxado para a direção de descanso.
	var rigid: Basis = mount.global_basis * _held_grip
	var size: float = rigid.get_scale().y
	var length_axis: Vector3 = (rigid.y.normalized() + rest_direction * _held_pull).normalized()
	var side: Vector3 = rigid.z.normalized()
	side = side - length_axis * side.dot(length_axis)
	if side.length() < 0.001:
		return
	side = side.normalized()
	_held_model.global_basis = Basis(length_axis.cross(side), length_axis, side).scaled_local(Vector3.ONE * size)


## Cria os encaixes nos ossos de [param skeleton]. Item de segurar: pegada em [param hand_offset] (m, a partir do
## pulso, no osso do placeholder). Item de cabeça: em [param head_offset] (m, a partir do início
## do osso da cabeça) com escala [param head_scale] (cada modelo tem um tamanho de cabeça). [param show_head] false =
## sem encaixe de cabeça (o item não aparece).
func setup(skeleton: Skeleton3D, hand_offset: Vector3, head_offset: Vector3, head_scale: float, show_head: bool = true) -> void:
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
	_refresh()


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
		mount.add_child(model)
