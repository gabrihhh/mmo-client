class_name ItemModels
extends RefCounted
## Liga cada item ao modelo 3D que aparece no boneco quando ele está vestido ([ART-02]) e ao jeito de segurar.
##
## Item sem modelo aqui simplesmente não aparece (ex.: colete e bota, que ainda não têm placeholder).
## Modelo novo: gere o .glb ([ART-02]) e adicione a linha itemId → caminho.
## ATENÇÃO: os itemIds vêm de mmo-server/src/items/catalog.ts.

## itemId → cena do modelo (.glb importado).
const _PATHS: Dictionary[String, String] = {
	"training_sword": "res://assets/placeholders/sword.glb",
	"training_staff": "res://assets/placeholders/staff.glb",
	"training_hood": "res://assets/placeholders/cap.glb",
}

## Como a mão segura (giro em X, graus, a partir do osso da mão). Os modelos de segurar têm o comprimento em +Y:
## 90 = "lâmina para a frente" (espada: com o braço caído aponta para a frente); 0 = em pé (cajado).
const _GRIP_PITCH: Dictionary[String, float] = {
	"training_staff": 0.0,
}
## Pegada padrão (armas de lâmina).
const DEFAULT_GRIP_PITCH: float = 90.0


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
