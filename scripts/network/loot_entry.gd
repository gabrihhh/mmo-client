class_name LootEntry
extends RefCounted
## Uma coisa do seu baú ([JOGO-19]): um item (com a ficha completa: nome, classe, nível, atributos) ou moedas.
## ATENÇÃO: LootView em mmo-server/src/net/protocol.ts.

var loot_id: String = ""
## Item do baú; null = moedas.
var item: InventoryState.Item = null
## Moedas (só quando [member item] é null).
var gold: int = 0


## Lê do dicionário do `chest_loot`; null se estiver fora do formato.
static func from_dict(data: Dictionary) -> LootEntry:
	var entry: LootEntry = LootEntry.new()
	entry.loot_id = Protocol.read_string(data, "lootId")
	if entry.loot_id.is_empty():
		return null
	match Protocol.read_string(data, "kind"):
		"gold":
			entry.gold = Protocol.read_int(data, "amount")
		"item":
			entry.item = InventoryState.Item.from_dict(Protocol.read_dict(data, "item"))
			if entry.item == null:
				return null
		_:
			return null
	return entry
