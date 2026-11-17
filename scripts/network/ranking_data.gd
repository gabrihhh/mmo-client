class_name RankingData
extends RefCounted
## Uma tabela de ranking como o servidor manda em [constant Protocol.MSG_RANKING] (mmo-docs [SOC-07]): top 100, a
## minha linha (ou a da minha guilda) e quando o período vira. Só exibição: quem conta e ordena é o servidor.
##
## ATENÇÃO: espelho de RankingData em mmo-server/src/net/protocol.ts.

## Categorias. ATENÇÃO: RANKING_CATEGORIES em mmo-server/src/progression/ranking.ts.
const CATEGORY_MONSTERS: String = "monsters"
const CATEGORY_PVP: String = "pvp"
const CATEGORY_GUILD_MONSTERS: String = "guild_monsters"
const CATEGORY_GUILD_PVP: String = "guild_pvp"
## Períodos. ATENÇÃO: RANKING_PERIODS em mmo-server/src/progression/ranking.ts.
const PERIOD_DAILY: String = "daily"
const PERIOD_WEEKLY: String = "weekly"
const PERIOD_GLOBAL: String = "global"


## Uma linha: posição, id (jogador ou guilda), nome (ou "[TAG] Nome") e valor (XP ou jogadores mortos).
class Row:
	extends RefCounted
	var rank: int = 0
	var id: String = ""
	var name: String = ""
	var value: float = 0.0


var category: String = ""
var period: String = ""
## Top 100, do primeiro ao último.
var rows: Array[Row] = []
## Minha linha (ou da minha guilda); null = ainda não pontuou / sem guilda.
var me: Row = null
## Segundos até o período virar (0 = global).
var resets_in: int = 0
## Há quantos segundos a tabela foi calculada.
var age: int = 0


## Lê o `data` de [constant Protocol.MSG_RANKING].
static func from_dict(data: Dictionary) -> RankingData:
	var result: RankingData = RankingData.new()
	result.category = Protocol.read_string(data, "category")
	result.period = Protocol.read_string(data, "period")
	for entry: Dictionary in Protocol.read_dict_array(data, "rows"):
		result.rows.append(_row(entry))
	var me_data: Dictionary = Protocol.read_dict(data, "me")
	result.me = null if me_data.is_empty() else _row(me_data)
	result.resets_in = Protocol.read_int(data, "resetsIn")
	result.age = Protocol.read_int(data, "age")
	return result


static func _row(entry: Dictionary) -> Row:
	var row: Row = Row.new()
	row.rank = Protocol.read_int(entry, "rank")
	row.id = Protocol.read_string(entry, "id")
	row.name = Protocol.read_string(entry, "name")
	row.value = Protocol.read_float(entry, "value")
	return row


## true para os rankings de guilda.
static func is_guild(category_id: String) -> bool:
	return category_id == CATEGORY_GUILD_MONSTERS or category_id == CATEGORY_GUILD_PVP
