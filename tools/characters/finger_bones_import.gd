@tool
extends EditorScenePostImport
## Script de importação dos corpos ([ART-07]): acrescenta ossos de dedo nas mãos para o personagem poder FECHAR a
## mão segurando a arma ([HandGrip]). O rig dos corpos (Meshy/Mixamo "sem dedos", 24 ossos) termina na mão: os dedos
## existem na malha, mas seguem o osso da mão e ficam sempre abertos.
##
## Por mão cria 2 ossos, filhos da mão:
## - `<Lado>Fingers`: os 4 dedos juntos, a partir dos nós dos dedos (a malha low poly tem "membrana" entre eles e não
##   separa dedo por dedo: dobram como uma luva);
## - `<Lado>Thumb`: o polegar (a "ilha" de vértices que se solta da mão primeiro, de lado).
## Os vértices desses pedaços passam para o osso novo, com uma faixa de transição na dobra ([constant BLEND_M]).
## Cada osso novo nasce com o eixo Y apontando ao longo do dedo e o X como eixo de dobra: girar +X fecha o dedo em
## direção à palma (a palma aponta para baixo na pose T).
##
## Ligado no `.glb.import` do corpo (`import_script/path`); roda a cada importação, o `.glb` não muda.
## Roda depois do mapa de ossos: os nomes já são os do jogo ("RightHand"). Unidades em metros, espaço do osso da mão
## (Y = do pulso para os dedos).

## Onde ficam os nós dos dedos, como fração do comprimento da mão (do vértice mais perto do pulso à ponta).
const KNUCKLE_FRACTION: float = 0.55
## Meia largura (m) da faixa de transição na dobra: abaixo dela tudo segue a mão; acima, tudo segue o dedo.
const BLEND_M: float = 0.01
## Peso mínimo (0..1) no osso da mão para um vértice contar como "da mão".
const HAND_WEIGHT_MIN: float = 0.5
## Passo (m) da busca do corte em que o polegar se solta.
const THUMB_SCAN_STEP: float = 0.005
## Direção da palma na pose T (espaço do esqueleto): para baixo.
const PALM_DIRECTION: Vector3 = Vector3.DOWN


func _post_import(scene: Node) -> Object:
	var skeletons: Array[Node] = scene.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if skeletons.is_empty() or meshes.is_empty():
		return scene
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	for node: Node in meshes:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.skin == null or not (instance.mesh is ArrayMesh):
			continue
		for side: String in ["Right", "Left"]:
			_add_finger_bones(skeleton, instance, side)
	return scene


## Cria os ossos de dedo de um lado ([param side] = "Right"/"Left") e passa os vértices para eles.
func _add_finger_bones(skeleton: Skeleton3D, instance: MeshInstance3D, side: String) -> void:
	var hand_bone: int = skeleton.find_bone(side + "Hand")
	if hand_bone < 0 or skeleton.find_bone(side + "Fingers") >= 0:
		return
	var skin: Skin = instance.skin
	var hand_bind: int = _bind_index(skin, skeleton, hand_bone)
	if hand_bind < 0:
		push_warning("finger_bones_import: sem bind para %sHand" % side)
		return
	var mesh: ArrayMesh = instance.mesh as ArrayMesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vertex: int = bones.size() / vertices.size()
	var hand_bind_pose: Transform3D = skin.get_bind_pose(hand_bind)

	# Vértices da mão, no espaço do osso da mão (o bind leva da malha para o osso).
	var local: Dictionary[int, Vector3] = {}
	var y_min: float = INF
	var y_max: float = -INF
	for v: int in range(vertices.size()):
		var weight: float = 0.0
		for k: int in range(per_vertex):
			if bones[v * per_vertex + k] == hand_bind:
				weight += weights[v * per_vertex + k]
		if weight >= HAND_WEIGHT_MIN:
			var point: Vector3 = hand_bind_pose * vertices[v]
			local[v] = point
			y_min = minf(y_min, point.y)
			y_max = maxf(y_max, point.y)
	if local.is_empty():
		return
	var knuckle: float = y_min + (y_max - y_min) * KNUCKLE_FRACTION
	var thumb: Dictionary[int, bool] = _thumb_vertices(local, vertices, indices, y_min, knuckle)
	var thumb_cut: float = INF
	for v: int in thumb:
		thumb_cut = minf(thumb_cut, local[v].y)

	var fingers: Dictionary[int, bool] = {}
	for v: int in local:
		if not thumb.has(v) and local[v].y > knuckle - BLEND_M:
			fingers[v] = true

	var palm: Vector3 = (skeleton.get_bone_global_rest(hand_bone).basis.inverse() * PALM_DIRECTION).normalized()
	var finger_bind: int = _add_bone(skeleton, skin, hand_bone, hand_bind, side + "Fingers", local, fingers, knuckle, palm)
	var thumb_bind: int = _add_bone(skeleton, skin, hand_bone, hand_bind, side + "Thumb", local, thumb, thumb_cut, palm) \
		if not thumb.is_empty() else -1

	# Pesos: dedo = rampa de 0 a 1 na faixa da dobra; o resto continua na mão.
	for v: int in fingers:
		_set_two_weights(bones, weights, per_vertex, v, finger_bind, hand_bind, _ramp(local[v].y, knuckle))
	for v: int in thumb:
		_set_two_weights(bones, weights, per_vertex, v, thumb_bind, hand_bind, _ramp(local[v].y, thumb_cut + BLEND_M))
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	_replace_surface(instance, mesh, arrays)
	print("finger_bones_import: %s %s: %d vértices nos dedos, %d no polegar" % [instance.name, side, fingers.size(), thumb.size()])


## Índice do bind de [param bone] na [param skin] (bind por nome ou por índice de osso), ou -1.
func _bind_index(skin: Skin, skeleton: Skeleton3D, bone: int) -> int:
	for b: int in range(skin.get_bind_count()):
		if skin.get_bind_name(b) == skeleton.get_bone_name(bone) or skin.get_bind_bone(b) == bone:
			return b
	return -1


## Vértices do polegar: subindo o corte a partir do meio da palma, o primeiro em que a mão se parte em pedaços (pela
## malha); o polegar é o pedaço mais de lado (mais longe do eixo da mão). Vazio se não achar.
func _thumb_vertices(local: Dictionary[int, Vector3], vertices: PackedVector3Array, indices: PackedInt32Array,
		y_min: float, knuckle: float) -> Dictionary[int, bool]:
	# Vértices na mesma posição (costura de UV) contam como um só.
	var key_of: Dictionary[int, int] = {}
	var keys: Dictionary[Vector3i, int] = {}
	for v: int in local:
		var key: Vector3i = Vector3i((vertices[v] * 10000.0).round())
		if not keys.has(key):
			keys[key] = keys.size()
		key_of[v] = keys[key]
	var cut: float = y_min + (knuckle - y_min) * 0.5
	while cut < knuckle:
		var groups: Dictionary[int, Array] = _islands(local, key_of, indices, cut)
		if groups.size() >= 2:
			var best: Array = []
			var best_side: float = -1.0
			for root: int in groups:
				var members: Array = groups[root]
				var center: Vector3 = Vector3.ZERO
				for v: int in members:
					center += local[v]
				center /= float(members.size())
				var side_distance: float = Vector2(center.x, center.z).length()
				if side_distance > best_side:
					best_side = side_distance
					best = members
			var result: Dictionary[int, bool] = {}
			for v: int in best:
				result[v] = true
			return result
		cut += THUMB_SCAN_STEP
	return {}


## Pedaços conectados (pelas arestas dos triângulos) dos vértices da mão acima de [param cut]: raiz → vértices.
func _islands(local: Dictionary[int, Vector3], key_of: Dictionary[int, int], indices: PackedInt32Array, cut: float) -> Dictionary[int, Array]:
	var parent: Dictionary[int, int] = {}
	for v: int in local:
		if local[v].y > cut:
			parent[key_of[v]] = key_of[v]
	for t: int in range(0, indices.size(), 3):
		for e: int in range(3):
			var a: int = indices[t + e]
			var b: int = indices[t + (e + 1) % 3]
			if not key_of.has(a) or not key_of.has(b):
				continue
			var ka: int = key_of[a]
			var kb: int = key_of[b]
			if parent.has(ka) and parent.has(kb):
				var ra: int = _find(parent, ka)
				var rb: int = _find(parent, kb)
				if ra != rb:
					parent[ra] = rb
	var groups: Dictionary[int, Array] = {}
	for v: int in local:
		if parent.has(key_of[v]):
			var root: int = _find(parent, key_of[v])
			if not groups.has(root):
				groups[root] = []
			groups[root].append(v)
	return groups


func _find(parent: Dictionary[int, int], key: int) -> int:
	while parent[key] != key:
		parent[key] = parent[parent[key]]
		key = parent[key]
	return key


## Cria o osso [param bone_name] (filho da mão) na base dos vértices [param members] (altura [param base_y] no espaço da
## mão), com Y ao longo do dedo e X = eixo de dobra para a [param palm]; acrescenta o bind na [param skin]. Devolve o
## índice do bind novo.
func _add_bone(skeleton: Skeleton3D, skin: Skin, hand_bone: int, hand_bind: int, bone_name: String,
		local: Dictionary[int, Vector3], members: Dictionary[int, bool], base_y: float, palm: Vector3) -> int:
	var base: Vector3 = Vector3.ZERO
	var base_count: int = 0
	var tip: Vector3 = Vector3.ZERO
	for v: int in members:
		tip += local[v]
		if local[v].y < base_y + 2.0 * BLEND_M:
			base += local[v]
			base_count += 1
	tip /= float(members.size())
	base = base / float(base_count) if base_count > 0 else Vector3(tip.x, base_y, tip.z)
	var along: Vector3 = (tip - base).normalized()
	if along.length() < 0.5:
		along = Vector3.UP  # pedaço sem comprimento: ao longo da mão
	var bend_axis: Vector3 = along.cross(palm)
	if bend_axis.length() < 0.2:
		# Dedo apontando quase para a palma (polegar de alguns corpos): dobra no mesmo eixo dos outros dedos
		# (eixo da mão × palma), tirada a parte ao longo do dedo.
		bend_axis = Vector3.UP.cross(palm)
		bend_axis -= along * bend_axis.dot(along)
	bend_axis = bend_axis.normalized()
	var rest_basis: Basis = Basis(bend_axis, along, bend_axis.cross(along)).orthonormalized()
	var rest: Transform3D = Transform3D(rest_basis, base)  # no espaço da mão

	var bone: int = skeleton.get_bone_count()
	skeleton.add_bone(bone_name)
	skeleton.set_bone_parent(bone, hand_bone)
	skeleton.set_bone_rest(bone, rest)
	skeleton.reset_bone_pose(bone)
	# Bind: mesmo "malha → esqueleto" da mão, agora até o osso novo.
	var bind: int = skin.get_bind_count()
	skin.add_named_bind(bone_name, rest.affine_inverse() * skin.get_bind_pose(hand_bind))
	return bind


## 0 abaixo da faixa da dobra, 1 acima, rampa linear no meio ([param fold] = centro da faixa).
func _ramp(y: float, fold: float) -> float:
	return clampf((y - (fold - BLEND_M)) / (2.0 * BLEND_M), 0.0, 1.0)


## Vértice [param v] passa a seguir [param bind_a] com peso [param weight_a] e a mão ([param bind_b]) com o resto.
func _set_two_weights(bones: PackedInt32Array, weights: PackedFloat32Array, per_vertex: int, v: int,
		bind_a: int, bind_b: int, weight_a: float) -> void:
	for k: int in range(per_vertex):
		bones[v * per_vertex + k] = 0
		weights[v * per_vertex + k] = 0.0
	bones[v * per_vertex] = bind_a
	weights[v * per_vertex] = weight_a
	bones[v * per_vertex + 1] = bind_b
	weights[v * per_vertex + 1] = 1.0 - weight_a


## Troca a superfície 0 da malha pelos [param arrays] novos (mesmo material e nome), refazendo os LODs.
func _replace_surface(instance: MeshInstance3D, mesh: ArrayMesh, arrays: Array) -> void:
	var importer: ImporterMesh = ImporterMesh.new()
	importer.set_blend_shape_mode(mesh.blend_shape_mode)
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh.surface_get_material(0), mesh.surface_get_name(0))
	importer.generate_lods(60.0, 0.0, [])
	var rebuilt: ArrayMesh = importer.get_mesh()
	rebuilt.resource_name = mesh.resource_name
	instance.mesh = rebuilt
