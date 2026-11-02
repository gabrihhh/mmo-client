class_name AbilityView
extends RefCounted
## O que o CLIENTE precisa saber de uma habilidade para mostrar a carta e a prévia da mira.
## Ver mmo-docs [JOGO-01..03].
##
## Não tem dano, recarga nem custo: quem decide isso é o servidor. Hoje os dados vêm do kit de treino
## local ([method training_kit]); no passo 2 do [ROAD-05] passam a vir do servidor (itens vestidos).

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


func _init(ability_id: String, ability_title: String, slot: String, aim: AimType, range_meters: float = 0.0, radius_meters: float = 0.0) -> void:
	id = ability_id
	title = ability_title
	slot_label = slot
	aim_type = aim
	range_m = range_meters
	radius_m = radius_meters


## true se a habilidade precisa de mira (não sai na hora).
func needs_aim() -> bool:
	return aim_type != AimType.SELF


## Ataque simples da arma de treino: corpo a corpo, 2,5 m ([JOGO-03]). Arrastar escolhe o alvo fixo até 15 m.
static func training_attack() -> AbilityView:
	return AbilityView.new("basic_attack", "Ataque", "Arma", AimType.TARGET, 2.5)


## As 6 cartas do kit de treino, na ordem da HUD: 3 da arma, cabeça, peito, pés ([JOGO-03]).
static func training_kit() -> Array[AbilityView]:
	return [
		AbilityView.new("heavy_strike", "Golpe forte", "Arma", AimType.TARGET, 3.0),
		AbilityView.new("dash", "Investida", "Arma", AimType.DIRECTION, 6.0, 1.0),
		AbilityView.new("spin", "Giro", "Arma", AimType.AREA_SELF, 0.0, 3.0),
		AbilityView.new("heal", "Cura", "Cabeça", AimType.SELF),
		AbilityView.new("shield", "Escudo", "Peito", AimType.SELF),
		AbilityView.new("sprint", "Disparada", "Pés", AimType.SELF),
	]
