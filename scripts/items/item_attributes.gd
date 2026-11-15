class_name ItemAttributes
extends RefCounted
## Atributos de melhoria dos itens no ferreiro ([JOGO-16]): nome na tela, cor e o texto do efeito dos pontos.
## Só exibição: quem decide preço, chance e resultado é o servidor (vem pronto no inventário).
## ATENÇÃO: ids e contas espelham mmo-server/src/items/attributes.ts (ATTRIBUTE_IDS, LINEAR_PER_POINT, DIMINISHING_K).

## Ordem de exibição (a mesma do servidor).
const IDS: Array[String] = ["damage", "healing", "shield", "health", "mana", "defense", "cooldown", "crit", "attackSpeed", "lifesteal"]
## Nome de cada atributo.
const TITLES: Dictionary[String, String] = {
	"damage": "Dano", "healing": "Cura", "shield": "Escudo", "health": "Vida", "mana": "Mana", "defense": "Defesa",
	"cooldown": "Recarga", "crit": "Crítico", "attackSpeed": "Velocidade de ataque", "lifesteal": "Roubo de vida",
}
## Cor da etiqueta de cada atributo.
const COLORS: Dictionary[String, Color] = {
	"damage": Color(0.62, 0.18, 0.14), "healing": Color(0.18, 0.5, 0.2), "shield": Color(0.2, 0.36, 0.62),
	"health": Color(0.55, 0.2, 0.3), "mana": Color(0.22, 0.3, 0.7), "defense": Color(0.35, 0.38, 0.42),
	"cooldown": Color(0.32, 0.3, 0.28), "crit": Color(0.7, 0.42, 0.1), "attackSpeed": Color(0.5, 0.4, 0.12),
	"lifesteal": Color(0.45, 0.1, 0.18),
}
## Atributos com retorno decrescente (os outros: +1% por ponto, sem teto).
const DIMINISHING: Array[String] = ["defense", "cooldown", "crit", "lifesteal"]
## +1% por ponto. ATENÇÃO: = LINEAR_PER_POINT no servidor.
const LINEAR_PER_POINT: float = 0.01
## 1 − 1 / (1 + k × pontos). ATENÇÃO: = DIMINISHING_K no servidor.
const DIMINISHING_K: float = 0.005


## Nome do atributo [param id] (id desconhecido = o próprio id).
static func title(id: String) -> String:
	return TITLES.get(id, id)


## Fração do efeito de [param points] pontos no atributo [param id] (0,05 = 5%).
static func effect(id: String, points: int) -> float:
	if points <= 0:
		return 0.0
	if DIMINISHING.has(id):
		return 1.0 - 1.0 / (1.0 + DIMINISHING_K * float(points))
	return LINEAR_PER_POINT * float(points)


## Texto do efeito: "+5% de dano", "−2,4% de recarga", "4,8% de chance de crítico"...
static func effect_text(id: String, points: int) -> String:
	var percent: String = _percent(effect(id, points))
	match id:
		"defense":
			return "−%s de dano recebido" % percent
		"cooldown":
			return "−%s de recarga" % percent
		"crit":
			return "%s de chance de crítico" % percent
		"lifesteal":
			return "%s do dano vira vida" % percent
		"attackSpeed":
			return "+%s de velocidade de ataque" % percent
		_:
			return "+%s de %s" % [percent, title(id).to_lower()]


## 0,0475 → "4,8%" (1 casa, sem ",0").
static func _percent(fraction: float) -> String:
	var value: float = snappedf(fraction * 100.0, 0.1)
	var text: String = str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value).replace(".", ",")
	return text + "%"
