class_name PlayerAttributes
extends RefCounted
## Atributos de um jogador como o servidor responde ao [constant Protocol.MSG_INSPECT] (mensagem
## [constant Protocol.MSG_ATTRIBUTES]): o que a tela de Atributos mostra ([AttributesPanel], mmo-docs [SOC-02]).
## Só exibição: quem calcula vida, mana e força é o servidor.
##
## ATENÇÃO: espelho de AttributesView em mmo-server/src/net/protocol.ts.

## Um item vestido, só o que se mostra.
class EquippedItem:
	extends RefCounted
	## Id do item no catálogo (ícone: [method ItemIcons.item]).
	var item_id: String = ""
	## Nome exibido.
	var name: String = ""
	## Conjunto ("Mago", "Cavaleiro"...): cor da moldura ([method ItemIcons.set_color]).
	var set_name: String = ""

## Id do jogador.
var id: String = ""
## Nome exibido (username como foi cadastrado).
var name: String = ""
## Nível ([JOGO-12]).
var level: int = 0
## Vida e mana máximas (com nível e vida extra dos itens).
var max_hp: float = 0.0
var max_mana: float = 0.0
## Força pelo nível: multiplicadores do dano, da cura e do escudo que ele dá (1 = nível 0).
var damage_power: float = 1.0
var healing_power: float = 1.0
var shield_power: float = 1.0
## Item vestido por slot ("hand", "head", "chest", "feet"); slot vazio não entra.
var equipped: Dictionary[String, EquippedItem] = {}
## Perfil fechado para mim (Configuração → Perfil do dono, [SOC-08]): só id, nome e nível valem.
var hidden: bool = false
## Contadores do perfil ([SOC-08]): XP ganha matando monstros, jogadores mortos e mortes.
var monster_xp: float = 0.0
var kills: int = 0
var deaths: int = 0


## Lê o `data` de [constant Protocol.MSG_ATTRIBUTES]; null se faltar o id.
static func from_dict(data: Dictionary) -> PlayerAttributes:
	var result: PlayerAttributes = PlayerAttributes.new()
	result.id = Protocol.read_string(data, "id")
	if result.id.is_empty():
		return null
	result.name = Protocol.read_string(data, "name")
	result.level = Protocol.read_int(data, "level")
	var hidden_value: Variant = data.get("hidden")
	result.hidden = hidden_value is bool and hidden_value == true
	if result.hidden:
		return result
	var stats: Dictionary = Protocol.read_dict(data, "stats")
	result.monster_xp = Protocol.read_float(stats, "monsterXp")
	result.kills = Protocol.read_int(stats, "kills")
	result.deaths = Protocol.read_int(stats, "deaths")
	result.max_hp = Protocol.read_float(data, "maxHp")
	result.max_mana = Protocol.read_float(data, "maxMana")
	var power: Dictionary = Protocol.read_dict(data, "power")
	result.damage_power = Protocol.read_float(power, "damage", 1.0)
	result.healing_power = Protocol.read_float(power, "healing", 1.0)
	result.shield_power = Protocol.read_float(power, "shield", 1.0)
	var slots: Dictionary = Protocol.read_dict(data, "equipped")
	for slot: String in InventoryState.SLOTS:
		var entry: Dictionary = Protocol.read_dict(slots, slot)
		var item_id: String = Protocol.read_string(entry, "itemId")
		if item_id.is_empty():
			continue
		var item: EquippedItem = EquippedItem.new()
		item.item_id = item_id
		item.name = Protocol.read_string(entry, "name")
		item.set_name = Protocol.read_string(entry, "set")
		result.equipped[slot] = item
	return result
