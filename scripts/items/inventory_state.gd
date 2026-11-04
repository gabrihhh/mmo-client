class_name InventoryState
extends RefCounted
## Inventário recebido do servidor (mensagem "inventory"): o que está vestido, a mochila e as
## habilidades de cada item. Só leitura: para trocar, o cliente pede ([method Network.send_equip]) e
## o servidor responde com o inventário novo. Ver mmo-docs [JOGO-04].

## Slots vestidos na ordem da HUD (3 cartas da arma, depois cabeça, peito, pés).
## ATENÇÃO: igual a EQUIP_SLOTS em mmo-server/src/items/catalog.ts.
const SLOTS: Array[String] = ["hand", "head", "chest", "feet"]


## Um item possuído (vestido ou na mochila).
class Item:
	extends RefCounted
	var uid: String = ""
	var item_id: String = ""
	var name: String = ""
	## Frase curta e conjunto ("Treino", "Mago", "Cavaleiro") para a ficha e a cor da moldura ([ItemIcons]).
	var description: String = ""
	var set_name: String = ""
	## Vida máxima extra enquanto vestido ([JOGO-09]).
	var bonus_hp: float = 0.0
	## Perfil do conjunto em baixo/médio/alto: "damage", "health", "healing", "cooldown" → "zero" | "low" |
	## "medium" | "high" ([JOGO-09]). Vazio = sem perfil.
	## ATENÇÃO: espelha SetProfileView em mmo-server/src/net/protocol.ts.
	var profile: Dictionary[String, String] = {}
	## "hand", "head", "chest" ou "feet".
	var slot: String = ""
	## Ataque simples (só armas); null nos outros.
	var basic_attack: AbilityView = null
	var abilities: Array[AbilityView] = []

	static func from_dict(data: Dictionary) -> Item:
		var item: Item = Item.new()
		item.uid = Protocol.read_string(data, "uid")
		item.item_id = Protocol.read_string(data, "itemId")
		item.name = Protocol.read_string(data, "name")
		item.description = Protocol.read_string(data, "description")
		item.set_name = Protocol.read_string(data, "set")
		item.slot = Protocol.read_string(data, "slot")
		item.bonus_hp = Protocol.read_float(data, "bonusHp")
		var profile: Dictionary = Protocol.read_dict(data, "profile")
		for key: String in ["damage", "health", "healing", "cooldown"]:
			var tier: String = Protocol.read_string(profile, key)
			if not tier.is_empty():
				item.profile[key] = tier
		var attack: Dictionary = Protocol.read_dict(data, "basicAttack")
		if not attack.is_empty():
			item.basic_attack = AbilityView.from_dict(attack, item.slot)
		for ability: Dictionary in Protocol.read_dict_array(data, "abilities"):
			item.abilities.append(AbilityView.from_dict(ability, item.slot))
		return item


## Item vestido em cada slot (sem chave = vazio).
var equipped: Dictionary[String, Item] = {}
## Itens na mochila.
var bag: Array[Item] = []
var bag_capacity: int = 0
## Ataque simples sem arma.
var unarmed_attack: AbilityView = AbilityView.new("punch", "Soco", "Arma", AbilityView.AimType.TARGET, 1.5)


## Cria a partir do payload da mensagem "inventory".
static func from_dict(data: Dictionary) -> InventoryState:
	var state: InventoryState = InventoryState.new()
	var slots: Dictionary = Protocol.read_dict(data, "equipped")
	for slot: String in SLOTS:
		var item_data: Dictionary = Protocol.read_dict(slots, slot)
		if not item_data.is_empty():
			state.equipped[slot] = Item.from_dict(item_data)
	for item_data: Dictionary in Protocol.read_dict_array(data, "bag"):
		state.bag.append(Item.from_dict(item_data))
	state.bag_capacity = Protocol.read_int(data, "bagCapacity")
	var unarmed: Dictionary = Protocol.read_dict(data, "unarmedAttack")
	if not unarmed.is_empty():
		state.unarmed_attack = AbilityView.from_dict(unarmed, "hand")
	return state


## Item vestido no [param slot], ou null.
func item_in(slot: String) -> Item:
	if not equipped.has(slot):
		return null
	return equipped[slot]


## As 6 cartas na ordem da HUD: 3 da arma, cabeça, peito, pés. Slot vazio → null nas posições dele.
func cards() -> Array[AbilityView]:
	var result: Array[AbilityView] = []
	var per_slot: Dictionary[String, int] = {"hand": 3, "head": 1, "chest": 1, "feet": 1}
	for slot: String in SLOTS:
		var item: Item = item_in(slot)
		for i: int in range(per_slot[slot]):
			result.append(item.abilities[i] if item != null and i < item.abilities.size() else null)
	return result


## Ataque simples atual: o da arma vestida, ou o soco.
func basic_attack() -> AbilityView:
	var weapon: Item = item_in("hand")
	return weapon.basic_attack if weapon != null and weapon.basic_attack != null else unarmed_attack
