class_name ItemModels
extends RefCounted
## Liga cada item ao modelo 3D que aparece no boneco quando ele está vestido ([ART-02]) e ao jeito de segurar.
##
## Item sem modelo aqui simplesmente não aparece (ex.: colete e bota, que ainda não têm placeholder).
## Modelo novo: gere o .glb ([ART-02]) e adicione a linha itemId → caminho.
## ATENÇÃO: os itemIds vêm de mmo-server/src/items/catalog.ts.

## itemId → cena do modelo (.glb importado).
const _PATHS: Dictionary[String, String] = {
	"training_sword": "res://assets/items/sword/curved_sword.tscn",
	"training_staff": "res://assets/placeholders/staff.glb",
	"training_hood": "res://assets/items/hood/cloth_hood.tscn",
}

## Como a mão segura (giro em X, graus, a partir do osso da mão). Os modelos de segurar têm o comprimento em +Y:
## 90 = "lâmina para a frente" (espada: com o braço caído aponta para a frente); 0 = em pé (cajado).
const _GRIP_PITCH: Dictionary[String, float] = {
	"training_staff": 0.0,
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
}
## Postura parada por arma na mão ([CharacterAnimator.set_idle_animation]); sem linha = "idle".
const _IDLE: Dictionary[String, String] = {
	"training_sword": "idle_sword",
	"training_staff": "idle_staff",
}
## Armas de duas mãos: onde a mão esquerda segura (m, no espaço do modelo do item: comprimento em +Y, origem na mão
## direita). A mão esquerda vai até lá por IK ([EquipmentView]).
const _OFF_HAND_GRIP: Dictionary[String, Vector3] = {
	"training_sword": Vector3(0.0, -0.11, 0.0),
}


## Cria o modelo do item [param item_id], ou null se ele não tiver modelo.
static func instantiate(item_id: String) -> Node3D:
	if not _PATHS.has(item_id):
		return null
	var scene: PackedScene = load(_PATHS[item_id]) as PackedScene
	if scene == null:
		push_warning("Modelo do item %s não carregou: %s" % [item_id, _PATHS[item_id]])
		return null
	return scene.instantiate() as Node3D


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


## true se [param item_id] é segurado com as duas mãos ([method off_hand_grip]).
static func is_two_handed(item_id: String) -> bool:
	return _OFF_HAND_GRIP.has(item_id)


## true se, durante uma ação, o item [param item_id] segue a direção do antebraço (e não a de descanso).
static func follows_forearm_in_action(item_id: String) -> bool:
	return _HOLD.has(item_id) and bool(_HOLD[item_id][3])


## Ponto do item [param item_id] onde a mão esquerda segura (espaço do modelo do item, m).
static func off_hand_grip(item_id: String) -> Vector3:
	return _OFF_HAND_GRIP.get(item_id, Vector3.ZERO)
