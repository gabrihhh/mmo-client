class_name AbilityView
extends RefCounted
## O que o CLIENTE precisa saber de uma habilidade para mostrar a carta e a prévia da mira.
## Ver mmo-docs [JOGO-01..03].
##
## Não tem dano, recarga nem custo: quem decide isso é o servidor. Os dados vêm do servidor, junto com
## o inventário (itens vestidos), na mensagem "inventory" ([InventoryState]).

## Como a habilidade mira (define a prévia e o que vai no pedido ao servidor).
enum AimType {
	## Em uma unidade (jogador/monstro): toque usa o alvo fixo; arrastar escolhe quem está sob a mira.
	TARGET,
	## Numa direção a partir do personagem (linha de [member range_m]).
	DIRECTION,
	## Área num ponto do chão, até [member range_m] de distância, raio [member radius_m].
	AREA,
	## Área ao redor do próprio personagem (raio [member radius_m]).
	AREA_SELF,
	## Em si mesmo (bônus/cura): sai na hora, sem mira.
	SELF,
}

## Id da habilidade (o servidor reconhece por ele).
var id: String = ""
## Nome curto na carta.
var title: String = ""
## Slot de origem, para a legenda da carta: "Arma", "Cabeça", "Peito", "Pés".
var slot_label: String = ""
var aim_type: AimType = AimType.SELF
## Alcance em metros (TARGET, DIRECTION, AREA).
var range_m: float = 0.0
## Raio em metros (AREA, AREA_SELF) ou largura da linha (DIRECTION).
var radius_m: float = 0.0
## Tempo de recarga em segundos (no ataque simples: intervalo entre golpes). Mostrado como relógio na carta.
var cooldown_s: float = 0.0


func _init(ability_id: String, ability_title: String, slot: String, aim: AimType, range_meters: float = 0.0, radius_meters: float = 0.0, cooldown_seconds: float = 0.0) -> void:
	id = ability_id
	title = ability_title
	slot_label = slot
	aim_type = aim
	range_m = range_meters
	radius_m = radius_meters
	cooldown_s = cooldown_seconds


## true se a habilidade precisa de mira (não sai na hora).
func needs_aim() -> bool:
	return aim_type != AimType.SELF


## Nome em português de cada slot (legenda da carta e do inventário).
const SLOT_LABELS: Dictionary[String, String] = {"hand": "Arma", "head": "Cabeça", "chest": "Peito", "feet": "Pés"}


## Cria a partir do AbilityView do servidor ({ id, title, aim, range, radius }). [param slot] = "hand", "head"...
static func from_dict(data: Dictionary, slot: String) -> AbilityView:
	var label: String = SLOT_LABELS[slot] if SLOT_LABELS.has(slot) else slot
	return AbilityView.new(
		Protocol.read_string(data, "id"),
		Protocol.read_string(data, "title"),
		label,
		_aim_from_string(Protocol.read_string(data, "aim")),
		Protocol.read_float(data, "range"),
		Protocol.read_float(data, "radius"),
		Protocol.read_float(data, "cooldown"),
	)


## ATENÇÃO: nomes iguais a AimType em mmo-server/src/items/catalog.ts.
static func _aim_from_string(aim: String) -> AimType:
	match aim:
		"target":
			return AimType.TARGET
		"direction":
			return AimType.DIRECTION
		"area":
			return AimType.AREA
		"area_self":
			return AimType.AREA_SELF
		_:
			return AimType.SELF
