extends SceneTree
## Exporta um item do jogo como ele fica VESTIDO no corpo em repouso, para servir de base no Blender ([ART-09]).
## Monta o personagem, veste o item, deixa o esqueleto em repouso e grava as malhas do item no espaço do personagem
## (origem nos pés, metros, Y para cima): importado no Blender, cai exatamente onde fica no jogo.
## Pés: sai só o pé esquerdo, na posição do encaixe pelo osso (o jogo ainda reencaixa pela sola do pé, [ART-04]).
##
## Chamado por tools/blender/item_to_blender.py (rodar aquele). Direto, da pasta mmo-client:
##   godot --path . --headless --script res://tools/blender/item_to_glb.gd -- <item_id> <male|female> <saida.glb>

## Pasta do slot em assets/itens → slot do look.
const LOOK_SLOT: Dictionary[String, String] = {"head": "head", "chest": "chest", "boot": "feet", "hand": "hand"}
## Encaixes de cada slot do look (um só por slot: a mão esquerda e o pé direito são cópias espelhadas).
const MOUNT_KEYS: Dictionary[String, String] = {"head": "head", "chest": "chest", "feet": "foot_left", "hand": "hand"}

var _frames: int = 0
var _model: CharacterModel = null
var _item_id: String = ""
var _output: String = ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		return not _build()
	_rest()
	if _frames < 4:
		return false
	_export()
	return true


func _build() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("uso: -- <item_id> <male|female> <saida.glb>")
		return false
	_item_id = args[0]
	_output = args[2]
	var folder: String = ItemModels.folder(_item_id)
	if folder.is_empty():
		push_error("item desconhecido: %s" % _item_id)
		return false
	var slot: String = LOOK_SLOT.get(folder.get_base_dir().get_file(), "")
	_model = (load("res://assets/characters/%s/%s_character.tscn" % [args[1], args[1]]) as PackedScene).instantiate() as CharacterModel
	get_root().add_child(_model)
	(_model.get_node("Animator") as AnimationTree).active = false
	var look: PlayerState = PlayerState.new()
	look.set_look({slot: _item_id})
	_model.bind_look(look)
	_model.set_meta(&"slot", slot)
	return true


## Esqueleto em repouso (sem animação): igual ao corpo do .blend.
func _rest() -> void:
	for skeleton: Node in _model.find_children("*", "Skeleton3D", true, false):
		(skeleton as Skeleton3D).reset_bone_poses()


func _export() -> void:
	var slot: String = _model.get_meta(&"slot")
	var bone: String = EquipmentView.MOUNTS[MOUNT_KEYS[slot]][1]
	var attachment: Node = _model.find_child(bone + "Mount", true, false)
	if attachment == null:
		push_error("encaixe %sMount não encontrado" % bone)
		quit(1)
		return
	var to_character: Transform3D = _model.global_transform.affine_inverse()
	var root: Node3D = Node3D.new()
	root.name = _item_id
	var count: int = 0
	for node: Node in attachment.find_children("*", "MeshInstance3D", true, false):
		var source: MeshInstance3D = node as MeshInstance3D
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.name = source.name
		copy.mesh = source.mesh
		copy.transform = to_character * source.global_transform
		for surface: int in range(source.mesh.get_surface_count()):
			copy.set_surface_override_material(surface, source.get_active_material(surface))
		root.add_child(copy)
		count += 1
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, _output)
	print("ITEM %s: %d malha(s) → %s (erro %d)" % [_item_id, count, _output, error])
	root.free()
