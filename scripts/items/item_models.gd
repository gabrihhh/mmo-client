class_name ItemModels
extends RefCounted
## Liga cada item ao modelo 3D que aparece no boneco quando ele está vestido ([ART-02]).
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


## Cria o modelo do item [param item_id], ou null se ele não tiver modelo.
static func instantiate(item_id: String) -> Node3D:
	if not _PATHS.has(item_id):
		return null
	var scene: PackedScene = load(_PATHS[item_id]) as PackedScene
	if scene == null:
		push_warning("Modelo do item %s não carregou: %s" % [item_id, _PATHS[item_id]])
		return null
	return scene.instantiate() as Node3D
