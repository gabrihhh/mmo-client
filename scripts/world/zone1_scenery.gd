class_name Zone1Scenery
extends Node3D
## Cenário da zona 1 ([MUN-03]), todo low poly gerado por código ([LowPolyShapes]) sobre a forma de [ZoneTerrain]:
## - praça de pedra no centro: círculo onde os jogadores nascem, piso quadrado de lajotas, escada no meio de cada lado
##   e quatro pilares nos cantos;
## - campo florido em volta (flores e grama em MultiMesh, divididos em blocos para a câmera só desenhar os perto);
## - árvores e pedras espalhadas;
## - montanhas fechando o mapa nas quatro bordas (o servidor limita o movimento em ±150 m).
## Só visual. Semente fixa ([constant SEED]): sai igual em todo aparelho.

const SEED: int = 1
## Chão: metade do lado (m, passa da borda andável para ficar embaixo das montanhas) e tamanho do quadrado da grade.
const GROUND_HALF: float = 210.0
const GROUND_CELL: float = 4.0
## Flores e tufos de grama no campo todo, e o lado (m) de cada bloco de MultiMesh.
const FLOWER_COUNT: int = 14000
const GRASS_COUNT: int = 9000
const CHUNK_SIZE: float = 40.0
## Cores das pétalas.
const PETAL_COLORS: Array[Color] = [
	Color(0.98, 0.95, 0.97), Color(1.0, 0.85, 0.25), Color(0.95, 0.45, 0.6), Color(0.65, 0.5, 0.95),
	Color(1.0, 0.6, 0.3), Color(0.55, 0.75, 1.0),
]
## Pedras da praça.
## Centro (x, z em m) de cada bosque; as árvores caem até [constant GROVE_SPREAD] m dele. O mapa do Menu
## ([ZoneMap]) desenha os bosques daqui.
const GROVES: Array[Vector2] = [
	Vector2(-40, -35), Vector2(45, -50), Vector2(-60, 40), Vector2(55, 45), Vector2(0, -85), Vector2(-95, -10),
	Vector2(95, 5), Vector2(10, 90), Vector2(-85, -90), Vector2(90, -95), Vector2(-100, 95), Vector2(100, 100),
]
const GROVE_SPREAD: float = 12.0
const STONE: Color = Color(0.5, 0.48, 0.45)
const STONE_DARK: Color = Color(0.36, 0.34, 0.32)
const STONE_LIGHT: Color = Color(0.6, 0.57, 0.53)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	_add_ground()
	_add_plaza()
	_add_field()
	_add_trees_and_rocks()
	_add_mountains()


# --- Chão do campo ---

func _add_ground() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells: int = int(GROUND_HALF * 2.0 / GROUND_CELL)
	for i: int in range(cells):
		for j: int in range(cells):
			var x0: float = -GROUND_HALF + i * GROUND_CELL
			var z0: float = -GROUND_HALF + j * GROUND_CELL
			var a: Vector3 = _field_point(x0, z0)
			var b: Vector3 = _field_point(x0 + GROUND_CELL, z0)
			var c: Vector3 = _field_point(x0 + GROUND_CELL, z0 + GROUND_CELL)
			var d: Vector3 = _field_point(x0, z0 + GROUND_CELL)
			LowPolyShapes.triangle(st, a, c, b, _grass_color(a.y))
			LowPolyShapes.triangle(st, a, d, c, _grass_color(c.y))
	add_child(LowPolyShapes.mesh_instance(st))


func _field_point(x: float, z: float) -> Vector3:
	return Vector3(x, ZoneTerrain.field_height(x, z), z)


## Verde do campo, um pouco mais seco no alto da borda.
func _grass_color(height: float) -> Color:
	var base: Color = Color(0.42, 0.68, 0.3).lerp(Color(0.52, 0.76, 0.34), _rng.randf())
	return base.lerp(Color(0.55, 0.6, 0.4), clampf((height - 3.0) / 6.0, 0.0, 1.0))


# --- Praça de pedra ---

func _add_plaza() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = ZoneTerrain.PLAZA_HALF
	var top: float = ZoneTerrain.PLAZA_HEIGHT
	# Paredes do piso (da altura do campo até o topo).
	LowPolyShapes.box(st, Vector3(0.0, top * 0.5 - 0.1, 0.0), Vector3(half, top * 0.5 + 0.1, half), STONE_DARK, STONE)
	# Lajotas: grade de quadrados de 1,25 m com tons variados (fora do círculo).
	var tiles: int = 16
	var tile: float = half * 2.0 / tiles
	for i: int in range(tiles):
		for j: int in range(tiles):
			var x0: float = -half + i * tile
			var z0: float = -half + j * tile
			var center: Vector2 = Vector2(x0 + tile * 0.5, z0 + tile * 0.5)
			if center.length() < ZoneTerrain.SPAWN_CIRCLE_RADIUS + 0.3:
				continue
			var y: float = top + 0.01
			var gap: float = 0.04
			var shade: Color = STONE.lerp(STONE_LIGHT, _rng.randf() * 0.7).darkened(_rng.randf() * 0.08)
			LowPolyShapes.quad(st, Vector3(x0 + gap, y, z0 + gap), Vector3(x0 + gap, y, z0 + tile - gap),
				Vector3(x0 + tile - gap, y, z0 + tile - gap), Vector3(x0 + tile - gap, y, z0 + gap), shade)
	# Círculo onde se nasce: anel de pedras escuras e o miolo claro, um pouco acima do piso.
	var segments: int = 28
	var radius: float = ZoneTerrain.SPAWN_CIRCLE_RADIUS
	for k: int in range(segments):
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		var y_ring: float = top + 0.05
		var outer0: Vector3 = Vector3(cos(a0) * radius, y_ring, sin(a0) * radius)
		var outer1: Vector3 = Vector3(cos(a1) * radius, y_ring, sin(a1) * radius)
		var inner0: Vector3 = Vector3(cos(a0) * (radius - 0.55), y_ring, sin(a0) * (radius - 0.55))
		var inner1: Vector3 = Vector3(cos(a1) * (radius - 0.55), y_ring, sin(a1) * (radius - 0.55))
		var ring_color: Color = STONE_DARK.darkened(0.1) if k % 2 == 0 else STONE_DARK
		LowPolyShapes.quad(st, outer0, inner0, inner1, outer1, ring_color)
	LowPolyShapes.disc(st, Vector3(0.0, top + 0.04, 0.0), radius - 0.5, segments, Color(0.66, 0.63, 0.58))
	# Símbolo no meio: uma estrela de quatro pontas em pedra mais escura.
	var y_star: float = top + 0.06
	for k: int in range(4):
		var angle: float = TAU * k / 4.0
		var tip: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (radius - 1.0)
		var side: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * 0.35
		LowPolyShapes.triangle(st, Vector3(0.0, y_star, 0.0) + side, Vector3(0.0, y_star, 0.0) + tip, Vector3(0.0, y_star, 0.0) - side, Color(0.42, 0.4, 0.37))
	# Escadas: três degraus no meio de cada lado.
	for side_index: int in range(4):
		var yaw: float = PI * 0.5 * side_index
		var out: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
		var across: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
		for step: int in range(ZoneTerrain.STEP_COUNT):
			var step_top: float = top - ZoneTerrain.STEP_RISE * (step + 1)
			var distance: float = half + ZoneTerrain.STEP_RUN * (step + 0.5)
			var center: Vector3 = out * distance + Vector3.UP * (step_top * 0.5 - 0.1)
			var extent: Vector3 = (out.abs() * ZoneTerrain.STEP_RUN * 0.5 + across.abs() * ZoneTerrain.STAIR_HALF_WIDTH) + Vector3.UP * (step_top * 0.5 + 0.1)
			LowPolyShapes.box(st, center, extent, STONE_DARK, STONE_LIGHT if step % 2 == 0 else STONE)
	# Pilares nos quatro cantos.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner: Vector3 = Vector3(sx * (half - 0.6), top, sz * (half - 0.6))
			LowPolyShapes.box(st, corner + Vector3.UP * 0.15, Vector3(0.55, 0.15, 0.55), STONE_DARK)
			LowPolyShapes.box(st, corner + Vector3.UP * 1.3, Vector3(0.35, 1.0, 0.35), STONE, STONE_LIGHT)
			LowPolyShapes.box(st, corner + Vector3.UP * 2.4, Vector3(0.48, 0.1, 0.48), STONE_LIGHT)
	var plaza: MeshInstance3D = LowPolyShapes.mesh_instance(st)
	plaza.name = "Plaza"
	add_child(plaza)


# --- Campo florido ---

func _add_field() -> void:
	var blossom: ArrayMesh = LowPolyShapes.blossom_mesh()
	var stem: ArrayMesh = LowPolyShapes.stem_mesh()
	var tuft: ArrayMesh = LowPolyShapes.tuft_mesh()
	# Pontos agrupados por bloco (para a câmera não desenhar o campo inteiro de uma vez).
	var flowers: Dictionary[Vector2i, Array] = {}
	var grass: Dictionary[Vector2i, Array] = {}
	_scatter(flowers, FLOWER_COUNT, true)
	_scatter(grass, GRASS_COUNT, false)
	for chunk: Vector2i in flowers:
		var points: Array = flowers[chunk]
		var stems: MultiMesh = LowPolyShapes.multimesh(stem, points.size(), false)
		var heads: MultiMesh = LowPolyShapes.multimesh(blossom, points.size(), true)
		for i: int in range(points.size()):
			var at: Transform3D = points[i]
			stems.set_instance_transform(i, at)
			heads.set_instance_transform(i, at.translated_local(Vector3.UP * 0.3))
			heads.set_instance_color(i, PETAL_COLORS[_rng.randi() % PETAL_COLORS.size()])
		add_child(LowPolyShapes.multimesh_instance(stems))
		add_child(LowPolyShapes.multimesh_instance(heads))
	for chunk: Vector2i in grass:
		var points: Array = grass[chunk]
		var tufts: MultiMesh = LowPolyShapes.multimesh(tuft, points.size(), false)
		for i: int in range(points.size()):
			tufts.set_instance_transform(i, points[i])
		add_child(LowPolyShapes.multimesh_instance(tufts))


## Sorteia [param count] posições no campo (fora da praça e antes da borda), mais densas em "manchas" de flores, e
## guarda em [param into] por bloco de [constant CHUNK_SIZE].
func _scatter(into: Dictionary[Vector2i, Array], count: int, patchy: bool) -> void:
	var limit: float = ZoneTerrain.WALK_HALF - 4.0
	var keep_out: float = ZoneTerrain.PLAZA_HALF + ZoneTerrain.STEP_COUNT * ZoneTerrain.STEP_RUN + 0.6
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 6:
		tries += 1
		var x: float = _rng.randf_range(-limit, limit)
		var z: float = _rng.randf_range(-limit, limit)
		if absf(x) < keep_out and absf(z) < keep_out:
			continue
		# Manchas: mais flores onde o "ruído" é alto (campo com canteiros, não uniforme).
		if patchy and _rng.randf() > 0.25 + 0.75 * clampf(sin(x * 0.12) * cos(z * 0.1) + 0.3, 0.0, 1.0):
			continue
		var scale_factor: float = _rng.randf_range(0.75, 1.35)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		var chunk: Vector2i = Vector2i(floori(x / CHUNK_SIZE), floori(z / CHUNK_SIZE))
		if not into.has(chunk):
			into[chunk] = []
		into[chunk].append(Transform3D(basis, Vector3(x, ZoneTerrain.field_height(x, z), z)))
		placed += 1


# --- Árvores, pedras e montanhas ---

func _add_trees_and_rocks() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Bosques: alguns centros, árvores em volta de cada um.
	for grove: Vector2 in GROVES:
		for k: int in range(_rng.randi_range(5, 9)):
			var at: Vector2 = grove + Vector2(_rng.randf_range(-GROVE_SPREAD, GROVE_SPREAD), _rng.randf_range(-GROVE_SPREAD, GROVE_SPREAD))
			_tree(st, Vector3(at.x, ZoneTerrain.field_height(at.x, at.y), at.y), _rng.randf_range(0.8, 1.4))
	# Pedras soltas pelo campo.
	for k: int in range(70):
		var x: float = _rng.randf_range(-135.0, 135.0)
		var z: float = _rng.randf_range(-135.0, 135.0)
		if Vector2(x, z).length() < 20.0:
			continue
		var size: float = _rng.randf_range(0.3, 1.1)
		LowPolyShapes.cone(st, _rng, Vector3(x, ZoneTerrain.field_height(x, z) - 0.1, z), size, size * 0.8, 5, Color(0.55, 0.55, 0.53), 0.3)
	add_child(LowPolyShapes.mesh_instance(st))


## Árvore: tronco e copa em dois cones.
func _tree(st: SurfaceTool, at: Vector3, size: float) -> void:
	LowPolyShapes.cone(st, _rng, at, 0.2 * size, 1.4 * size, 6, Color(0.42, 0.28, 0.16), 0.0)
	LowPolyShapes.cone(st, _rng, at + Vector3.UP * 1.0 * size, 1.5 * size, 2.7 * size, 7, Color(0.24, 0.5, 0.25), 0.15)
	LowPolyShapes.cone(st, _rng, at + Vector3.UP * 2.2 * size, 1.1 * size, 2.1 * size, 7, Color(0.28, 0.56, 0.28), 0.15)


## Cordilheira nas quatro bordas, logo depois do limite andável: fileira da frente esverdeada, a de trás mais alta,
## azulada e com neve.
func _add_mountains() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: float = ZoneTerrain.WALK_HALF
	for side_index: int in range(4):
		var yaw: float = PI * 0.5 * side_index
		var out: Vector2 = Vector2(sin(yaw), cos(yaw))
		var across: Vector2 = Vector2(cos(yaw), -sin(yaw))
		for row: int in range(2):
			var count: int = 10 if row == 0 else 8
			for k: int in range(count):
				var t: float = lerpf(-edge - 40.0, edge + 40.0, (k + _rng.randf_range(0.0, 0.7)) / count)
				var distance: float = edge + (18.0 if row == 0 else 45.0) + _rng.randf_range(-5.0, 8.0)
				var at: Vector2 = out * distance + across * t
				var height: float = _rng.randf_range(22.0, 38.0) if row == 0 else _rng.randf_range(45.0, 75.0)
				var radius: float = height * _rng.randf_range(0.8, 1.1)
				var color: Color = Color(0.34, 0.5, 0.33) if row == 0 else Color(0.46, 0.51, 0.62)
				var base: Vector3 = Vector3(at.x, ZoneTerrain.EDGE_RISE - 2.0, at.y)
				LowPolyShapes.cone(st, _rng, base, radius, height, 7, color, 0.18)
				if height > 50.0:
					var cap: float = height * 0.28
					LowPolyShapes.cone(st, _rng, base + Vector3.UP * (height - cap), radius * 0.28, cap, 7, Color(0.95, 0.96, 0.98), 0.05)
	add_child(LowPolyShapes.mesh_instance(st))
