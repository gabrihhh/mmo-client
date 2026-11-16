class_name ChestInfo
extends RefCounted
## Baú de um acampamento ([JOGO-19]), como vem no `welcome`: onde fica (no chão, m), nível, se o acampamento tem chefe
## e se está aberto (o evento `chest` muda). ATENÇÃO: ChestView em mmo-server/src/net/protocol.ts.

var id: String = ""
var x: float = 0.0
var z: float = 0.0
var level: int = 0
var boss: bool = false
var open: bool = false


## Lê do dicionário do welcome; null se faltar o id.
static func from_dict(data: Dictionary) -> ChestInfo:
	var chest: ChestInfo = ChestInfo.new()
	chest.id = Protocol.read_string(data, "id")
	if chest.id.is_empty():
		return null
	chest.x = Protocol.read_float(data, "x")
	chest.z = Protocol.read_float(data, "z")
	chest.level = Protocol.read_int(data, "level")
	var boss_value: Variant = data.get("boss")
	chest.boss = boss_value is bool and boss_value == true
	var open_value: Variant = data.get("open")
	chest.open = open_value is bool and open_value == true
	return chest
