@tool
class_name MonsterSpawns
extends Node3D
## Editor dos monstros de uma zona ([MUN-05]): raiz da cena res://scenes/world/zone_1_monsters.tscn. Cada filho
## [MonsterSpawn] é um monstro (arraste, escolha tipo e nível no inspetor; Ctrl+D duplica). Ao **salvar a cena**
## (Ctrl+S) ou no botão "Salvar no servidor" do inspetor, grava a lista em [member server_file], o arquivo que o
## servidor lê (mmo-server/src/zones/monsters/zone_1.json). O servidor rodando com `npm start`/`./run.sh` recarrega
## sozinho (quem estiver no jogo cai e reconecta).
##
## A cena é a fonte da verdade: não editar o .json à mão (a próxima gravação sobrescreve).
## No editor monta uma prévia do mapa por baixo (chão de [ZoneTerrain], praça, bosques de [Zone1Scenery]) para saber
## onde se está; ela não é salva na cena. Só editor: o jogo não carrega esta cena.
##
## ATENÇÃO: formato lido por parseMonsterSpawns em mmo-server/src/zones/monsterSpawns.ts.

## Arquivo do servidor, a partir da pasta do projeto (mmo-client).
@export var server_file: String = "../mmo-server/src/zones/monsters/zone_1.json"
## Grava agora (o mesmo que salvar a cena).
@export_tool_button("Salvar no servidor") var save_button: Callable = save_to_server

## Prévia do chão: tamanho da célula (m) e cores.
const PREVIEW_CELL: float = 4.0
const FIELD_COLOR: Color = Color(0.45, 0.68, 0.35)
const HILL_COLOR: Color = Color(0.36, 0.55, 0.3)
const PLAZA_COLOR: Color = Color(0.6, 0.57, 0.53)
const GROVE_COLOR: Color = Color(0.18, 0.4, 0.2)


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		save_to_server()


## Os monstros desta cena (filhos [MonsterSpawn]).
func spawns() -> Array[MonsterSpawn]:
	var result: Array[MonsterSpawn] = []
	for child: Node in get_children():
		if child is MonsterSpawn:
			result.append(child as MonsterSpawn)
	return result


## Grava a lista no arquivo do servidor. Não grava (e acusa no Output) se houver id repetido ou monstro fora do mapa:
## o servidor não subiria com o arquivo errado.
func save_to_server() -> void:
	var list: Array[Dictionary] = []
	var ids: Dictionary[String, bool] = {}
	for spawn: MonsterSpawn in spawns():
		var entry: Dictionary[String, Variant] = spawn.to_dictionary()
		var id: String = entry["id"]
		if ids.has(id):
			push_error("Monstros: id repetido '%s' (renomeie o nó %s). Nada foi gravado." % [id, spawn.name])
			return
		ids[id] = true
		if absf(spawn.position.x) > WorldConstants.ZONE_HALF_SIZE or absf(spawn.position.z) > WorldConstants.ZONE_HALF_SIZE:
			push_error("Monstros: %s está fora do mapa (±%d m). Nada foi gravado." % [spawn.name, int(WorldConstants.ZONE_HALF_SIZE)])
			return
		list.append(entry)
	var path: String = ProjectSettings.globalize_path("res://").path_join(server_file).simplify_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Monstros: não consegui gravar %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(list, "  ", false) + "\n")
	file.close()
	print("Monstros: %d gravados em %s" % [list.size(), path])


## Chão, praça e bosques, só para referência no editor (filhos internos: não vão para o arquivo da cena).
func _build_preview() -> void:
	var half: float = WorldConstants.ZONE_HALF_SIZE
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = int(half * 2.0 / PREVIEW_CELL)
	for i: int in range(steps):
		for j: int in range(steps):
			var x0: float = -half + i * PREVIEW_CELL
			var z0: float = -half + j * PREVIEW_CELL
			var corners: Array[Vector3] = []
			for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var x: float = x0 + c.x * PREVIEW_CELL
				var z: float = z0 + c.y * PREVIEW_CELL
				corners.append(Vector3(x, ZoneTerrain.height_at(x, z), z))
			var cx: float = x0 + PREVIEW_CELL * 0.5
			var cz: float = z0 + PREVIEW_CELL * 0.5
			var color: Color = PLAZA_COLOR if ZoneTerrain.is_plaza(cx, cz) \
				else FIELD_COLOR.lerp(HILL_COLOR, clampf(ZoneTerrain.height_at(cx, cz) / 3.0, 0.0, 1.0))
			st.set_color(color)
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(corners[k])
	st.generate_normals()
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.mesh = st.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = material
	add_child(ground, false, Node.INTERNAL_MODE_FRONT)
	# Círculo onde os jogadores nascem.
	var circle: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = ZoneTerrain.SPAWN_CIRCLE_RADIUS
	disc.bottom_radius = ZoneTerrain.SPAWN_CIRCLE_RADIUS
	disc.height = 0.05
	circle.mesh = disc
	circle.position.y = ZoneTerrain.PLAZA_HEIGHT + 0.03
	var circle_material: StandardMaterial3D = StandardMaterial3D.new()
	circle_material.albedo_color = Color(0.3, 0.3, 0.35)
	circle.material_override = circle_material
	add_child(circle, false, Node.INTERNAL_MODE_FRONT)
	# Bosques (árvores do jogo caem até GROVE_SPREAD m do centro).
	var grove_material: StandardMaterial3D = StandardMaterial3D.new()
	grove_material.albedo_color = GROVE_COLOR
	for center: Vector2 in Zone1Scenery.GROVES:
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = Zone1Scenery.GROVE_SPREAD
		cone.height = 6.0
		var grove: MeshInstance3D = MeshInstance3D.new()
		grove.mesh = cone
		grove.material_override = grove_material
		grove.position = Vector3(center.x, ZoneTerrain.height_at(center.x, center.y) + 3.0, center.y)
		add_child(grove, false, Node.INTERNAL_MODE_FRONT)
