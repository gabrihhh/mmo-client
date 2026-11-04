class_name ItemModels
extends RefCounted
## Liga cada item ao modelo 3D que aparece no boneco quando ele está vestido ([ART-02]) e ao jeito de segurar.
##
## Item sem modelo aqui simplesmente não aparece (ex.: colete e bota de treino, que ainda não têm modelo).
## Modelo novo: gere o .glb ([ART-02], [MESHY-07]), faça a cena com escala/origem e adicione a linha itemId → caminho.
## Itens de peito e pés são peças rígidas presas a ossos ([EquipmentView]); o de pés é um pé só (o direito espelha).
## ATENÇÃO: os itemIds vêm de mmo-server/src/items/catalog.ts.

## itemId → cena do modelo (.glb importado).
const _PATHS: Dictionary[String, String] = {
	"training_sword": "res://assets/items/sword/curved_sword.tscn",
	"training_staff": "res://assets/placeholders/staff.glb",
	"training_hood": "res://assets/items/hood/cloth_hood.tscn",
	"arcane_staff": "res://assets/items/arcane_staff/arcane_staff.tscn",
	"mage_hat": "res://assets/items/mage_hat/mage_hat.tscn",
	"mage_tunic": "res://assets/items/mage_tunic/mage_tunic.tscn",
	"mage_shoes": "res://assets/items/mage_shoes/mage_shoes.tscn",
	"knight_sword": "res://assets/items/knight_sword/knight_sword.tscn",
	"knight_helm": "res://assets/items/knight_helm/knight_helm.tscn",
	"knight_plate": "res://assets/items/knight_plate/knight_plate.tscn",
	"knight_greaves": "res://assets/items/knight_greaves/knight_greaves.tscn",
	"ranger_crossbow": "res://assets/items/ranger_crossbow/ranger_crossbow.tscn",
	"ranger_hood": "res://assets/items/ranger_hood/ranger_hood.tscn",
	"ranger_jerkin": "res://assets/items/ranger_jerkin/ranger_jerkin.tscn",
	"ranger_boots": "res://assets/items/ranger_boots/ranger_boots.tscn",
	"assassin_daggers": "res://assets/items/assassin_daggers/assassin_daggers.tscn",
	"assassin_hood": "res://assets/items/assassin_hood/assassin_hood.tscn",
	"assassin_vest": "res://assets/items/assassin_vest/assassin_vest.tscn",
	"assassin_boots": "res://assets/items/assassin_boots/assassin_boots.tscn",
	"healer_tome": "res://assets/items/healer_tome/healer_tome.tscn",
	"healer_circlet": "res://assets/items/healer_circlet/healer_circlet.tscn",
	"healer_robe": "res://assets/items/healer_robe/healer_robe.tscn",
	"healer_sandals": "res://assets/items/healer_sandals/healer_sandals.tscn",
}

## Como a mão segura (giro em X, graus, a partir do osso da mão). Os modelos de segurar têm o comprimento em +Y:
## 90 = "lâmina para a frente" (espada: com o braço caído aponta para a frente); 0 = em pé (cajado).
const _GRIP_PITCH: Dictionary[String, float] = {
	"training_staff": 0.0,
	"arcane_staff": 0.0,
	"healer_tome": 0.0,
}
## Pegada padrão (armas de lâmina).
const DEFAULT_GRIP_PITCH: float = 90.0
## Como cada item de segurar se acomoda na mão: [direção de descanso (espaço do personagem: +Z frente, +Y cima),
## puxão fora de ação, puxão durante uma ação, durante a ação segue o antebraço?]. Seguindo o antebraço, o puxão da
## ação vai na direção cotovelo → mão (a lâmina continua o braço: sobe na preparação, desce no golpe). A cada quadro o comprimento (+Y) do item é somado a direção × puxão
## (puxão 0 = preso ao osso da mão). As animações do Meshy são de mão vazia: o pulso gira e, preso ao osso, a espada
## apontava para cima e o cajado deitava para trás correndo (ou ficava de ponta-cabeça ao erguer o braço). Puxão > 1
## garante a direção; durante a ação a espada é puxada pouco, para o golpe seguir a mão.
const _HOLD: Dictionary[String, Array] = {
	"training_sword": [Vector3(0.0, 0.55, 1.0), 2.0, 2.0, true],
	"training_staff": [Vector3(0.0, 1.0, 0.3), 4.0, 4.0, false],
	"knight_sword": [Vector3(0.0, 0.55, 1.0), 2.0, 2.0, true],
	"arcane_staff": [Vector3(0.0, 1.0, 0.3), 4.0, 4.0, false],
	"ranger_crossbow": [Vector3(0.0, 0.15, 1.0), 3.0, 3.0, false],
	"healer_tome": [Vector3(0.0, 1.0, 0.2), 4.0, 4.0, false],
}
## Posição de carregar (parado/correndo), no espaço do personagem (m; +Z frente, +Y cima, lado direito = −X):
## [onde fica a pegada da mão direita, direção do comprimento]. As mãos vão até a arma por IK ([EquipmentView]).
## Perto o bastante do ombro para o braço alcançar (~0,45 m do ombro).
const _CARRY: Dictionary[String, Array] = {
	"training_sword": [Vector3(-0.10, 1.10, 0.30), Vector3(0.0, 0.6, 1.0)],
	"training_staff": [Vector3(-0.24, 1.12, 0.26), Vector3(0.0, 1.0, 0.18)],
	"knight_sword": [Vector3(-0.10, 1.10, 0.30), Vector3(0.0, 0.6, 1.0)],
	"arcane_staff": [Vector3(-0.24, 1.12, 0.26), Vector3(0.0, 1.0, 0.18)],
	"ranger_crossbow": [Vector3(-0.12, 1.12, 0.32), Vector3(0.0, 0.1, 1.0)],
	"healer_tome": [Vector3(-0.2, 1.0, 0.24), Vector3(0.0, 1.0, 0.1)],
}
## Postura parada por arma na mão ([CharacterAnimator.set_idle_animation]); sem linha = "idle".
const _IDLE: Dictionary[String, String] = {
	"training_sword": "idle_sword",
	"training_staff": "idle_staff",
	"knight_sword": "idle_sword",
	"arcane_staff": "idle_staff",
}
## Armas de duas mãos: onde a mão esquerda segura (m, no espaço do modelo do item: comprimento em +Y, origem na mão
## direita). A mão esquerda vai até lá por IK ([EquipmentView]).
const _OFF_HAND_GRIP: Dictionary[String, Vector3] = {
	"training_sword": Vector3(0.0, -0.11, 0.0),
	"knight_sword": Vector3(0.0, -0.09, 0.0),
}
## Armas que vêm em PAR (duas adagas): o mesmo modelo também aparece na mão esquerda, espelhado, seguindo a mão
## animada ([EquipmentView]).
const _PAIRED: Array[String] = ["assassin_daggers"]


## Cria o modelo do item [param item_id], ou null se ele não tiver modelo.
static func instantiate(item_id: String) -> Node3D:
	if not _PATHS.has(item_id):
		return null
	var scene: PackedScene = load(_PATHS[item_id]) as PackedScene
	if scene == null:
		push_warning("Modelo do item %s não carregou: %s" % [item_id, _PATHS[item_id]])
		return null
	return scene.instantiate() as Node3D


## Caixa (m) de todas as malhas de [param root], no espaço de [param root] (inclui as transformações dos filhos).
static func local_bounds(root: Node3D) -> AABB:
	return _bounds(root, Transform3D.IDENTITY)


static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	if node is MeshInstance3D:
		result = xform * (node as MeshInstance3D).get_aabb()
		found = true
	for child: Node in node.get_children():
		var child_xform: Transform3D = xform * (child as Node3D).transform if child is Node3D else xform
		var box: AABB = _bounds(child, child_xform)
		if box.size == Vector3.ZERO:
			continue
		result = box if not found else result.merge(box)
		found = true
	return result


## Rotação do item na mão (no espaço do osso da mão).
static func grip(item_id: String) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(_GRIP_PITCH.get(item_id, DEFAULT_GRIP_PITCH)))


## Direção de descanso do item [param item_id] na mão (espaço do personagem, normalizada); zero = sem correção.
static func hold_direction(item_id: String) -> Vector3:
	if not _HOLD.has(item_id):
		return Vector3.ZERO
	var direction: Vector3 = _HOLD[item_id][0]
	return direction.normalized()


## Quanto o item [param item_id] é puxado para a direção de descanso: fora de ação ([param acting] false) ou durante.
static func hold_pull(item_id: String, acting: bool) -> float:
	if not _HOLD.has(item_id):
		return 0.0
	return float(_HOLD[item_id][2 if acting else 1])


## Animação parada do personagem com [param item_id] na mão ("idle" se a arma não tiver postura própria).
static func idle_animation(item_id: String) -> String:
	return _IDLE.get(item_id, "idle")


## true se [param item_id] é um par (uma cópia espelhada vai na mão esquerda).
static func is_paired(item_id: String) -> bool:
	return item_id in _PAIRED


## true se [param item_id] é segurado com as duas mãos ([method off_hand_grip]).
static func is_two_handed(item_id: String) -> bool:
	return _OFF_HAND_GRIP.has(item_id)


## true se, durante uma ação, o item [param item_id] segue a direção do antebraço (e não a de descanso).
static func follows_forearm_in_action(item_id: String) -> bool:
	return _HOLD.has(item_id) and bool(_HOLD[item_id][3])


## Ponto do item [param item_id] onde a mão esquerda segura (espaço do modelo do item, m).
static func off_hand_grip(item_id: String) -> Vector3:
	return _OFF_HAND_GRIP.get(item_id, Vector3.ZERO)


## Posição de carregar de [param item_id] (espaço do personagem): origem = pegada da mão direita, eixo Y = comprimento.
## Transform3D() = o item não tem (segue a mão animada).
static func carry(item_id: String) -> Transform3D:
	if not _CARRY.has(item_id):
		return Transform3D()
	var grip_point: Vector3 = _CARRY[item_id][0]
	var direction: Vector3 = _CARRY[item_id][1]
	var length_axis: Vector3 = direction.normalized()
	var side: Vector3 = Vector3.RIGHT - length_axis * length_axis.x
	return Transform3D(Basis(side.normalized(), length_axis, side.normalized().cross(length_axis)), grip_point)
