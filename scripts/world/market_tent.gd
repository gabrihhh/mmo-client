class_name MarketTent
extends Node3D
## O **Mercador** no mundo ([JOGO-25]): uma tenda listrada com uma mesa cheia de pilhas de moedas e um baú aberto
## brilhando, no lugar do NPC `market` do servidor, com "Mercador" em cima. Feita por código (caixas, cilindros e um
## cone low poly, sem luz de verdade: leve no celular). Não anda, não é alvo; perto dela a HUD mostra "🪙 Mercado".

## Giro em Y (graus), quase de frente para a câmera isométrica ([CLI-02]).
const FACING_DEGREES: float = -35.0
## Lado (m) da base da tenda e altura dos postes / do topo do telhado.
const SIZE_M: float = 2.6
const POLE_HEIGHT_M: float = 2.0
const ROOF_HEIGHT_M: float = 1.1
const CLOTH_A: Color = Color(0.72, 0.16, 0.14)
const CLOTH_B: Color = Color(0.95, 0.85, 0.55)
const WOOD: Color = Color(0.45, 0.28, 0.14)
const GOLD: Color = Color(1.0, 0.8, 0.25)
const GOLD_DARK: Color = Color(0.85, 0.6, 0.12)


## Põe a tenda no lugar de [param state] (o NPC do servidor), no chão da zona.
func setup(state: PlayerState) -> void:
	name = "Market_%s" % state.id
	position = Vector3(state.x, ZoneTerrain.height_at(state.x, state.z), state.z)
	rotation_degrees.y = FACING_DEGREES
	var label: Label3D = Label3D.new()
	label.text = state.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0065
	label.font_size = 40
	label.outline_size = 10
	label.position = Vector3(0.0, POLE_HEIGHT_M + ROOF_HEIGHT_M + 0.35, 0.0)
	label.modulate = Color(1.0, 0.85, 0.45)
	add_child(label)


func _ready() -> void:
	var half: float = SIZE_M / 2.0
	# Postes nos cantos.
	for x: float in [-half, half]:
		for z: float in [-half, half]:
			add_child(_box(Vector3(0.1, POLE_HEIGHT_M, 0.1), Vector3(x, POLE_HEIGHT_M / 2.0, z), WOOD))
	# Telhado: pirâmide de 4 lados (cone de 4 segmentos) em listras: duas camadas de cor.
	var roof: MeshInstance3D = _cone(SIZE_M * 0.78, ROOF_HEIGHT_M, CLOTH_A)
	roof.position = Vector3(0.0, POLE_HEIGHT_M + ROOF_HEIGHT_M / 2.0, 0.0)
	roof.rotation_degrees.y = 45.0
	add_child(roof)
	var band: MeshInstance3D = _box(Vector3(SIZE_M + 0.08, 0.22, SIZE_M + 0.08), Vector3(0.0, POLE_HEIGHT_M - 0.05, 0.0), CLOTH_B)
	add_child(band)
	# Mesa com as pilhas de moedas.
	add_child(_box(Vector3(1.8, 0.08, 0.8), Vector3(0.0, 0.8, 0.35), WOOD))
	for leg: Vector2 in [Vector2(-0.8, 0.05), Vector2(0.8, 0.05), Vector2(-0.8, 0.65), Vector2(0.8, 0.65)]:
		add_child(_box(Vector3(0.08, 0.8, 0.08), Vector3(leg.x, 0.4, leg.y), WOOD))
	var piles: Array[Vector3] = [Vector3(-0.6, 0, 0.3), Vector3(-0.25, 0, 0.5), Vector3(0.15, 0, 0.25), Vector3(0.5, 0, 0.45), Vector3(0.0, 0, 0.6)]
	for i: int in range(piles.size()):
		var height: float = 0.08 + 0.05 * float(i % 3)
		add_child(_cylinder(0.11, height, Vector3(piles[i].x, 0.84 + height / 2.0, piles[i].z), GOLD))
	# Monte de ouro no chão e um baú aberto atrás.
	var mound: MeshInstance3D = _cone(0.55, 0.35, GOLD_DARK)
	mound.position = Vector3(-0.7, 0.18, -0.6)
	add_child(mound)
	add_child(_box(Vector3(0.8, 0.45, 0.5), Vector3(0.55, 0.23, -0.65), WOOD))
	add_child(_box(Vector3(0.7, 0.06, 0.42), Vector3(0.55, 0.47, -0.65), GOLD, true))


func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(size: Vector3, at: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, unshaded)
	instance.position = at
	return instance


func _cylinder(radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	instance.position = at
	return instance


## Cone low poly (4 lados = pirâmide) de raio [param radius] na base.
func _cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 4
	mesh.rings = 1
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	return instance
