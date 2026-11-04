class_name AbilityView
extends RefCounted
## O que o CLIENTE sabe de uma habilidade: a carta, a prévia da mira e a ficha do item no inventário ([CLI-10]).
## Ver mmo-docs [JOGO-01..03].
##
## Os números (dano, recarga, mana...) são só para MOSTRAR: quem aplica e decide é o servidor. Os dados vêm do
## servidor, junto com o inventário, na mensagem "inventory" ([InventoryState]).

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
## Tempo de lançamento em segundos: o personagem fica virado para o alvo/direção durante ele ([JOGO-05]).
var cast_time_s: float = 0.0
## Mana gasta (conferida antes de prever Investida/Disparada).
var mana_cost: float = 0.0
## Investida: metros percorridos e em quantos segundos. Disparada: multiplicador de velocidade e duração (s).
## 0 nas outras ([JOGO-07]).
var dash_distance: float = 0.0
var dash_seconds: float = 0.0
var speed_multiplier: float = 0.0
var speed_seconds: float = 0.0
## Frase curta da ficha do item.
var description: String = ""
## Só exibição (ficha do item): dano por alvo, cura, escudo (absorve) e duração (s), velocidade do projétil (m/s).
var damage: float = 0.0
var heal: float = 0.0
var shield: float = 0.0
var shield_seconds: float = 0.0
var projectile_speed: float = 0.0


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
	).with_cast_time(Protocol.read_float(data, "castTime")).with_movement(data).with_display(data)


## Lê mana e os dados de movimento (Investida/Disparada) do AbilityView do servidor (encadeável).
func with_movement(data: Dictionary) -> AbilityView:
	mana_cost = Protocol.read_float(data, "manaCost")
	dash_distance = Protocol.read_float(data, "dashDistance")
	dash_seconds = Protocol.read_float(data, "dashSeconds")
	speed_multiplier = Protocol.read_float(data, "speedMultiplier")
	speed_seconds = Protocol.read_float(data, "speedSeconds")
	return self


## Lê a descrição e os números só de exibição (ficha do item) do AbilityView do servidor (encadeável).
func with_display(data: Dictionary) -> AbilityView:
	description = Protocol.read_string(data, "description")
	damage = Protocol.read_float(data, "damage")
	heal = Protocol.read_float(data, "heal")
	shield = Protocol.read_float(data, "shield")
	shield_seconds = Protocol.read_float(data, "shieldSeconds")
	projectile_speed = Protocol.read_float(data, "projectileSpeed")
	return self


## Nome da mira na ficha do item.
const AIM_LABELS: Dictionary[AimType, String] = {
	AimType.TARGET: "No alvo",
	AimType.DIRECTION: "Em linha",
	AimType.AREA: "Área no chão",
	AimType.AREA_SELF: "Ao seu redor",
	AimType.SELF: "Em você",
}
## Tipo de cada número da ficha (cor da etiqueta, [ItemDetailPanel]).
enum StatKind { DAMAGE, HEAL, SHIELD, MANA, TIME, OTHER }


## Números da ficha do item, na ordem de leitura: [[texto, StatKind], ...]. Ex.: ["Dano 24", DAMAGE],
## ["Recarga 5 s", TIME]. Duração = quanto um efeito dura (escudo, velocidade).
func stats() -> Array[Array]:
	var out: Array[Array] = []
	out.append(["Mira: %s" % AIM_LABELS[aim_type], StatKind.OTHER])
	if damage > 0.0:
		out.append(["Dano %s" % number(damage), StatKind.DAMAGE])
	if heal > 0.0:
		out.append(["Cura +%s" % number(heal), StatKind.HEAL])
	if shield > 0.0:
		out.append(["Escudo %s · dura %s s" % [number(shield), number(shield_seconds)], StatKind.SHIELD])
	if speed_multiplier > 0.0:
		out.append(["Velocidade +%s%% · dura %s s" % [number((speed_multiplier - 1.0) * 100.0), number(speed_seconds)], StatKind.OTHER])
	if dash_distance > 0.0:
		out.append(["Avança %s m em %s s" % [number(dash_distance), number(dash_seconds)], StatKind.OTHER])
	elif range_m > 0.0:
		out.append(["Alcance %s m" % number(range_m), StatKind.OTHER])
	if radius_m > 0.0 and (aim_type == AimType.AREA or aim_type == AimType.AREA_SELF):
		out.append(["Raio %s m" % number(radius_m), StatKind.OTHER])
	if projectile_speed > 0.0:
		out.append(["Projétil %s m/s (dá para desviar)" % number(projectile_speed), StatKind.OTHER])
	out.append(["Lançamento %s s" % number(cast_time_s) if cast_time_s > 0.0 else "Instantânea", StatKind.TIME])
	out.append(["Recarga %s s" % number(cooldown_s), StatKind.TIME])
	if mana_cost > 0.0:
		out.append(["Mana %s" % number(mana_cost), StatKind.MANA])
	return out


## Número para a ficha: sem casas quando inteiro, senão até 2 casas com vírgula ("0,5", "1,25").
static func number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	var text: String = "%.2f" % value
	text = text.rstrip("0").rstrip(".")
	return text.replace(".", ",")


## Passos de movimento que a Investida dura (pelo menos 1), com [param tick_rate] em Hz.
## ATENÇÃO: mesma conta de dashSteps em mmo-server/src/items/catalog.ts.
func dash_steps(tick_rate: int) -> int:
	return maxi(1, roundi(dash_seconds * tick_rate))


## true se mexe no movimento: vai na fila de passos com predição ([JOGO-07]).
func is_movement() -> bool:
	return dash_distance > 0.0 or speed_multiplier > 0.0


## Define o tempo de lançamento (encadeável) e devolve a própria habilidade.
func with_cast_time(seconds: float) -> AbilityView:
	cast_time_s = seconds
	return self


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
