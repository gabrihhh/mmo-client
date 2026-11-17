class_name ChestInfo
extends RefCounted
## Baú de um acampamento ([JOGO-19]), como vem no `welcome`: onde fica (no chão, m), nível, se o acampamento tem chefe
## e se está aberto (o evento `chest` muda), e quando o acampamento volta inteiro (relógio do mapa, [CLI-11]).
## ATENÇÃO: ChestView em mmo-server/src/net/protocol.ts.

var id: String = ""
var x: float = 0.0
var z: float = 0.0
var level: int = 0
var boss: bool = false
var open: bool = false
## Quando (Time.get_ticks_msec) o acampamento volta inteiro; 0 = nenhum relógio correndo.
var reset_at_msec: int = 0


## Guarda o relógio a partir de [param reset_in] segundos (do servidor; 0 = sem relógio). Contado aqui, sem rede.
func set_reset_in(reset_in: float) -> void:
	reset_at_msec = 0 if reset_in <= 0.0 else Time.get_ticks_msec() + int(reset_in * 1000.0)


## Segundos que faltam para o acampamento voltar; -1 = nenhum relógio correndo.
func reset_in_seconds() -> float:
	if reset_at_msec == 0:
		return -1.0
	return maxf(0.0, float(reset_at_msec - Time.get_ticks_msec()) / 1000.0)


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
	chest.set_reset_in(Protocol.read_float(data, "resetIn"))
	return chest
