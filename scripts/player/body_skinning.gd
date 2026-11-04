class_name BodySkinning
extends RefCounted
## "Veste" roupas no corpo ([ART-04]): o item de peito e os calçados viram malhas com pesos (skinned, como a do corpo)
## que dobram junto com o corpo, em vez de peças rígidas presas a um osso só.
##
## **Transferência de pesos:** cada vértice da roupa, com o corpo em repouso (pose T), copia os pesos dos
## [constant NEIGHBORS] vértices do corpo mais próximos (média pela distância). Assim a ombreira segue ombro e braço, a
## barra da túnica segue quadril e coxas, a bota segue pé e canela — exatamente como a pele embaixo dela.
##
## **Calçado:** encaixado pelos vértices do PÉ do corpo (ossos `<Lado>Foot`/`<Lado>Toes`), direto no espaço do
## esqueleto: sola na sola, centrado no comprimento e na largura, com o bico para a frente mesmo que a cena do item
## esteja virada ([method foot_rest]). O pé direito usa o modelo do esquerdo espelhado em X.
##
## Os dados do corpo (posições em repouso, pesos e a grade de busca) são calculados uma vez por malha de corpo
## ([method sample]) e reaproveitados por todos os personagens com o mesmo corpo.

## Quantos vértices do corpo entram na média de cada vértice da roupa.
const NEIGHBORS: int = 4
## Lado (m) de cada célula da grade de busca.
const CELL_M: float = 0.05
## Folga do calçado sobre o pé (fração): a bota fica um pouco maior que o pé, para o pé não atravessar.
const FOOT_MARGIN: float = 1.12
## Quanto (m) a sola da bota fica abaixo da sola do pé (a pele não aparece por baixo; o chão esconde a diferença).
const SOLE_DROP_M: float = 0.006
## Ossos que contam como "pé" (prefixo do lado na frente).
const FOOT_BONES: Array[String] = ["Foot", "Toes"]

## Malha de corpo → dados dela ([BodyData]).
static var _cache: Dictionary[Mesh, BodyData] = {}


## Dados de um corpo, no espaço do esqueleto, com o corpo em repouso.
class BodyData:
	## Posição de cada vértice (m).
	var positions: PackedVector3Array = PackedVector3Array()
	## 4 ossos (índices do esqueleto) e 4 pesos por vértice.
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	## Célula → vértices nela.
	var grid: Dictionary[Vector3i, PackedInt32Array] = {}
	## Skin com um bind por osso do esqueleto (bind i = osso i), para as roupas.
	var skin: Skin = null


## Dados do corpo [param body] (malha com pesos) no esqueleto [param skeleton]; calculados na primeira vez.
static func sample(body: MeshInstance3D, skeleton: Skeleton3D) -> BodyData:
	if _cache.has(body.mesh):
		return _cache[body.mesh]
	var data: BodyData = BodyData.new()
	var body_skin: Skin = body.skin
	var bind_bone: PackedInt32Array = PackedInt32Array()
	for b: int in range(body_skin.get_bind_count()):
		var bone: int = skeleton.find_bone(body_skin.get_bind_name(b)) if body_skin.get_bind_name(b) != &"" else body_skin.get_bind_bone(b)
		bind_bone.append(bone)
	# Malha → esqueleto em repouso: repouso do osso × bind (igual para qualquer bind; usa o primeiro válido).
	var to_skeleton: Transform3D = Transform3D.IDENTITY
	for b: int in range(bind_bone.size()):
		if bind_bone[b] >= 0:
			to_skeleton = skeleton.get_bone_global_rest(bind_bone[b]) * body_skin.get_bind_pose(b)
			break
	for surface: int in range(body.mesh.get_surface_count()):
		var arrays: Array = body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / maxi(1, vertices.size())
		for v: int in range(vertices.size()):
			var index: int = data.positions.size()
			var point: Vector3 = to_skeleton * vertices[v]
			data.positions.append(point)
			for k: int in range(4):
				var bind: int = bones[v * per + k] if k < per else 0
				data.bones.append(maxi(0, bind_bone[bind]) if bind < bind_bone.size() else 0)
				data.weights.append(weights[v * per + k] if k < per else 0.0)
			var cell: Vector3i = _cell(point)
			if not data.grid.has(cell):
				data.grid[cell] = PackedInt32Array()
			data.grid[cell].append(index)
	data.skin = Skin.new()
	for bone: int in range(skeleton.get_bone_count()):
		data.skin.add_bind(bone, skeleton.get_bone_global_rest(bone).affine_inverse())
	_cache[body.mesh] = data
	return data


## Onde fica o calçado [param model] (feito para o pé esquerdo, bico em +Z) no pé [param side] ("Left"/"Right"), no
## espaço do esqueleto em repouso. O direito sai espelhado em X. Identidade se o corpo não tem vértices de pé.
static func foot_rest(model: Node3D, data: BodyData, skeleton: Skeleton3D, side: String) -> Transform3D:
	var foot_bones: PackedInt32Array = PackedInt32Array()
	for name: String in FOOT_BONES:
		var bone: int = skeleton.find_bone(side + name)
		if bone >= 0:
			foot_bones.append(bone)
	var foot: AABB = AABB()
	var found: bool = false
	for v: int in range(data.positions.size()):
		if _dominant_bone(data, v) in foot_bones:
			foot = AABB(data.positions[v], Vector3.ZERO) if not found else foot.expand(data.positions[v])
			found = true
	# Pontos do calçado no espaço da cena do item; virado 180° se o bico estiver para trás ([method _toe_turn]).
	var points: PackedVector3Array = PackedVector3Array()
	_gather_points(model, Transform3D.IDENTITY, points, true)
	if not found or points.is_empty():
		return Transform3D.IDENTITY
	var turn: Basis = _toe_turn(points)
	var item: AABB = AABB(turn * points[0], Vector3.ZERO)
	for point: Vector3 in points:
		item = item.expand(turn * point)
	if item.size.z <= 0.0 or item.size.x <= 0.0:
		return Transform3D.IDENTITY
	var scale: float = maxf(foot.size.z / item.size.z, foot.size.x / item.size.x) * FOOT_MARGIN
	var mirror: float = -1.0 if side == "Right" else 1.0
	var sized: Basis = Basis.from_scale(Vector3(mirror * scale, scale, scale))
	# Sola na sola, centro do calcanhar ao bico no centro do pé (a folga fica dividida), centrado na largura.
	var item_anchor: Vector3 = sized * Vector3(item.get_center().x, item.position.y, item.get_center().z)
	var foot_anchor: Vector3 = Vector3(foot.get_center().x, foot.position.y - SOLE_DROP_M, foot.get_center().z)
	return Transform3D(sized * turn, foot_anchor - item_anchor)


## Giro que deixa o bico do calçado em +Z. O cano (parte alta) fica sobre o calcanhar: se o meio dos pontos altos
## (30% de cima) está do lado +Z do centro, o bico está em −Z e o calçado gira 180° em Y. Os calçados do Meshy
## vieram todos com o bico em −Z na cena (2026-11-04): era por isso que as botas ficavam fora do pé.
static func _toe_turn(points: PackedVector3Array) -> Basis:
	var low: float = INF
	var high: float = -INF
	var z_min: float = INF
	var z_max: float = -INF
	for point: Vector3 in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
		z_min = minf(z_min, point.z)
		z_max = maxf(z_max, point.z)
	var top_z: float = 0.0
	var count: int = 0
	for point: Vector3 in points:
		if point.y > low + (high - low) * 0.7:
			top_z += point.z
			count += 1
	if count == 0:
		return Basis.IDENTITY
	return Basis(Vector3.UP, PI) if top_z / float(count) > (z_min + z_max) / 2.0 else Basis.IDENTITY


## Vértices das malhas de [param node] e filhos, no espaço de [param node] ([param is_root]: a transformação da raiz
## não entra, como em [method ItemModels.local_bounds]).
static func _gather_points(node: Node, parent_xform: Transform3D, points: PackedVector3Array, is_root: bool) -> void:
	var xform: Transform3D = parent_xform if is_root or not (node is Node3D) else parent_xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		for vertex: Vector3 in (node as MeshInstance3D).mesh.get_faces():
			points.append(xform * vertex)
	for child: Node in node.get_children():
		_gather_points(child, xform, points, false)


## Cria, como filhos de [param skeleton], as malhas com pesos equivalentes às de [param model], com o [param model]
## posto em [param rest] (espaço do esqueleto, corpo em repouso). Quem chamou libera/esconde o [param model].
static func skin(model: Node3D, skeleton: Skeleton3D, rest: Transform3D, data: BodyData) -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	_collect(model, rest * model.transform.affine_inverse(), skeleton, data, created)
	return created


static func _collect(node: Node, parent_xform: Transform3D, skeleton: Skeleton3D, data: BodyData,
		created: Array[MeshInstance3D]) -> void:
	var xform: Transform3D = parent_xform * (node as Node3D).transform if node is Node3D else parent_xform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = _skinned_copy(node as MeshInstance3D, xform, data)
		skeleton.add_child(instance)
		instance.skeleton = instance.get_path_to(skeleton)
		created.append(instance)
	for child: Node in node.get_children():
		_collect(child, xform, skeleton, data, created)


## Cópia de [param source] com vértices no espaço do esqueleto ([param xform]) e os pesos transferidos do corpo.
static func _skinned_copy(source: MeshInstance3D, xform: Transform3D, data: BodyData) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	var normal_basis: Basis = xform.basis.inverse().transposed()
	var mirrored: bool = xform.basis.determinant() < 0.0
	for surface: int in range(source.mesh.get_surface_count()):
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bones: PackedInt32Array = PackedInt32Array()
		var weights: PackedFloat32Array = PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for v: int in range(vertices.size()):
			vertices[v] = xform * vertices[v]
			if v < normals.size():
				normals[v] = (normal_basis * normals[v]).normalized()
			_transfer(vertices[v], data, bones, weights, v)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null  # não vale mais depois de mudar o espaço (low poly sem normal map)
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		if mirrored:
			# Espelhado: a ordem dos cantos de cada triângulo inverte (senão a face aponta para dentro).
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
			for t: int in range(0, indices.size() - 2, 3):
				var swap: int = indices[t + 1]
				indices[t + 1] = indices[t + 2]
				indices[t + 2] = swap
			arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = source.get_active_material(surface)
		if material != null:
			mesh.surface_set_material(surface, material)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = source.name + "Skinned"
	instance.mesh = mesh
	instance.skin = data.skin
	instance.cast_shadow = source.cast_shadow
	return instance


## Pesos do vértice [param v] (em [param point]) = média, pela distância, dos [constant NEIGHBORS] vértices do corpo
## mais próximos; ficam os 4 ossos de maior peso, normalizados.
static func _transfer(point: Vector3, data: BodyData, bones: PackedInt32Array, weights: PackedFloat32Array, v: int) -> void:
	var nearest: Array[Vector2] = _nearest(point, data)  # (distância, índice)
	var total: Dictionary[int, float] = {}
	for pair: Vector2 in nearest:
		var factor: float = 1.0 / pow(pair.x + 0.01, 2.0)
		var body_vertex: int = int(pair.y)
		for k: int in range(4):
			var w: float = data.weights[body_vertex * 4 + k]
			if w > 0.0:
				var bone: int = data.bones[body_vertex * 4 + k]
				total[bone] = total.get(bone, 0.0) + w * factor
	var ranked: Array = total.keys()
	ranked.sort_custom(func(a: int, b: int) -> bool: return total[a] > total[b])
	var sum: float = 0.0
	for k: int in range(mini(4, ranked.size())):
		sum += total[ranked[k]]
	for k: int in range(4):
		var has: bool = k < ranked.size() and sum > 0.0
		bones[v * 4 + k] = int(ranked[k]) if has else 0
		weights[v * 4 + k] = total[ranked[k]] / sum if has else 0.0


## Os [constant NEIGHBORS] vértices do corpo mais perto de [param point]: procura em anéis de células até achar.
static func _nearest(point: Vector3, data: BodyData) -> Array[Vector2]:
	var center: Vector3i = _cell(point)
	var found: Array[Vector2] = []
	for ring: int in range(0, 12):
		for x: int in range(-ring, ring + 1):
			for y: int in range(-ring, ring + 1):
				for z: int in range(-ring, ring + 1):
					if maxi(absi(x), maxi(absi(y), absi(z))) != ring:
						continue
					var cell: Vector3i = center + Vector3i(x, y, z)
					if not data.grid.has(cell):
						continue
					for index: int in data.grid[cell]:
						found.append(Vector2(point.distance_to(data.positions[index]), index))
		# Depois de achar o bastante, mais um anel garante que nenhum vizinho mais perto ficou de fora.
		if found.size() >= NEIGHBORS and ring > 0:
			break
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return found.slice(0, NEIGHBORS)


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i((point / CELL_M).floor())


static func _dominant_bone(data: BodyData, v: int) -> int:
	var best: int = 0
	for k: int in range(1, 4):
		if data.weights[v * 4 + k] > data.weights[v * 4 + best]:
			best = k
	return data.bones[v * 4 + best]
