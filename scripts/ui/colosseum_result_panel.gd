class_name ColosseumResultPanel
extends PixelMenuPanel
## Fim da partida do Coliseu ([JOGO-28]), mostrado já de volta na praça: Vitória / Derrota / Empate / Abandono (ou
## "Partida anulada"), o placar e o prêmio que entrou na conta — moedas, XP, Pontos de Coliseu, ranking do modo (e
## quanto mudou) e o nível. Passou das partidas premiadas do dia: avisa que só o ranking contou. Só exibição: o
## servidor calculou e aplicou tudo ([ColosseumData.Result]).

## Altura do painel (px).
const HEIGHT_PX: float = 820.0
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const WIN_COLOR: Color = Color(0.5, 1.0, 0.5)
const LOSS_COLOR: Color = Color(1.0, 0.55, 0.45)
const DIM_COLOR: Color = Color(1, 1, 1, 0.7)
const _TITLES: Dictionary[String, String] = {"win": "Vitória!", "loss": "Derrota", "draw": "Empate", "abandon": "Você abandonou"}

var _headline: Label = null
var _score: Label = null
var _lines: Label = null
var _note: Label = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Coliseu")
	back_button.text = "OK"
	_headline = PixelMenuPanel.make_label("", GOLD_COLOR)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_font_size_override("font_size", 48)
	body.add_child(_headline)
	_score = PixelMenuPanel.make_label("", DIM_COLOR)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_score)
	_lines = PixelMenuPanel.make_label("")
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.add_theme_font_size_override("font_size", 32)
	body.add_child(_lines)
	_note = PixelMenuPanel.make_label("", DIM_COLOR)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_note)


## Mostra o fim da partida [param result].
func show_result(result: ColosseumData.Result) -> void:
	var title: String = _TITLES.get(result.outcome, result.outcome)
	if result.annulled and result.outcome != "abandon":
		title = "Partida anulada"
	_headline.text = title
	var color: Color = WIN_COLOR if result.outcome == "win" else (LOSS_COLOR if result.outcome in ["loss", "abandon"] else GOLD_COLOR)
	_headline.add_theme_color_override("font_color", color)
	_score.text = "%s · placar %d x %d" % [result.mode, result.score[0], result.score[1]]
	var lines: Array[String] = []
	if result.gold > 0 or result.xp > 0.0 or result.points > 0:
		lines.append("+%s moedas" % InventoryView.format_gold(result.gold))
		lines.append("+%s XP" % str(snappedf(result.xp, 0.1)))
		lines.append("+%d Pontos de Coliseu" % result.points)
	lines.append("Ranking %s: %d (%s)" % [result.mode, result.rating, ("%+d" % result.rating_delta) if result.rating_delta != 0 else "±0"])
	lines.append("Nível %d" % result.level)
	_lines.text = "\n".join(lines)
	var notes: Array[String] = []
	if result.annulled:
		notes.append("Alguém abandonou antes do fim do 1º round: sem prêmio nem ranking.")
	if result.outcome == "abandon":
		notes.append("Abandonar tira ranking e bloqueia o Coliseu por 10 min.")
	elif not result.rewarded and not result.annulled:
		notes.append("Você já jogou as partidas premiadas de hoje: só o ranking contou.")
	_note.text = "\n".join(notes)
