class_name RankingPanel
extends PixelMenuPanel
## Menu → "Ranking" ([SOC-07]). Abas de cima: **Monstros** (XP ganha matando monstros), **PvP** (jogadores mortos) e
## **Guilda** (com as sub-abas Monstros / PvP: soma dos membros atuais) e **Coliseu** ([JOGO-28], sub-abas 1x1 / 2x2 /
## 3x3: global = pontos de ranking atuais, diário/semanal = pontos ganhos no período). Abas de baixo: **Diário**, **Semanal** e
## **Global**. A lista mostra o top 100 ("1. Nome ...... valor", os três primeiros em ouro/prata/bronze) e embaixo a
## minha posição (ou a da minha guilda). Ao abrir ou trocar de aba pede a tabela ([signal ranking_requested]); a
## [Hud] devolve a resposta por [method show_ranking]. O servidor recalcula no máximo a cada minuto.

## Pediu a tabela [param category] / [param period] ([RankingData] CATEGORY_* / PERIOD_*).
signal ranking_requested(category: String, period: String)

## Altura do painel (px).
const HEIGHT_PX: float = 1100.0
## Cores das três primeiras posições.
const PODIUM_COLORS: Array[Color] = [Color(1.0, 0.84, 0.3), Color(0.85, 0.88, 0.95), Color(0.9, 0.6, 0.35)]
const KEY_COLOR: Color = Color(1, 1, 1, 0.7)
const VALUE_COLOR: Color = Color(1, 0.85, 0.6)
## Abas de cima: id → texto ("guild" abre as sub-abas).
const _TOP_TABS: Dictionary[String, String] = {"monsters": "Monstros", "pvp": "PvP", "guild": "Guilda", "colosseum": "Coliseu"}
const _GUILD_TABS: Dictionary[String, String] = {"monsters": "Monstros", "pvp": "PvP"}
## Sub-abas do Coliseu ([JOGO-28]): um ranking por modo.
const _COLOSSEUM_TABS: Dictionary[String, String] = {
	RankingData.CATEGORY_COLOSSEUM_1X1: "1x1", RankingData.CATEGORY_COLOSSEUM_2X2: "2x2", RankingData.CATEGORY_COLOSSEUM_3X3: "3x3",
}
const _PERIOD_TABS: Dictionary[String, String] = {
	RankingData.PERIOD_DAILY: "Diário", RankingData.PERIOD_WEEKLY: "Semanal", RankingData.PERIOD_GLOBAL: "Global",
}

## Aba de cima escolhida ("monsters", "pvp" ou "guild"), sub-aba da guilda e período.
var _top: String = "monsters"
var _guild_kind: String = "monsters"
## Sub-aba do Coliseu (categoria colosseum_*).
var _colosseum_kind: String = RankingData.CATEGORY_COLOSSEUM_1X1
var _period: String = RankingData.PERIOD_DAILY

var _top_buttons: Dictionary[String, Button] = {}
var _guild_buttons: Dictionary[String, Button] = {}
var _period_buttons: Dictionary[String, Button] = {}
var _guild_row: HBoxContainer = null
var _colosseum_buttons: Dictionary[String, Button] = {}
var _colosseum_row: HBoxContainer = null
var _info: Label = null
var _list: VBoxContainer = null
var _me_label: Label = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Ranking")
	body.add_child(_make_tabs(_TOP_TABS, _top_buttons, _on_top_tab))
	_guild_row = _make_tabs(_GUILD_TABS, _guild_buttons, _on_guild_tab)
	body.add_child(_guild_row)
	_colosseum_row = _make_tabs(_COLOSSEUM_TABS, _colosseum_buttons, _on_colosseum_tab)
	body.add_child(_colosseum_row)
	body.add_child(_make_tabs(_PERIOD_TABS, _period_buttons, _on_period_tab))
	_info = PixelMenuPanel.make_label("", KEY_COLOR)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_info)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_me_label = PixelMenuPanel.make_label("", VALUE_COLOR)
	_me_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_me_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_me_label)
	_refresh_tabs()
	visibility_changed.connect(func() -> void:
		if visible:
			_request())


## Categoria escolhida agora ([RankingData] CATEGORY_*).
func current_category() -> String:
	if _top == "colosseum":
		return _colosseum_kind
	if _top != "guild":
		return _top
	return RankingData.CATEGORY_GUILD_MONSTERS if _guild_kind == "monsters" else RankingData.CATEGORY_GUILD_PVP


## Mostra a tabela que chegou (ignora resposta atrasada de outra aba). [param has_guild] = estou numa guilda.
func show_ranking(ranking: RankingData, has_guild: bool) -> void:
	if ranking.category != current_category() or ranking.period != _period:
		return
	_clear_list()
	var guild: bool = RankingData.is_guild(ranking.category)
	var xp: bool = ranking.category == RankingData.CATEGORY_MONSTERS or ranking.category == RankingData.CATEGORY_GUILD_MONSTERS
	var measure: String = "XP de monstros" if xp else "Jogadores mortos"
	if RankingData.is_colosseum(ranking.category):
		# Global = pontos atuais do modo; diário/semanal = pontos ganhos no período ([JOGO-28]).
		measure = "Pontos de ranking" if ranking.period == RankingData.PERIOD_GLOBAL else "Pontos ganhos"
	_info.text = "%s · %s" % [measure, _reset_text(ranking.resets_in)]
	if ranking.rows.is_empty():
		var empty: Label = PixelMenuPanel.make_label("Ninguém pontuou ainda.", KEY_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
	for row: RankingData.Row in ranking.rows:
		_add_row(row)
	if guild and not has_guild:
		_me_label.text = "Você não está numa guilda."
	elif ranking.me == null:
		_me_label.text = "Sua guilda ainda não pontuou aqui." if guild else "Você ainda não pontuou aqui."
	else:
		_me_label.text = "%s: %dº · %s" % ["Sua guilda" if guild else "Você", ranking.me.rank, _value_text(ranking.me.value)]


func _request() -> void:
	_clear_list()
	_info.text = "Carregando…"
	_me_label.text = ""
	ranking_requested.emit(current_category(), _period)


func _on_top_tab(id: String) -> void:
	_top = id
	_refresh_tabs()
	_request()


func _on_guild_tab(id: String) -> void:
	_guild_kind = id
	_refresh_tabs()
	_request()


func _on_colosseum_tab(id: String) -> void:
	_colosseum_kind = id
	_refresh_tabs()
	_request()


func _on_period_tab(id: String) -> void:
	_period = id
	_refresh_tabs()
	_request()


## Uma linha de abas: um botão por item de [param tabs] (id → texto), guardados em [param store].
func _make_tabs(tabs: Dictionary[String, String], store: Dictionary[String, Button], on_pressed: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for id: String in tabs.keys():
		var button: Button = PixelMenuPanel.make_button(tabs[id])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_pressed.bind(id))
		row.add_child(button)
		store[id] = button
	return row


## Acende a aba escolhida de cada linha (✓) e apaga as outras; sub-abas da guilda só com "Guilda".
func _refresh_tabs() -> void:
	_mark(_top_buttons, _TOP_TABS, _top)
	_mark(_guild_buttons, _GUILD_TABS, _guild_kind)
	_mark(_period_buttons, _PERIOD_TABS, _period)
	_mark(_colosseum_buttons, _COLOSSEUM_TABS, _colosseum_kind)
	_guild_row.visible = _top == "guild"
	_colosseum_row.visible = _top == "colosseum"


func _mark(buttons: Dictionary[String, Button], texts: Dictionary[String, String], selected: String) -> void:
	for id: String in buttons.keys():
		var on: bool = id == selected
		buttons[id].text = ("✓ " + texts[id]) if on else texts[id]
		buttons[id].modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.5)


## Linha "posição. nome ........ valor" (pódio colorido).
func _add_row(row: RankingData.Row) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var color: Color = PODIUM_COLORS[row.rank - 1] if row.rank >= 1 and row.rank <= PODIUM_COLORS.size() else Color(1, 1, 1)
	var name_label: Label = PixelMenuPanel.make_label("%d. %s" % [row.rank, row.name], color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(name_label)
	var value_label: Label = PixelMenuPanel.make_label(_value_text(row.value), VALUE_COLOR)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(value_label)
	_list.add_child(line)


## Valor inteiro com ponto de milhar (XP vem com 1 casa; o ranking mostra sem).
static func _value_text(value: float) -> String:
	return InventoryView.format_gold(floori(value))


## "vira em 5 h 12 min" (diário/semanal) ou "desde 17/11/2026" (global).
static func _reset_text(seconds: int) -> String:
	if seconds <= 0:
		return "desde 17/11/2026"
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours >= 24:
		return "vira em %d d %d h" % [hours / 24, hours % 24]
	if hours > 0:
		return "vira em %d h %d min" % [hours, minutes]
	return "vira em %d min" % maxi(1, minutes)


func _clear_list() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
