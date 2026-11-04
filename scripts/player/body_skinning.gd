class_name BodySkinning
extends RefCounted
## "Veste" um item rígido no esqueleto ([ART-04]): copia as malhas do item para uma malha com pesos (skinned, como a do
## corpo) em que cada vértice segue o osso certo. Usado no item de peito: as **ombreiras** seguem o ombro e o braço
## (antes eram presas ao peito e o braço saía de dentro delas ao levantar) e o resto segue o peito.
##
## Os pesos são calculados pela posição de cada vértice com o corpo em repouso (pose T), no espaço do esqueleto:
## - braço: perto da junta do ombro, de lado (além de [constant ARM_START_M] antes da junta) e na altura dela (acima
##   de [constant ARM_BELOW_M] da junta), com rampa suave; dividido entre `<Lado>Shoulder` e `<Lado>UpperArm`
##   ([constant UPPER_ARM_SHARE]);
## - resto: o osso onde o item estava preso ([param base_bone]).
## Lados: +X do esqueleto = esquerda do personagem.

## Distância lateral (m) antes da junta do ombro em que o braço começa a puxar o vértice (rampa até [constant ARM_FULL_M]).
const ARM_START_M: float = 0.07
## Distância lateral (m) depois da junta em que o vértice já segue o braço por inteiro.
const ARM_FULL_M: float = 0.02
## Abaixo da junta do ombro (m): até aqui o vértice ainda é da axila/lateral do tronco (fica no peito)...
const ARM_BELOW_M: float = 0.14
## ...e daqui para cima já pode seguir o braço inteiro.
const ARM_LEVEL_M: float = 0.06
## Parte do peso do braço que vai para o UpperArm (o resto vai para a clavícula, `<Lado>Shoulder`).
const UPPER_ARM_SHARE: float = 0.6


## Cria, como filho de [param skeleton], as malhas com pesos equivalentes às malhas de [param model] e devolve os nós
## criados (quem chamou esconde/libera o [param model]). [param rest] = onde o [param model] ficaria, no espaço do
## esqueleto, com o corpo em repouso. [param base_bone] = osso que segue o que não é ombreira (ex.: "Chest").
static func skin(model: Node3D, skeleton: Skeleton3D, rest: Transform3D, base_bone: String) -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	var base: int = skeleton.find_bone(base_bone)
	if base < 0:
		return created
	var bones: PackedInt32Array = [base]
	for name: String in ["LeftShoulder", "LeftUpperArm", "RightShoulder", "RightUpperArm"]:
		bones.append(skeleton.find_bone(name))
	var skin_resource: Skin = Skin.new()
	for bone: int in bones:
		skin_resource.add_bind(maxi(bone, 0), skeleton.get_bone_global_rest(maxi(bone, 0)).affine_inverse())
	var joints: Dictionary[String, Vector3] = {}
	for side: String in ["Left", "Right"]:
		var upper: int = skeleton.find_bone(side + "UpperArm")
		if upper >= 0:
			joints[side] = skeleton.get_bone_global_rest(upper).origin
	_collect(model, rest * model.transform.affine_inverse(), skeleton, skin_resource, bones, joints, created)
	return created


## Percorre [param node] (e filhos) acumulando a transformação [param parent_xform] (espaço do esqueleto).
static func _collect(node: Node, parent_xform: Transform3D, skeleton: Skeleton3D, skin_resource: Skin,
		bones: PackedInt32Array, joints: Dictionary[String, Vector3], created: Array[MeshInstance3D]) -> void:
	var xform: Transform3D = parent_xform * (node as Node3D).transform if node is Node3D else parent_xform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = _skinned_copy(node as MeshInstance3D, xform, skin_resource, bones, joints)
		skeleton.add_child(instance)
		instance.skeleton = instance.get_path_to(skeleton)
		created.append(instance)
	for child: Node in node.get_children():
		_collect(child, xform, skeleton, skin_resource, bones, joints, created)


## Cópia de [param source] com vértices no espaço do esqueleto ([param xform]) e pesos por osso.
static func _skinned_copy(source: MeshInstance3D, xform: Transform3D, skin_resource: Skin, bones: PackedInt32Array,
		joints: Dictionary[String, Vector3]) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	var normal_basis: Basis = xform.basis.inverse().transposed()
	for surface: int in range(source.mesh.get_surface_count()):
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bone_indices: PackedInt32Array = PackedInt32Array()
		var weights: PackedFloat32Array = PackedFloat32Array()
		bone_indices.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for v: int in range(vertices.size()):
			vertices[v] = xform * vertices[v]
			if v < normals.size():
				normals[v] = (normal_basis * normals[v]).normalized()
			_weights_for(vertices[v], bones, joints, bone_indices, weights, v)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null  # não vale mais depois de mudar o espaço (low poly sem normal map)
		arrays[Mesh.ARRAY_BONES] = bone_indices
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = source.get_active_material(surface)
		if material != null:
			mesh.surface_set_material(surface, material)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = source.name + "Skinned"
	instance.mesh = mesh
	instance.skin = skin_resource
	instance.cast_shadow = source.cast_shadow
	return instance


## Pesos do vértice [param v] em [param point] (espaço do esqueleto). Ordem dos binds: base, LeftShoulder,
## LeftUpperArm, RightShoulder, RightUpperArm (índices do bind, não do osso).
static func _weights_for(point: Vector3, bones: PackedInt32Array, joints: Dictionary[String, Vector3],
		bone_indices: PackedInt32Array, weights: PackedFloat32Array, v: int) -> void:
	var side: String = "Left" if point.x > 0.0 else "Right"
	var arm: float = 0.0
	if joints.has(side):
		var joint: Vector3 = joints[side]
		var lateral: float = absf(point.x) - absf(joint.x)
		arm = smoothstep(-ARM_START_M, ARM_FULL_M, lateral) * smoothstep(joint.y - ARM_BELOW_M, joint.y - ARM_LEVEL_M, point.y)
	var first: int = 1 if side == "Left" else 3
	if bones[first] < 0 or bones[first + 1] < 0:
		arm = 0.0
	bone_indices[v * 4] = 0
	weights[v * 4] = 1.0 - arm
	bone_indices[v * 4 + 1] = first
	weights[v * 4 + 1] = arm * (1.0 - UPPER_ARM_SHARE)
	bone_indices[v * 4 + 2] = first + 1
	weights[v * 4 + 2] = arm * UPPER_ARM_SHARE
	bone_indices[v * 4 + 3] = 0
	weights[v * 4 + 3] = 0.0
