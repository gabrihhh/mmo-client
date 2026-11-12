@tool
class_name MonsterSpawn
extends Marker3D
## Um monstro posto no mapa pelo editor do Godot ([MUN-05]): arraste o nó para onde ele deve ficar e escolha o tipo e
## o nível no inspetor. Vive na cena res://scenes/world/zone_1_monsters.tscn ([MonsterSpawns]), que grava a lista no
## servidor ao salvar. O id do monstro sai do nome do nó ("Lutador2" → "zombie_lutador2").
##
## Só existe no editor: o jogo não carrega esta cena (quem decide onde o monstro está é o servidor, [INFRA-09]).
## No editor desenha uma cápsula da cor do tipo, o nome com o nível em cima e o círculo de perseguição no chão.

## Tipo de monstro. ATENÇÃO: a ordem bate com [constant KIND_IDS] e com MONSTER_KINDS em
## mmo-server/src/zones/monsterSpawns.ts.
enum Kind { FIGHTER, SHOOTER }
## Id de cada [enum Kind] no arquivo do servidor.
const KIND_IDS: Array[String] = ["fighter", "shooter"]
## Nome na tela de cada [enum Kind].
const KIND_NAMES: Array[String] = ["Zumbi lutador", "Zumbi atirador"]
## Cor da cápsula de cada [enum Kind] (só no editor).
const KIND_COLORS: Array[Color] = [Color(0.85, 0.25, 0.2), Color(0.95, 0.6, 0.15)]
## Maior nível aceito. ATENÇÃO: = MONSTER_MAX_LEVEL do servidor (nível máximo dos jogadores, [JOGO-12]).
const MAX_LEVEL: int = 50
## Raio (m) em que o zumbi percebe o jogador e vai atrás. ATENÇÃO: = ZOMBIE_AGGRO_RADIUS em mmo-server/src/zones/zones.ts.
const AGGRO_RADIUS: float = 8.0

## Que monstro é (arma e habilidade dele no servidor, [JOGO-13]).
@export var kind: Kind = Kind.FIGHTER:
	set(value):
		kind = value
		_refresh_visual()
## Nível ([JOGO-12]): vida, dano e a XP que dá crescem 1% por nível, acumulando.
@export_range(0, MAX_LEVEL) var level: int = 0:
	set(value):
		level = clampi(value, 0, MAX_LEVEL)
		_refresh_visual()

var _label: Label3D = null
var _body: MeshInstance3D = null
var _ring: MeshInstance3D = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_visual()
	_refresh_visual()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# Fica em cima do chão da prévia (o servidor só usa x e z).
	var ground: float = ZoneTerrain.height_at(position.x, position.z)
	if absf(position.y - ground) > 0.01:
		position.y = ground


## Id no servidor: "zombie_" + o nome do nó em snake_case.
func spawn_id() -> String:
	return "zombie_" + String(name).to_snake_case()


## Linha do arquivo do servidor ({ id, kind, level, x, z }; x/z em m, 1 casa decimal).
func to_dictionary() -> Dictionary[String, Variant]:
	return {
		"id": spawn_id(),
		"kind": KIND_IDS[kind],
		"level": level,
		"x": snappedf(position.x, 0.1),
		"z": snappedf(position.z, 0.1),
	}


func _build_visual() -> void:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.position.y = 0.9
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = AGGRO_RADIUS - 0.12
	ring_mesh.outer_radius = AGGRO_RADIUS
	ring_mesh.rings = 48
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.position.y = 0.15
	add_child(_ring, false, Node.INTERNAL_MODE_FRONT)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 64
	_label.outline_size = 12
	_label.position.y = 2.4
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)


func _refresh_visual() -> void:
	if _label == null:
		return
	_label.text = "%s\nnível %d" % [KIND_NAMES[kind], level]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = KIND_COLORS[kind]
	_body.material_override = material
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = KIND_COLORS[kind]
	_ring.material_override = ring_material
