extends SceneTree
## Mede o corpo de um personagem para o encaixe dos itens ([ART-02]): caixa (m) do tronco e do pé esquerdo em repouso,
## a partir do início do osso de encaixe ("Chest" / "LeftFoot") e com os eixos do personagem (+Y cima, +Z frente).
## Usa os vértices da malha presos (peso dominante) aos ossos de cada parte. Os números vão para
## [member CharacterModel.chest_fit_box] e [member CharacterModel.foot_fit_box] da cena do corpo.
##
## Rodar da pasta mmo-client:
##   godot --headless --path . --script res://tools/placeholders/measure_body.gd -- res://assets/characters/male/male_character.tscn

## Parte → [osso de encaixe, ossos cujos vértices contam].
const PARTS: Dictionary[String, Array] = {
	"tronco": ["Chest", ["Spine", "Chest", "UpperChest"]],
	"ombros": ["Chest", ["Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder"]],
	"quadril": ["Chest", ["Hips"]],
	"pe": ["LeftFoot", ["LeftFoot", "LeftToes"]],
	"cabeca": ["Head", ["Head"]],
}


var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_measure()
	return false


func _measure() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var model: CharacterModel = (load(path) as PackedScene).instantiate() as CharacterModel
	get_root().add_child(model)
	var skeleton: Skeleton3D = model.get_node(model.skeleton_path) as Skeleton3D
	var body: MeshInstance3D = model.get_node(model.body_path) as MeshInstance3D
	skeleton.reset_bone_poses()
	for part: String in PARTS:
		var mount_bone: int = skeleton.find_bone(String(PARTS[part][0]))
		var origin: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(mount_bone).origin
		var wanted: Array = PARTS[part][1]
		var box: AABB = _bounds(skeleton, body, wanted, origin)
		var low: Vector3 = box.position
		var high: Vector3 = box.end
		print("%s: osso %s em %s | x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f | tamanho %s" % [
			part, PARTS[part][0], origin, low.x, high.x, low.y, high.y, low.z, high.z, box.size])
	quit()


## Caixa dos vértices de [param body] cujo osso de maior peso está em [param wanted], relativa a [param origin].
func _bounds(skeleton: Skeleton3D, body: MeshInstance3D, wanted: Array, origin: Vector3) -> AABB:
	var skin: Skin = body.skin
	var to_global: Transform3D = body.global_transform
	var result: AABB = AABB()
	var first: bool = true
	var mesh: ArrayMesh = body.mesh as ArrayMesh
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			continue
		var per_vertex: int = bones.size() / vertices.size()
		for i: int in range(vertices.size()):
			var best: int = 0
			for k: int in range(1, per_vertex):
				if weights[i * per_vertex + k] > weights[i * per_vertex + best]:
					best = k
			var bind: int = bones[i * per_vertex + best]
			var bone_name: String = String(skin.get_bind_name(bind)) if skin != null and skin.get_bind_name(bind) != &"" else skeleton.get_bone_name(skin.get_bind_bone(bind) if skin != null else bind)
			if not wanted.has(bone_name):
				continue
			var point: Vector3 = to_global * vertices[i] - origin
			if first:
				result = AABB(point, Vector3.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result
