class_name ItemIcons
extends RefCounted
## Imagens (pixel art 48×48) dos itens e das habilidades: inventário, ficha do item e cartas da HUD ([CLI-10]).
##
## Arquivos por id: `assets/icons/items/<itemId>.png` e `assets/icons/abilities/<abilityId>.png`. Feitas no Meshy
## (texto → imagem) e convertidas em pixel art por `tools/icons/pixelate.py` ([MESHY-07]). Sem arquivo = null
## (o slot/carta desenha só a moldura e o nome). Desenhar sempre com filtro NEAREST (pixels nítidos).
## ATENÇÃO: os ids vêm de mmo-server/src/items/catalog.ts.

## Pasta dos ícones de item.
const ITEMS_DIR: String = "res://assets/icons/items/"
## Pasta dos ícones de habilidade.
const ABILITIES_DIR: String = "res://assets/icons/abilities/"

## Cor da moldura por conjunto (campo `set` do item): reconhece o conjunto de relance.
const SET_COLORS: Dictionary[String, Color] = {
	"Treino": Color(0.72, 0.52, 0.3),
	"Mago": Color(0.62, 0.45, 1.0),
	"Cavaleiro": Color(0.5, 0.72, 1.0),
	"Atirador": Color(0.45, 0.8, 0.4),
	"Assassino": Color(0.75, 0.3, 0.85),
	"Curandeiro": Color(1.0, 0.85, 0.4),
}
## Moldura de item de conjunto desconhecido.
const DEFAULT_SET_COLOR: Color = Color(0.8, 0.7, 0.5)

## Já carregados (id → textura; null = não existe), para não procurar o arquivo de novo a cada redesenho.
static var _cache: Dictionary[String, Texture2D] = {}


## Ícone do item [param item_id], ou null.
static func item(item_id: String) -> Texture2D:
	return _load(ITEMS_DIR + item_id + ".png")


## Ícone da habilidade [param ability_id], ou null.
static func ability(ability_id: String) -> Texture2D:
	return _load(ABILITIES_DIR + ability_id + ".png")


## Cor da moldura do conjunto [param set_name].
static func set_color(set_name: String) -> Color:
	return SET_COLORS.get(set_name, DEFAULT_SET_COLOR)


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[path] = texture
	return texture
