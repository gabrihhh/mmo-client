class_name EquipmentView
extends Node3D
## Mostra no boneco os itens vestidos ([ART-02]): segue o [member PlayerState.look] e troca os modelos.
##
## Fica dentro do "Body" (centro da cápsula, 0,9 m acima dos pés): morto, o corpo some e os itens junto.
## Cada slot tem um ponto de encaixe. Enquanto o corpo é uma cápsula, os pontos são fixos aqui; com o boneco
## de verdade, "hand" vira um BoneAttachment3D no osso da mão (hand.R) e "head" no da cabeça.
##
## Os modelos têm a frente em +Z ([ART-02]) e o personagem olha para −Z: todo encaixe gira 180° em Y.

## Inclinação da arma para a frente (rad): a ponta vai um pouco à frente do corpo.
const WEAPON_TILT: float = deg_to_rad(-20.0)
## Escala dos itens de cabeça: o boné tem o tamanho de uma cabeça de verdade e a cápsula é bem mais larga.
## Volta a 1 quando o boneco de verdade entrar.
const HEAD_SCALE: float = 2.0

## Ponto de encaixe de cada slot (relativo ao centro da cápsula). Slot sem encaixe não mostra nada (por ora).
var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null


func _ready() -> void:
	var turn: Basis = Basis(Vector3.UP, PI)
	# Mão direita: lado +X (o personagem olha para −Z), na altura da cintura, um pouco à frente.
	_add_mount("hand", Transform3D(Basis(Vector3.RIGHT, WEAPON_TILT) * turn, Vector3(0.48, -0.05, -0.12)))
	# Cabeça: no topo da cápsula (a base do boné afunda um pouco na curva).
	_add_mount("head", Transform3D(turn.scaled(Vector3.ONE * HEAD_SCALE), Vector3(0.0, 0.83, 0.0)))
	if _state != null:
		_refresh()


## Passa a seguir a aparência de [param state] (troca na hora e a cada [signal PlayerState.look_changed]).
func bind(state: PlayerState) -> void:
	if _state != null and _state.look_changed.is_connected(_refresh):
		_state.look_changed.disconnect(_refresh)
	_state = state
	if _state == null:
		return
	_state.look_changed.connect(_refresh)
	if is_node_ready():
		_refresh()


func _add_mount(slot: String, mount_transform: Transform3D) -> void:
	var mount: Node3D = Node3D.new()
	mount.name = slot.capitalize() + "Mount"
	mount.transform = mount_transform
	add_child(mount)
	_mounts[slot] = mount


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
		if model != null:
			mount.add_child(model)
