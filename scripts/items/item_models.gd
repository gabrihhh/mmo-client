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
## Itens que ficam "em pé" na mão: quanto o comprimento (+Y) é puxado para cima a cada quadro (0 = preso ao osso).
## As animações do Meshy são de mão vazia: ao erguer o braço o pulso gira e o cajado preso ao osso ficava de ponta
## cabeça. Com puxão > 1 a ponta (+Y) fica sempre para cima, mas o cajado ainda balança com o movimento da mão.
const _UPRIGHT_PULL: Dictionary[String, float] = {
	"training_staff": 1.5,
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


## Quanto o item [param item_id] é puxado para ficar em pé na mão (0 = segue o osso da mão sem correção).
static func upright_pull(item_id: String) -> float:
	return _UPRIGHT_PULL.get(item_id, 0.0)
