extends SceneTree
## Transforma um peito do Meshy (genérico, encaixado pela caixa do tronco, [ART-04]) em **peça sob medida** de um
## corpo ([ART-08]): veste no corpo em repouso, opcionalmente **estica só a parte de baixo** (abaixo de
## `pivot_fraction` da altura, contando de cima) até a barra ficar em `bottom_y` (m do chão), **empurra para fora da
## pele** todo ponto da roupa que estiver dentro do corpo ou a menos de `margin` (m) dele, e grava o .glb no espaço
## do personagem (origem nos pés, metros). Instalado direto em `<item>/<corpo>/<slot>-<nome>.glb` (sem .tscn), o jogo
## o trata como sob medida e afunda a pele embaixo ([method BodySkinning.covered_mesh]).
## Feito para o casaco longo do assassino (2026-11-14, [MESHY-10]).
##
## Rodar da pasta mmo-client (um corpo por vez):
##   godot --path . --headless --script res://tools/items/tailor_chest.gd -- <item_id> <male|female> <saida.glb> \
##       <bottom_y (0 = não esticar)> <pivot_fraction> [margin=0.02] [glb já sob medida em vez do item vestido]
## Ex.: 1º passo (do genérico, esticando): `-- assassin_vest male /tmp/c.glb 0.14 0.40`; ajuste fino (só empurrar
## mais): `-- assassin_vest female /tmp/c2.glb 0 0.4 0.045 res://assets/itens/chest/assassin/female/chest-assassin.glb`.
## Depois de instalar: a textura extraída volta com `compress/mode=0` — trocar para 2 e `size_limit=256` ([MESHY-01]).
var _frames: int = 0
var _model: CharacterModel = null
var _args: PackedStringArray = []

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_args = OS.get_cmdline_user_args()
		_model = (load("res://assets/characters/%s/%s_character.tscn" % [_args[1], _args[1]]) as PackedScene).instantiate() as CharacterModel
		get_root().add_child(_model)
		(_model.get_node("Animator") as AnimationTree).active = false
		var look: PlayerState = PlayerState.new()
		if _args.size() <= 6:
			look.set_look({"chest": _args[0]})
		_model.bind_look(look)
		return false
	for skeleton: Node in _model.find_children("*", "Skeleton3D", true, false):
		(skeleton as Skeleton3D).reset_bone_poses()
	if _frames < 4:
		return false
	var to_character: Transform3D = _model.global_transform.affine_inverse()
	var sources: Array[MeshInstance3D] = []
	# 7º argumento: um .glb já no espaço do personagem (peça sob medida): usa ele em vez do item vestido.
	var file_root: Node3D = null
	if _args.size() > 6:
		file_root = (load(_args[6]) as PackedScene).instantiate() as Node3D
		get_root().add_child(file_root)
		file_root.global_transform = _model.global_transform
		for node: Node in file_root.find_children("*", "MeshInstance3D", true, false):
			sources.append(node as MeshInstance3D)
	else:
		var attachment: Node = _model.find_child("ChestMount", true, false)
		for node: Node in attachment.find_children("*", "MeshInstance3D", true, false):
			sources.append(node as MeshInstance3D)
	# Altura de cima e de baixo (espaço do personagem).
	var top: float = -INF
	var bottom: float = INF
	for source: MeshInstance3D in sources:
		var xf: Transform3D = to_character * source.global_transform
		for v: Vector3 in source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = xf * v
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
	var target: float = float(_args[3])
	if target <= 0.0:
		target = bottom
	var pivot: float = top - float(_args[4]) * (top - bottom)
	var k: float = (pivot - target) / (pivot - bottom)
	# Pele do corpo em repouso (espaço do personagem): pontos e normais, para empurrar o casaco para fora.
	var body: MeshInstance3D = _model.get_node(_model.body_path) as MeshInstance3D
	var body_mesh: Mesh = body.mesh
	var bxf: Transform3D = to_character * body.global_transform
	var skin_points: PackedVector3Array = PackedVector3Array()
	var skin_normals: PackedVector3Array = PackedVector3Array()
	for s: int in range(body_mesh.get_surface_count()):
		var barr: Array = body_mesh.surface_get_arrays(s)
		var bv: PackedVector3Array = barr[Mesh.ARRAY_VERTEX]
		var bn: PackedVector3Array = barr[Mesh.ARRAY_NORMAL]
		for i: int in range(bv.size()):
			skin_points.append(bxf * bv[i])
			skin_normals.append((bxf.basis * bn[i]).normalized())
	var margin: float = float(_args[5]) if _args.size() > 5 else 0.02
	var pushed: int = 0
	print("top %.3f bottom %.3f pivot %.3f → bottom %.3f (×%.3f abaixo do pivô)" % [top, bottom, pivot, target, k])
	var root: Node3D = Node3D.new()
	root.name = _args[0]
	for source: MeshInstance3D in sources:
		var xf: Transform3D = to_character * source.global_transform
		var mesh: ArrayMesh = ArrayMesh.new()
		for s: int in range(source.mesh.get_surface_count()):
			var arrays: Array = source.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i: int in range(verts.size()):
				var p: Vector3 = xf * verts[i]
				if p.y < pivot:
					p.y = pivot - (pivot - p.y) * k
				# Ponto da pele mais perto: se o casaco está dentro dela (ou a menos de `margin`), empurra para fora.
				var best: int = -1
				var best_d: float = INF
				for j: int in range(skin_points.size()):
					var dd: float = p.distance_squared_to(skin_points[j])
					if dd < best_d:
						best_d = dd
						best = j
				if best >= 0 and best_d < 0.15 * 0.15:
					var depth: float = (p - skin_points[best]).dot(skin_normals[best])
					if depth < margin:
						p += skin_normals[best] * (margin - depth)
						pushed += 1
				verts[i] = p
				if normals.size() > i:
					normals[i] = (xf.basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = verts
			if normals.size() > 0:
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(s, source.get_active_material(s))
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.name = source.name
		copy.mesh = mesh
		root.add_child(copy)
	print("empurrados para fora da pele: %d vértices" % pushed)
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, _args[2])
	print("gravado %s (erro %d)" % [_args[2], error])
	root.free()
	return true
