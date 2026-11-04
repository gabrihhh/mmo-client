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
	# Conjunto do Mago
	"arcane_attack": "attack_staff",
	"ice_lance": "cast_forward",
	"arcane_nova": "cast_up",
	"starfall": "cast_up",
	"meditation": "buff",
	"arcane_barrier": "buff",
	"blink": "dash",
	# Conjunto do Cavaleiro
	"knight_attack": "attack_sword",
	"line_cleave": "heavy_strike",
	"heroic_charge": "dash",
	"ground_slam": "heavy_strike",
	"rallying_cry": "buff",
	"steel_wall": "buff",
	"iron_stance": "buff",
	# Conjunto do Atirador (besta: tiros como o cajado, para a frente)
	"crossbow_attack": "attack_staff",
	"piercing_bolt": "cast_forward",
	"bolt_rain": "cast_up",
	"quick_shot": "cast_forward",
	"bandage": "buff",
	"leather_guard": "buff",
	"roll": "dash",
	# Conjunto do Assassino
	"dagger_attack": "attack_sword",
	"shadow_leap": "dash",
	"backstab": "heavy_strike",
	"blade_flurry": "spin",
	"evasion": "buff",
	"smoke_veil": "buff",
	"shadow_step": "buff",
	# Conjunto do Curandeiro (cura em aliado = magia para a frente, [JOGO-09])
	"tome_attack": "cast_forward",
	"greater_heal": "cast_forward",
	"healing_circle": "cast_up",
	"holy_shield": "cast_forward",
	"grace": "buff",
	"aegis": "cast_up",
	"light_steps": "buff",
}
## Cor dos efeitos (projétil, aviso no chão).
const COLORS: Dictionary[String, Color] = {
	"fireball": Color(1.0, 0.45, 0.1),
	"meteor": Color(1.0, 0.3, 0.1),
	"staff_attack": Color(0.7, 0.4, 1.0),
	"bolt": Color(0.55, 0.9, 1.0),
	"heal": Color(0.4, 1.0, 0.45),
	"shield": Color(0.5, 0.75, 1.0),
	"arcane_attack": Color(0.6, 0.5, 1.0),
	"ice_lance": Color(0.6, 0.95, 1.0),
	"arcane_nova": Color(0.85, 0.4, 1.0),
	"starfall": Color(1.0, 0.9, 0.4),
	"meditation": Color(0.5, 0.9, 1.0),
	"arcane_barrier": Color(0.75, 0.5, 1.0),
	"line_cleave": Color(0.9, 0.95, 1.0),
	"ground_slam": Color(1.0, 0.6, 0.3),
	"rallying_cry": Color(0.5, 0.75, 1.0),
	"steel_wall": Color(0.8, 0.85, 0.95),
	"iron_stance": Color(1.0, 0.85, 0.4),
	"crossbow_attack": Color(0.75, 0.95, 0.5),
	"piercing_bolt": Color(0.6, 1.0, 0.4),
	"bolt_rain": Color(0.85, 0.95, 0.6),
	"quick_shot": Color(1.0, 0.95, 0.5),
	"bandage": Color(0.4, 1.0, 0.45),
	"leather_guard": Color(0.6, 0.85, 0.5),
	"backstab": Color(0.8, 0.3, 1.0),
	"blade_flurry": Color(0.7, 0.35, 0.9),
	"evasion": Color(1.0, 0.85, 0.4),
	"smoke_veil": Color(0.55, 0.5, 0.65),
	"tome_attack": Color(1.0, 0.95, 0.6),
	"greater_heal": Color(0.4, 1.0, 0.45),
	"healing_circle": Color(0.5, 1.0, 0.55),
	"holy_shield": Color(1.0, 0.9, 0.5),
	"grace": Color(1.0, 0.85, 0.4),
	"aegis": Color(1.0, 0.9, 0.55),
}
const DEFAULT_COLOR: Color = Color(1.0, 0.85, 0.5)
## Golpes corpo a corpo com clarão no momento do golpe: alcance do clarão (m). Negativo = anel inteiro (ao redor).
const SLASH_REACH: Dictionary[String, float] = {
	"sword_attack": 1.8,
	"heavy_strike": -2.5,
	"punch": 1.1,
	"spin": -3.0,
	"knight_attack": 1.9,
	"line_cleave": 3.0,
	"ground_slam": -3.5,
	"dagger_attack": 1.5,
	"backstab": 1.8,
	"blade_flurry": -2.5,
}
## Magias que acendem um brilho na mão durante o lançamento (mostra aos outros que vem coisa aí).
const CAST_GLOW: Array[String] = [
	"fireball", "meteor", "bolt", "heal", "shield",
	"ice_lance", "arcane_nova", "starfall", "meditation", "arcane_barrier",
	"bandage", "tome_attack", "greater_heal", "healing_circle", "holy_shield", "aegis",
]
## Habilidades de alvo com projétil só visual: tempo de voo (s). Ele sai de modo a chegar junto com o dano.
## Reserva: o tempo de verdade vem do servidor no `cast_start.release` (AbilityDef.releaseTime em
## mmo-server/src/items/catalog.ts); manter igual.
const HOMING_FLIGHT: Dictionary[String, float] = {
	"staff_attack": 0.3,
	"bolt": 0.15,
	"arcane_attack": 0.3,
	"crossbow_attack": 0.25,
	"quick_shot": 0.1,
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
