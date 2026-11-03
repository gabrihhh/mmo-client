class_name AbilityVisuals
extends RefCounted
## Como cada habilidade aparece ([JOGO-08]): animação do personagem, cor dos efeitos e projétil visual.
##
## Regra (dano, alcance, tempo) é do servidor; aqui é só o visual. Habilidade nova: uma linha em cada tabela
## que fizer sentido (sem linha = animação "cast_forward" e cor padrão).
## ATENÇÃO: ids de habilidade vêm de mmo-server/src/items/catalog.ts; animações de CharacterAnimator.HIT_TIMES.

## Habilidade → animação do personagem (por tipo de arma no ataque simples; cardápio genérico nas cartas).
const ANIMATIONS: Dictionary[String, String] = {
	"sword_attack": "attack_sword",
	"staff_attack": "attack_staff",
	"punch": "attack_punch",
	"heavy_strike": "heavy_strike",
	"dash": "dash",
	"spin": "spin",
	"fireball": "cast_forward",
	"bolt": "cast_forward",
	"meteor": "cast_up",
	"heal": "buff",
	"shield": "buff",
	"sprint": "buff",
}
## Cor dos efeitos (projétil, aviso no chão).
const COLORS: Dictionary[String, Color] = {
	"fireball": Color(1.0, 0.45, 0.1),
	"meteor": Color(1.0, 0.3, 0.1),
	"staff_attack": Color(0.7, 0.4, 1.0),
	"bolt": Color(0.55, 0.9, 1.0),
	"heal": Color(0.4, 1.0, 0.45),
	"shield": Color(0.5, 0.75, 1.0),
}
const DEFAULT_COLOR: Color = Color(1.0, 0.85, 0.5)
## Golpes corpo a corpo com clarão no momento do golpe: alcance do clarão (m). Negativo = anel inteiro (ao redor).
const SLASH_REACH: Dictionary[String, float] = {
	"sword_attack": 1.8,
	"heavy_strike": 2.3,
	"punch": 1.1,
	"spin": -3.0,
}
## Magias que acendem um brilho na mão durante o lançamento (mostra aos outros que vem coisa aí).
const CAST_GLOW: Array[String] = ["fireball", "meteor", "bolt", "heal", "shield"]
## Habilidades de alvo com projétil só visual: tempo de voo (s). Ele sai de modo a chegar junto com o dano.
const HOMING_FLIGHT: Dictionary[String, float] = {
	"staff_attack": 0.3,
	"bolt": 0.15,
}


## Animação do personagem para [param ability_id].
static func animation(ability_id: String) -> String:
	return ANIMATIONS.get(ability_id, "cast_forward")


## Cor dos efeitos de [param ability_id].
static func color(ability_id: String) -> Color:
	return COLORS.get(ability_id, DEFAULT_COLOR)


## Alcance (m) do clarão do golpe de [param ability_id]; 0 = não tem; negativo = anel inteiro.
static func slash_reach(ability_id: String) -> float:
	return SLASH_REACH.get(ability_id, 0.0)


## true se [param ability_id] acende o brilho na mão durante o lançamento.
static func has_cast_glow(ability_id: String) -> bool:
	return ability_id in CAST_GLOW


## Tempo de voo (s) do projétil visual de [param ability_id]; 0 = não tem.
static func homing_flight(ability_id: String) -> float:
	return HOMING_FLIGHT.get(ability_id, 0.0)
