class_name EquipmentView
extends Node
## Mostra no boneco os itens vestidos ([ART-02], [ART-03]): segue o [member PlayerState.look] e troca os modelos.
##
## Cada slot com modelo tem um encaixe ([BoneAttachment3D]) num osso do esqueleto: arma na mão direita
## ("RightHand"), chapéu/capuz na cabeça ("Head"). Os encaixes acompanham as animações.
## Modelos e o jeito de segurar cada item: [ItemModels].

## Slot → osso do encaixe. Slot fora daqui (peito, pés) ainda não tem modelo.
const MOUNT_BONES: Dictionary[String, String] = {"hand": "RightHand", "head": "Head"}
## Ponto de pegada (m) a partir do início do osso da mão (pulso): o meio do punho fechado.
const HAND_OFFSET: Vector3 = Vector3(0.0, -0.06, 0.02)
## Onde assenta um item de cabeça (m) a partir do início do osso da cabeça: no alto do cabelo.
const HEAD_OFFSET: Vector3 = Vector3(0.0, 0.175, 0.0)
## Escala dos itens de cabeça para cobrir o cabelo do placeholder.
const HEAD_SCALE: float = 1.1

var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null


## Cria os encaixes nos ossos de [param skeleton].
func setup(skeleton: Skeleton3D) -> void:
	for slot: String in MOUNT_BONES:
		var bone_name: String = MOUNT_BONES[slot]
		if skeleton.find_bone(bone_name) < 0:
			continue
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = bone_name + "Mount"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		var mount: Node3D = Node3D.new()
		if slot == "head":
			mount.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * HEAD_SCALE), HEAD_OFFSET)
		else:
			mount.position = HAND_OFFSET
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
