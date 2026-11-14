class_name Zone1Scenery
extends Node3D
## Cenário da zona 1 ([MUN-03]):
## - o mapa feito no Blender ([ART-10], `workspace-blender/spawn.blend` → `assets/zones/zone_1/zone_1.glb`): chão,
##   praça, montanhas e o que o dono puser na coleção `Terreno`. Refazer: `python3 tools/blender/export_zone.py`.
##   As cores vêm por vértice; todas as malhas usam o material low poly de [LowPolyShapes];
## - campo florido por código por cima (flores e grama em MultiMesh, divididos em blocos para a câmera só desenhar os
##   perto), na altura de [ZoneTerrain], fora da praça.
## Só visual. Semente fixa ([constant SEED]): sai igual em todo aparelho.

## Mapa exportado do Blender.
const MAP_SCENE: PackedScene = preload("res://assets/zones/zone_1/zone_1.glb")
const SEED: int = 1
## Flores e tufos de grama no campo todo, e o lado (m) de cada bloco de MultiMesh.
const FLOWER_COUNT: int = 14000
const GRASS_COUNT: int = 9000
const CHUNK_SIZE: float = 40.0
## Sem flores neste quadrado em volta do centro (m, metade do lado): a praça de 20 × 20 m com as escadas.
const PLAZA_KEEP_OUT: float = 12.1
## Cores das pétalas.
const PETAL_COLORS: Array[Color] = [
	Color(0.98, 0.95, 0.97), Color(1.0, 0.85, 0.25), Color(0.95, 0.45, 0.6), Color(0.65, 0.5, 0.95),
	Color(1.0, 0.6, 0.3), Color(0.55, 0.75, 1.0),
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	ZoneTerrain.preload_heights()
	_add_map()
	_add_field()


## Malhas do Blender, com o material de cor por vértice (o do .glb é só um marcador).
func _add_map() -> void:
	var map: Node3D = MAP_SCENE.instantiate() as Node3D
	map.name = "Map"
	add_child(map)
	var material: StandardMaterial3D = LowPolyShapes.material()
	for node: Node in map.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material


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
	var keep_out: float = PLAZA_KEEP_OUT
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
		into[chunk].append(Transform3D(basis, Vector3(x, ZoneTerrain.height_at(x, z), z)))
		placed += 1
