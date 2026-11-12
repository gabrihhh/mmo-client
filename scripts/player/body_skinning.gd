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
## Item de peito: parte do peso do braço que fica no braço (o resto vai para a clavícula, `<Lado>Shoulder`). A peça
## fica por cima do ombro, longe da junta: seguindo o braço inteiro ela gira demais e amassa quando o braço desce da
## pose T (a ombreira desabava e o braço atravessava).
const CHEST_ARM_SHARE: float = 0.35
## Ossos do braço (prefixo do lado na frente), todos levados ao UpperArm/Shoulder no item de peito.
const ARM_BONES: Array[String] = ["UpperArm", "LowerArm", "Hand", "Fingers", "Thumb"]
## Pele coberta por roupa sob medida ([method covered_mesh]): até quanto (m) para fora da pele, pela normal, a roupa
## ainda conta como "por cima".
const COVER_REACH_M: float = 0.06
## Idem, quanto (m) para dentro da pele: roupa modelada encostada ou levemente afundada também cobre.
const COVER_INSET_M: float = 0.01
## Quanto (m) a pele coberta afunda (pela normal, para dentro): com o braço baixando da pose T a pele do ombro sobe
## mais que a roupa e atravessava. Afundar (em vez de apagar) não abre buraco por onde se veja através do corpo.
const COVER_SINK_M: float = 0.025
## Ossos que contam como "pé" (prefixo do lado na frente).
const FOOT_BONES: Array[String] = ["Foot", "Toes"]

## Malha de corpo → dados dela ([BodyData]).
static var _cache: Dictionary[Mesh, BodyData] = {}
## Roupa já vestida: chave (corpo|item|encaixe) → [[ArrayMesh, nome, sombra], ...]. Calcular os pesos custa de 0,1 a
## 0,6 s no PC (bem mais no celular); com o cache, trocar de roupa de novo é instantâneo (o atirador de teste troca a
## cada ~3 s e congelava o jogo).
static var _mesh_cache: Dictionary[String, Array] = {}
## Corpo com pele afundada sob roupa sob medida: chave (corpo|pés|roupa) → malha ([method covered_mesh]).
static var _covered_cache: Dictionary[String, ArrayMesh] = {}


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
	## Item de peito: osso do braço → [[osso, fração], ...] (braço amortecido, [constant CHEST_ARM_SHARE]).
	var chest_remap: Dictionary[int, Array] = {}
	## Malha do corpo com os pés escondidos (para quem está de calçado), criada na primeira vez.
	var feet_hidden: ArrayMesh = null
	## Espaço da malha do corpo → espaço do esqueleto em repouso (para levar as normais junto com as posições).
	var to_skeleton: Transform3D = Transform3D.IDENTITY


## Dados do corpo [param body] (malha com pesos) no esqueleto [param skeleton]; calculados na primeira vez.
## [param original] = a malha original do corpo (o [param body] pode estar com a versão de pés escondidos).
static func sample(body: MeshInstance3D, skeleton: Skeleton3D, original: Mesh = null) -> BodyData:
	var mesh: Mesh = original if original != null else body.mesh
	if _cache.has(mesh):
		return _cache[mesh]
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
	data.to_skeleton = to_skeleton
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
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
	for side: String in ["Left", "Right"]:
		var upper: int = skeleton.find_bone(side + "UpperArm")
		var shoulder: int = skeleton.find_bone(side + "Shoulder")
		if upper < 0:
			continue
		for name: String in ARM_BONES:
			var bone: int = skeleton.find_bone(side + name)
			if bone >= 0:
				data.chest_remap[bone] = [[upper, CHEST_ARM_SHARE], [shoulder if shoulder >= 0 else skeleton.get_bone_parent(upper), 1.0 - CHEST_ARM_SHARE]]
	_cache[mesh] = data
	return data


## Malha do corpo [param body] com os vértices do pé (ossos `<Lado>Foot`/`<Lado>Toes`) encolhidos até o tornozelo:
## com calçado, o pé não aparece por fora (o bico de alguns calçados é mais baixo que os dedos do corpo). Uma por
## malha de corpo, compartilhada.
static func feet_hidden_mesh(body: MeshInstance3D, skeleton: Skeleton3D, original: Mesh) -> ArrayMesh:
	var data: BodyData = _cache.get(original)
	if data == null:
		return null
	if data.feet_hidden != null:
		return data.feet_hidden
	var body_skin: Skin = body.skin
	var foot_binds: Dictionary[int, bool] = {}
	for b: int in range(body_skin.get_bind_count()):
		var bone_name: String = String(body_skin.get_bind_name(b))
		for side: String in ["Left", "Right"]:
			for name: String in FOOT_BONES:
				if bone_name == side + name:
					foot_binds[b] = true
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: int in range(original.get_surface_count()):
		var arrays: Array = original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / maxi(1, vertices.size())
		var ankles: Dictionary[int, Vector3] = _ankles(vertices, bones, weights, per, foot_binds)
		for v: int in range(vertices.size()):
			if _is_foot(bones, weights, per, foot_binds, v):
				# Encolhe para perto do tornozelo: fica escondido dentro do calçado.
				vertices[v] = vertices[v].lerp(ankles[1 if vertices[v].x > 0.0 else -1], 0.85)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, original.surface_get_material(surface))
	data.feet_hidden = mesh
	return mesh


## Malha do corpo ([param base]: a original ou a de pés escondidos, mesma ordem de vértices da [param original]) com a
## pele que fica embaixo das roupas sob medida [param covers] afundada [constant COVER_SINK_M] para dentro. [param covers]
## = malhas já vestidas ([method skin]: vértices no espaço do esqueleto em repouso). Pele coberta = o segmento pela
## normal dela, de [constant COVER_INSET_M] para dentro até [constant COVER_REACH_M] para fora, cruza um triângulo da
## roupa. Calculado uma vez por [param key] e compartilhado.
static func covered_mesh(original: Mesh, base: Mesh, covers: Array[Mesh], key: String) -> ArrayMesh:
	if _covered_cache.has(key):
		return _covered_cache[key]
	var data: BodyData = _cache.get(original)
	if data == null:
		return null
	# Triângulos da roupa numa grade: cada um entra nas células que a caixa dele (aumentada do alcance) toca.
	var tris: PackedVector3Array = PackedVector3Array()
	for cover: Mesh in covers:
		for surface: int in range(cover.get_surface_count()):
			var arrays: Array = cover.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			for i: int in range(0, indices.size() - 2, 3):
				tris.append_array([vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]])
	var grid: Dictionary[Vector3i, PackedInt32Array] = {}
	for t: int in range(tris.size() / 3):
		var box: AABB = AABB(tris[t * 3], Vector3.ZERO).expand(tris[t * 3 + 1]).expand(tris[t * 3 + 2]).grow(COVER_REACH_M)
		var low: Vector3i = _cell(box.position)
		var high: Vector3i = _cell(box.end)
		for x: int in range(low.x, high.x + 1):
			for y: int in range(low.y, high.y + 1):
				for z: int in range(low.z, high.z + 1):
					var cell: Vector3i = Vector3i(x, y, z)
					if not grid.has(cell):
						grid[cell] = PackedInt32Array()
					grid[cell].append(t)
	var mesh: ArrayMesh = ArrayMesh.new()
	var offset: int = 0
	var to_mesh: Basis = data.to_skeleton.basis.inverse()
	for surface: int in range(base.get_surface_count()):
		var arrays: Array = base.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for v: int in range(vertices.size()):
			var cell: Vector3i = _cell(data.positions[offset + v])
			if normals.is_empty() or not grid.has(cell):
				continue
			var point: Vector3 = data.positions[offset + v]
			var normal: Vector3 = (data.to_skeleton.basis * normals[v]).normalized()
			var start: Vector3 = point - normal * COVER_INSET_M
			var end: Vector3 = point + normal * COVER_REACH_M
			for t: int in grid[cell]:
				if Geometry3D.segment_intersects_triangle(start, end, tris[t * 3], tris[t * 3 + 1], tris[t * 3 + 2]) != null:
					vertices[v] -= to_mesh * (normal * COVER_SINK_M)
					break
		offset += vertices.size()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, base.surface_get_material(surface))
	_covered_cache[key] = mesh
	return mesh


## Centro aproximado de cada tornozelo (chave −1 = lado −X, 1 = lado +X): média dos vértices do pé (osso dominante
## em [param foot_binds]) mais altos que o meio daquele pé.
static func _ankles(vertices: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int,
		foot_binds: Dictionary[int, bool]) -> Dictionary[int, Vector3]:
	var result: Dictionary[int, Vector3] = {}
	for side_key: int in [-1, 1]:
		var low: float = INF
		var high: float = -INF
		var members: PackedInt32Array = PackedInt32Array()
		for i: int in range(vertices.size()):
			if _is_foot(bones, weights, per, foot_binds, i) and (1 if vertices[i].x > 0.0 else -1) == side_key:
				members.append(i)
				low = minf(low, vertices[i].y)
				high = maxf(high, vertices[i].y)
		var center: Vector3 = Vector3.ZERO
		var count: int = 0
		for i: int in members:
			if vertices[i].y > (low + high) / 2.0:
				center += vertices[i]
				count += 1
		result[side_key] = center / float(maxi(1, count))
	return result


## true se o osso dominante do vértice [param v] é um osso de pé.
static func _is_foot(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, foot_binds: Dictionary[int, bool], v: int) -> bool:
	var best: int = 0
	for k: int in range(1, per):
		if weights[v * per + k] > weights[v * per + best]:
			best = k
	return foot_binds.has(bones[v * per + best])


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
## [param chest] = item de peito (influência do braço amortecida, [constant CHEST_ARM_SHARE]).
## [param cache_key] (ex.: "<id da malha do corpo>|<itemId>|<encaixe>"): mesma chave = mesmo resultado; a partir da
## segunda vez só cria os nós com as malhas já calculadas ([member _mesh_cache]). Vazio = sem cache.
static func skin(model: Node3D, skeleton: Skeleton3D, rest: Transform3D, data: BodyData, chest: bool = false,
		cache_key: String = "") -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	if not cache_key.is_empty() and _mesh_cache.has(cache_key):
		for entry: Array in _mesh_cache[cache_key]:
			var instance: MeshInstance3D = MeshInstance3D.new()
			instance.mesh = entry[0]
			instance.name = entry[1]
			instance.cast_shadow = entry[2]
			instance.skin = data.skin
			skeleton.add_child(instance)
			instance.skeleton = instance.get_path_to(skeleton)
			created.append(instance)
		return created
	_collect(model, rest * model.transform.affine_inverse(), skeleton, data, created, chest)
	if not cache_key.is_empty():
		var entries: Array = []
		for instance: MeshInstance3D in created:
			entries.append([instance.mesh, instance.name, instance.cast_shadow])
		_mesh_cache[cache_key] = entries
	return created


static func _collect(node: Node, parent_xform: Transform3D, skeleton: Skeleton3D, data: BodyData,
		created: Array[MeshInstance3D], chest: bool) -> void:
	var xform: Transform3D = parent_xform * (node as Node3D).transform if node is Node3D else parent_xform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = _skinned_copy(node as MeshInstance3D, xform, data, chest)
		skeleton.add_child(instance)
		instance.skeleton = instance.get_path_to(skeleton)
		created.append(instance)
	for child: Node in node.get_children():
		_collect(child, xform, skeleton, data, created, chest)


## Cópia de [param source] com vértices no espaço do esqueleto ([param xform]) e os pesos transferidos do corpo.
static func _skinned_copy(source: MeshInstance3D, xform: Transform3D, data: BodyData, chest: bool) -> MeshInstance3D:
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
		# Vértices na mesma posição (costuras de UV/normal) recebem os mesmos pesos: calcula uma vez só.
		var done: Dictionary[Vector3i, int] = {}
		for v: int in range(vertices.size()):
			vertices[v] = xform * vertices[v]
			if v < normals.size():
				normals[v] = (normal_basis * normals[v]).normalized()
			var key: Vector3i = Vector3i((vertices[v] * 10000.0).round())
			if done.has(key):
				var first: int = done[key]
				for k: int in range(4):
					bones[v * 4 + k] = bones[first * 4 + k]
					weights[v * 4 + k] = weights[first * 4 + k]
				continue
			done[key] = v
			_transfer(vertices[v], data, bones, weights, v, chest)
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
static func _transfer(point: Vector3, data: BodyData, bones: PackedInt32Array, weights: PackedFloat32Array, v: int,
		chest: bool) -> void:
	var nearest: Array[Vector2] = _nearest(point, data)  # (distância, índice)
	var total: Dictionary[int, float] = {}
	for pair: Vector2 in nearest:
		var factor: float = 1.0 / pow(pair.x + 0.01, 2.0)
		var body_vertex: int = int(pair.y)
		for k: int in range(4):
			var w: float = data.weights[body_vertex * 4 + k]
			if w > 0.0:
				var bone: int = data.bones[body_vertex * 4 + k]
				if chest and data.chest_remap.has(bone):
					for remap: Array in data.chest_remap[bone]:
						var target: int = remap[0]
						total[target] = total.get(target, 0.0) + w * factor * float(remap[1])
				else:
					total[bone] = total.get(bone, 0.0) + w * factor
	# Os 4 ossos de maior peso (seleção simples: são poucos ossos, sem ordenar a lista toda).
	var top_bones: PackedInt32Array = [-1, -1, -1, -1]
	var top_weights: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]
	for bone: int in total:
		var w: float = total[bone]
		for k: int in range(4):
			if w > top_weights[k]:
				for m: int in range(3, k, -1):
					top_weights[m] = top_weights[m - 1]
					top_bones[m] = top_bones[m - 1]
				top_weights[k] = w
				top_bones[k] = bone
				break
	var sum: float = top_weights[0] + top_weights[1] + top_weights[2] + top_weights[3]
	for k: int in range(4):
		var has: bool = top_bones[k] >= 0 and sum > 0.0
		bones[v * 4 + k] = top_bones[k] if has else 0
		weights[v * 4 + k] = top_weights[k] / sum if has else 0.0


## Os [constant NEIGHBORS] vértices do corpo mais perto de [param point]: procura em anéis de células até achar.
static func _nearest(point: Vector3, data: BodyData) -> Array[Vector2]:
	var center: Vector3i = _cell(point)
	# Os NEIGHBORS melhores até agora, do mais perto ao mais longe (inserção: sem ordenar listas grandes).
	var best: Array[Vector2] = []
	var count: int = 0
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
						count += 1
						var d: float = point.distance_squared_to(data.positions[index])
						if best.size() == NEIGHBORS and d >= best[NEIGHBORS - 1].x:
							continue
						var at: int = best.size()
						while at > 0 and best[at - 1].x > d:
							at -= 1
						best.insert(at, Vector2(d, index))
						if best.size() > NEIGHBORS:
							best.pop_back()
		# Depois de achar o bastante, mais um anel garante que nenhum vizinho mais perto ficou de fora.
		if count >= NEIGHBORS and ring > 0:
			break
	for i: int in range(best.size()):
		best[i].x = sqrt(best[i].x)
	return best


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i((point / CELL_M).floor())


static func _dominant_bone(data: BodyData, v: int) -> int:
	var best: int = 0
	for k: int in range(1, 4):
		if data.weights[v * 4 + k] > data.weights[v * 4 + best]:
			best = k
	return data.bones[v * 4 + best]
