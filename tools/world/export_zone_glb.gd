extends SceneTree
## Exporta o cenário da zona 1 como o jogo monta ([Zone1Scenery], [MUN-04]) para um .glb que o Blender abre
## ([ART-09]): chão com morros e subida da borda, praça com escadas e pilares, árvores, pedras e montanhas. Flores e
## grama (MultiMesh, milhares de instâncias geradas por código) ficam de fora. Origem e escala do jogo (metros);
## no Blender o +Z do jogo vira −Y.
##   godot --headless --path . --script res://tools/world/export_zone_glb.gd -- ../workspace-blender/zone_1_jogo.glb

var _frames: int = 0
var _scenery: Zone1Scenery = null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_scenery = Zone1Scenery.new()
		_scenery.name = "Zone1"
		get_root().add_child(_scenery)
		return false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "../workspace-blender/zone_1_jogo.glb"
	var path: String = ProjectSettings.globalize_path("res://").path_join(out).simplify_path()
	# Só as malhas comuns (sem as MultiMesh de flores e grama).
	var root: Node3D = Node3D.new()
	root.name = "zone_1_jogo"
	var count: int = 0
	for node: Node in _scenery.find_children("*", "MeshInstance3D", true, false):
		var source: MeshInstance3D = node as MeshInstance3D
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		copy.transform = source.global_transform
		var label: String = String(source.get_parent().name) if source.get_parent() != _scenery else ""
		copy.name = (label + "_" if not label.is_empty() else "") + "parte_%d" % count
		root.add_child(copy)
		count += 1
	get_root().add_child(root)
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = gltf.append_from_scene(root, state)
	if error == OK:
		error = gltf.write_to_filesystem(state, path)
	print("ZONA %s: %d malhas → %s" % ["ok" if error == OK else "ERRO %d" % error, count, path])
	return true
