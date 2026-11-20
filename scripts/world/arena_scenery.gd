class_name ArenaScenery
extends Node3D
## Cenário placeholder da arena do Coliseu ([JOGO-28]), montado por código (low poly, [LowPolyShapes]):
## - chão de pedra redondo do raio da arena ([member Network.arena_radius], 20 m) com anéis de pedra mais clara;
## - muro de blocos em volta (o servidor e a predição prendem os jogadores dentro, [method Movement.constrain_arena]);
## - **barreira do meio** (plano translúcido em x = 0), visível só na preparação e nas pausas, quando prende cada time
##   no seu lado ([method ColosseumData.MatchState.barrier_active]);
## - marcas no chão do lado de cada time (azul = time 0 em x < 0, vermelho = time 1 em x > 0).
## Chão plano: liga [member ZoneTerrain.flat] (os personagens e efeitos ficam na altura 0).

## Raio usado se o welcome não trouxe (m).
const DEFAULT_RADIUS: float = 20.0
## Lados dos círculos (low poly).
const SEGMENTS: int = 48
## Muro: altura, espessura e blocos (m).
const WALL_HEIGHT: float = 2.2
const WALL_THICKNESS: float = 0.8
const WALL_BLOCKS: int = 40
## Barreira: altura (m).
const BARRIER_HEIGHT: float = 3.0
const STONE: Color = Color(0.56, 0.54, 0.5)
const STONE_LIGHT: Color = Color(0.68, 0.66, 0.6)
const STONE_DARK: Color = Color(0.4, 0.38, 0.35)
const OUTSIDE: Color = Color(0.3, 0.36, 0.26)
const TEAM_COLORS: Array[Color] = [Color(0.3, 0.5, 0.95), Color(0.95, 0.35, 0.3)]

var _barrier: MeshInstance3D = null


func _ready() -> void:
	ZoneTerrain.flat = true
	var radius: float = DEFAULT_RADIUS
	if Network.instance != null and Network.instance.arena_radius > 0.0:
		radius = Network.instance.arena_radius
	_add_floor(radius)
	_add_wall(radius)
	_add_barrier(radius)
	if Network.instance != null:
		Network.instance.colosseum_state_changed.connect(_on_state)
		_on_state(Network.instance.colosseum_state)


## Chão: grama escura fora, pedra dentro, anéis e as marcas dos dois lados.
func _add_floor(radius: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyShapes.disc(st, Vector3(0.0, -0.02, 0.0), radius + 30.0, SEGMENTS, OUTSIDE)
	LowPolyShapes.disc(st, Vector3(0.0, 0.0, 0.0), radius + WALL_THICKNESS, SEGMENTS, STONE_DARK)
	LowPolyShapes.disc(st, Vector3(0.0, 0.005, 0.0), radius, SEGMENTS, STONE)
	LowPolyShapes.disc(st, Vector3(0.0, 0.01, 0.0), radius * 0.66, SEGMENTS, STONE_LIGHT)
	LowPolyShapes.disc(st, Vector3(0.0, 0.015, 0.0), radius * 0.6, SEGMENTS, STONE)
	LowPolyShapes.disc(st, Vector3(0.0, 0.02, 0.0), 2.0, SEGMENTS / 2, STONE_LIGHT)
	# Marca do lado de cada time, onde nascem (60% do raio, como no servidor).
	for team: int in range(2):
		var side: float = -1.0 if team == 0 else 1.0
		LowPolyShapes.disc(st, Vector3(side * radius * 0.6, 0.025, 0.0), 3.5, SEGMENTS / 2, TEAM_COLORS[team].darkened(0.3))
	# Linha do meio.
	LowPolyShapes.box(st, Vector3(0.0, 0.03, 0.0), Vector3(0.12, 0.01, radius), STONE_DARK)
	_add_mesh(st, "Floor")


## Muro de blocos em volta (com folga entre eles para não ficar liso).
func _add_wall(radius: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var block_length: float = TAU * (radius + WALL_THICKNESS * 0.5) / WALL_BLOCKS
	for k: int in range(WALL_BLOCKS):
		var angle: float = TAU * k / WALL_BLOCKS
		var center: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (radius + WALL_THICKNESS * 0.5)
		var height: float = WALL_HEIGHT * (0.9 + 0.2 * float((k * 7) % 3) / 2.0)
		var color: Color = STONE_DARK if k % 2 == 0 else STONE
		var block: SurfaceTool = SurfaceTool.new()
		block.begin(Mesh.PRIMITIVE_TRIANGLES)
		LowPolyShapes.box(block, Vector3(0.0, height * 0.5, 0.0), Vector3(WALL_THICKNESS * 0.5, height * 0.5, block_length * 0.47), color, STONE_LIGHT)
		var transform: Transform3D = Transform3D(Basis(Vector3.UP, -angle), center)
		st.append_from(block.commit(), 0, transform)
	_add_mesh(st, "Wall")


## Barreira do meio: plano translúcido em x = 0 (some no round).
func _add_barrier(radius: float) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.12, BARRIER_HEIGHT, radius * 2.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.55, 0.85, 1.0, 0.35)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	_barrier = MeshInstance3D.new()
	_barrier.name = "Barrier"
	_barrier.mesh = mesh
	_barrier.position = Vector3(0.0, BARRIER_HEIGHT * 0.5, 0.0)
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_barrier)


## Placar novo: a barreira aparece fora do round.
func _on_state(state: ColosseumData.MatchState) -> void:
	if _barrier != null:
		_barrier.visible = state == null or state.barrier_active()


## Malha com o material low poly de cor por vértice.
func _add_mesh(st: SurfaceTool, mesh_name: String) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = st.commit()
	instance.material_override = LowPolyShapes.material()
	add_child(instance)
