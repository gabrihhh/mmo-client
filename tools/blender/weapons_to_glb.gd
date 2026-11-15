extends SceneTree
## Exporta a cena de cada arma (como o jogo monta, com escala e giro da cena do item) para .glb, uma por arquivo:
## usada pela vitrine do testes.blend ([ART-09], tools/blender/build_vitrine.py).
## Uso: godot --path . --headless --script res://tools/blender/weapons_to_glb.gd -- <pasta de saída> <item_id>...
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	for id: String in args.slice(1):
		var model: Node3D = ItemModels.instantiate(id, "male")
		var root: Node3D = Node3D.new()
		root.name = id
		root.add_child(model)
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var err: int = doc.append_from_scene(root, state)
		if err == OK:
			err = doc.write_to_filesystem(state, "%s/%s.glb" % [out_dir, id])
		print("ARMA ", id, " ", err)
		root.free()
	quit()
