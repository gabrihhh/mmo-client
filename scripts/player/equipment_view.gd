class_name EquipmentView
extends Node
## Mostra no boneco os itens vestidos ([ART-02], [ART-03]): segue o [member PlayerState.look] e troca os modelos.
##
## Cada slot com modelo tem um encaixe ([BoneAttachment3D]) num osso do esqueleto: arma na mão direita
## ("RightHand"), chapéu/capuz na cabeça ("Head"). Os encaixes acompanham as animações.
## Modelos e o jeito de segurar cada item: [ItemModels]. Pegada e offsets são medidos no osso do placeholder;
## [method SkeletonRetarget.mount_fix] converte para o osso de outro modelo (eixos diferentes).

## Slot → osso do encaixe. Slot fora daqui (peito, pés) ainda não tem modelo.
const MOUNT_BONES: Dictionary[String, String] = {"hand": "RightHand", "head": "Head"}
var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null


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
		mount.add_child(model)
