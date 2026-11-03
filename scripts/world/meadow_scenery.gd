class_name MeadowScenery
extends Node3D
## Cenário de fundo da tela de escolha de personagem ([CLI-09]): campo florido, uma casa ao longe e montanhas, tudo
## low poly facetado e gerado por código ([LowPolyShapes], sem assets). Só visual: nada aqui conversa com o servidor.
##
## Coordenadas: os personagens ficam perto da origem olhando para +Z (para a câmera); o fundo fica em −Z.
## A semente fixa ([constant SEED]) faz o cenário sair sempre igual.

## Semente do aleatório (mesma cena toda vez).
const SEED: int = 20261103
## Lado do chão (m), centrado na origem.
const GROUND_SIZE: float = 240.0
## Quadrados do chão por lado (cada um vira 2 triângulos).
const GROUND_CELLS: int = 48
## Flores e tufos de grama espalhados (área perto dos personagens).
const FLOWER_COUNT: int = 4500
const GRASS_COUNT: int = 900
## Área das flores (m): largura em X e de onde até onde em Z.
const FLOWER_HALF_WIDTH: float = 14.0
const FLOWER_Z_RANGE: Vector2 = Vector2(-26.0, 0.8)
## Cores das pétalas.
const PETAL_COLORS: Array[Color] = [
	Color(0.98, 0.95, 0.97), Color(1.0, 0.85, 0.25), Color(0.95, 0.45, 0.6), Color(0.65, 0.5, 0.95),
	Color(1.0, 0.6, 0.3), Color(0.55, 0.75, 1.0),
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	_add_ground()
	_add_flowers()
	_add_house(Vector3(0.4, 0.0, -36.0), deg_to_rad(-25.0))
	_add_tree(Vector3(5.0, 0.0, -40.0), 1.15)
	_add_tree(Vector3(-4.5, 0.0, -42.0), 1.0)
	_add_tree(Vector3(-9.0, 0.0, -48.0), 1.3)
	_add_tree(Vector3(-15.0, 0.0, -36.0), 0.95)
	_add_mountains()


## Altura do chão (m) em (x, z): plano perto dos personagens, ondulando suave mais longe.
func ground_height(x: float, z: float) -> float:
	var far: float = clampf((Vector2(x, z).length() - 12.0) / 40.0, 0.0, 1.0)
	return far * (sin(x * 0.11) * 0.9 + cos(z * 0.07 + x * 0.05) * 1.2 + 0.6)


# --- Chão ---

func _add_ground() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell: float = GROUND_SIZE / GROUND_CELLS
	var half: float = GROUND_SIZE * 0.5
	for i: int in range(GROUND_CELLS):
		for j: int in range(GROUND_CELLS):
			var x0: float = -half + i * cell
			var z0: float = -half + j * cell
			var a: Vector3 = _ground_point(x0, z0)
			var b: Vector3 = _ground_point(x0 + cell, z0)
			var c: Vector3 = _ground_point(x0 + cell, z0 + cell)
			var d: Vector3 = _ground_point(x0, z0 + cell)
			LowPolyShapes.triangle(st, a, c, b, _grass_color())
			LowPolyShapes.triangle(st, a, d, c, _grass_color())
	add_child(LowPolyShapes.mesh_instance(st))


func _ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, ground_height(x, z), z)


func _grass_color() -> Color:
	return Color(0.42, 0.68, 0.3).lerp(Color(0.55, 0.78, 0.35), _rng.randf())


# --- Flores e grama (MultiMesh: um desenho para todas) ---

func _add_flowers() -> void:
	var stems: MultiMesh = LowPolyShapes.multimesh(LowPolyShapes.stem_mesh(), FLOWER_COUNT, false)
	var blossoms: MultiMesh = LowPolyShapes.multimesh(LowPolyShapes.blossom_mesh(), FLOWER_COUNT, true)
	for i: int in range(FLOWER_COUNT):
		var x: float = _rng.randf_range(-FLOWER_HALF_WIDTH, FLOWER_HALF_WIDTH)
		var z: float = _rng.randf_range(FLOWER_Z_RANGE.x, FLOWER_Z_RANGE.y)
		var scale_factor: float = _rng.randf_range(0.7, 1.3)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		var at: Vector3 = Vector3(x, ground_height(x, z), z)
		stems.set_instance_transform(i, Transform3D(basis, at))
		blossoms.set_instance_transform(i, Transform3D(basis, at + Vector3.UP * 0.3 * scale_factor))
		blossoms.set_instance_color(i, PETAL_COLORS[_rng.randi() % PETAL_COLORS.size()])
	add_child(LowPolyShapes.multimesh_instance(stems))
	add_child(LowPolyShapes.multimesh_instance(blossoms))

	var grass: MultiMesh = LowPolyShapes.multimesh(LowPolyShapes.tuft_mesh(), GRASS_COUNT, false)
	for i: int in range(GRASS_COUNT):
		var x: float = _rng.randf_range(-FLOWER_HALF_WIDTH * 1.4, FLOWER_HALF_WIDTH * 1.4)
		var z: float = _rng.randf_range(FLOWER_Z_RANGE.x * 1.3, FLOWER_Z_RANGE.y - 0.3)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4))
		grass.set_instance_transform(i, Transform3D(basis, Vector3(x, ground_height(x, z), z)))
	add_child(LowPolyShapes.multimesh_instance(grass))


# --- Casa, árvores e montanhas ---

## Casinha: paredes claras, telhado de duas águas, porta, janelas e chaminé. [param at] = centro da base.
func _add_house(at: Vector3, yaw: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 3.2
	var d: float = 2.6
	var h: float = 2.4
	var wall: Color = Color(0.93, 0.88, 0.76)
	LowPolyShapes.box(st, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d) * 0.5, wall)
	# Telhado: prisma (duas águas) com beiral.
	var roof: Color = Color(0.72, 0.28, 0.2)
	var eave: float = 0.3
	var top: float = h + 1.5
	var l0: Vector3 = Vector3(-w * 0.5 - eave, h - 0.1, d * 0.5 + eave)
	var r0: Vector3 = Vector3(w * 0.5 + eave, h - 0.1, d * 0.5 + eave)
	var l1: Vector3 = Vector3(-w * 0.5 - eave, h - 0.1, -d * 0.5 - eave)
	var r1: Vector3 = Vector3(w * 0.5 + eave, h - 0.1, -d * 0.5 - eave)
	var ridge0: Vector3 = Vector3(0.0, top, d * 0.5 + eave)
	var ridge1: Vector3 = Vector3(0.0, top, -d * 0.5 - eave)
	LowPolyShapes.quad(st, l0, ridge0, ridge1, l1, roof)
	LowPolyShapes.quad(st, ridge0, r0, r1, ridge1, roof.darkened(0.15))
	# Oitões (triângulos das paredes de frente e de trás).
	LowPolyShapes.triangle(st, Vector3(-w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, d * 0.5), Vector3(0.0, top - 0.1, d * 0.5), wall)
	LowPolyShapes.triangle(st, Vector3(w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, -d * 0.5), Vector3(0.0, top - 0.1, -d * 0.5), wall)
	var wood: Color = Color(0.45, 0.28, 0.15)
	LowPolyShapes.box(st, Vector3(0.0, 0.6, d * 0.5 + 0.02), Vector3(0.38, 0.6, 0.03), wood)
	var glass: Color = Color(0.55, 0.75, 0.9)
	LowPolyShapes.box(st, Vector3(-0.95, 1.35, d * 0.5 + 0.02), Vector3(0.32, 0.28, 0.03), glass)
	LowPolyShapes.box(st, Vector3(0.95, 1.35, d * 0.5 + 0.02), Vector3(0.32, 0.28, 0.03), glass)
	LowPolyShapes.box(st, Vector3(w * 0.5 + 0.02, 1.35, 0.0), Vector3(0.03, 0.28, 0.32), glass)
	LowPolyShapes.box(st, Vector3(0.85, top - 0.4, -0.4), Vector3(0.22, 0.6, 0.22), Color(0.55, 0.5, 0.48))
	var house: MeshInstance3D = LowPolyShapes.mesh_instance(st)
	house.position = at + Vector3.UP * ground_height(at.x, at.z)
	house.rotation.y = yaw
	add_child(house)


## Árvore low poly: tronco e copa em dois cones.
func _add_tree(at: Vector3, size: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyShapes.cone(st, _rng, Vector3.ZERO, 0.18, 1.2, 6, Color(0.42, 0.28, 0.16), 0.0)
	LowPolyShapes.cone(st, _rng, Vector3(0.0, 0.9, 0.0), 1.3, 2.4, 7, Color(0.24, 0.5, 0.25), 0.15)
	LowPolyShapes.cone(st, _rng, Vector3(0.0, 2.0, 0.0), 0.95, 1.9, 7, Color(0.28, 0.56, 0.28), 0.15)
	var tree: MeshInstance3D = LowPolyShapes.mesh_instance(st)
	tree.position = at + Vector3.UP * ground_height(at.x, at.z)
	tree.scale = Vector3.ONE * size
	add_child(tree)


## Cordilheira ao fundo: cones irregulares com neve no topo, em duas fileiras (as de trás mais azuladas).
func _add_mountains() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[Dictionary] = [
		{"z": -200.0, "count": 9, "height": Vector2(45.0, 80.0), "color": Color(0.45, 0.5, 0.62)},
		{"z": -140.0, "count": 8, "height": Vector2(22.0, 40.0), "color": Color(0.33, 0.5, 0.33)},
	]
	for row: Dictionary in rows:
		var count: int = row["count"]
		var heights: Vector2 = row["height"]
		for k: int in range(count):
			var x: float = lerpf(-170.0, 170.0, (k + _rng.randf_range(0.0, 0.6)) / count)
			var height: float = _rng.randf_range(heights.x, heights.y)
			var radius: float = height * _rng.randf_range(0.9, 1.3)
			var base: Vector3 = Vector3(x, -2.0, float(row["z"]) + _rng.randf_range(-12.0, 12.0))
			LowPolyShapes.cone(st, _rng, base, radius, height, 7, row["color"], 0.18)
			# Neve: um cone menor no topo, das montanhas altas.
			if height > 50.0:
				var cap: float = height * 0.28
				LowPolyShapes.cone(st, _rng, base + Vector3.UP * (height - cap), radius * 0.28, cap, 7, Color(0.95, 0.96, 0.98), 0.05)
	add_child(LowPolyShapes.mesh_instance(st))
