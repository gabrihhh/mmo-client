extends SceneTree
## Imprime o AABB (m) de cada .glb passado na linha de comando.

func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			print("%s: não carregou" % path)
			continue
		var root: Node3D = scene.instantiate() as Node3D
		var box: AABB = _bounds(root, Transform3D.IDENTITY)
		var tris: int = _tris(root)
		print("%s pos=%s size=%s tris=%d" % [path.get_file(), box.position, box.size, tris])
		root.free()
	quit()


func _bounds(node: Node, xform: Transform3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var current: Transform3D = xform
	if node is Node3D:
		current = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		result = current * (node as MeshInstance3D).get_aabb()
		first = false
	for child: Node in node.get_children():
		var b: AABB = _bounds(child, current)
		if b.size == Vector3.ZERO:
			continue
		result = b if first else result.merge(b)
		first = false
	return result


func _tris(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += idx.size() / 3
	for child: Node in node.get_children():
		count += _tris(child)
	return count
