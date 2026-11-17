class_name LevelText
extends RefCounted
## Nível abreviado para caber nos quadradinhos e nos nomes ([SOC-08]): até 999 o número inteiro; de 1.000 para cima
## "1k", "1.2k", "12k", "999k", "1M", "1.5M"… Uma casa decimal só abaixo de 10 (mil/milhão), sempre cortando (nunca
## arredonda para cima: 1.999 = "1.9k"). O jogo não tem nível máximo ([JOGO-12]).


## Texto curto do nível [param level].
static func short(level: int) -> String:
	if level < 1000:
		return str(level)
	if level < 1000000:
		return _abbreviate(level, 1000, "k")
	return _abbreviate(level, 1000000, "M")


## [param value] em unidades de [param unit] com o sufixo [param suffix] (1 casa abaixo de 10 unidades).
static func _abbreviate(value: int, unit: int, suffix: String) -> String:
	var whole: int = value / unit
	if whole >= 10:
		return "%d%s" % [whole, suffix]
	var tenth: int = (value % unit) * 10 / unit
	return ("%d%s" % [whole, suffix]) if tenth == 0 else ("%d.%d%s" % [whole, tenth, suffix])


## "[nível] nome" como em cima do boneco e nas listas ([CLI-04], [SOC-02]).
static func title(level: int, name: String) -> String:
	return "[%s] %s" % [short(level), name]
