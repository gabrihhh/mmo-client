class_name ColosseumPanel
extends PixelMenuPanel
## Menu → "Coliseu" ([JOGO-28]): escolher o **modo** (1x1 / 2x2 / 3x3) e a **build** (um conjunto por slot: mão,
## cabeça, peito, pés; tocar troca o conjunto) e entrar/sair da fila. Mostra o papel que a mão dá (Curandeiro =
## healer, o resto = DPS; o 1x1 não aceita healer), o ranking em cada modo, os Pontos de Coliseu, quantos esperam
## em cada fila, as partidas premiadas hoje e o bloqueio (abandono/recusas). A fila só se entra nas pedras da praça
## (o servidor confere e recusa com aviso). Tudo vem do servidor ([ColosseumData.Info]).

## Abriu o painel: pede o estado ([method Network.send_colosseum_open]).
signal open_requested
## Entrar na fila do [param mode] com a [param build] (slot → conjunto).
signal queue_requested(mode: String, build: Dictionary[String, String])
## Sair da fila.
signal leave_requested

## Altura do painel (px).
const HEIGHT_PX: float = 1120.0
const DIM_COLOR: Color = Color(1, 1, 1, 0.7)
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const WARN_COLOR: Color = Color(1.0, 0.55, 0.45)
const OK_COLOR: Color = Color(0.5, 1.0, 0.5)
## Papéis na tela.
const _ROLE_TEXT: Dictionary[String, String] = {"dps": "DPS", "healer": "Healer"}

var _info: ColosseumData.Info = null
var _mode: String = "1x1"
## Build escolhida (slot → conjunto); começa toda Mago.
var _build: Dictionary[String, String] = {"hand": "Mago", "head": "Mago", "chest": "Mago", "feet": "Mago"}
var _mode_buttons: Dictionary[String, Button] = {}
var _slot_buttons: Dictionary[String, Button] = {}
var _role: Label = null
var _status: Label = null
var _queue_button: Button = null
var _message: Label = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Coliseu")
	_status = PixelMenuPanel.make_label("", DIM_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	var modes: HBoxContainer = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	for mode: String in ColosseumData.MODES:
		var button: Button = PixelMenuPanel.make_button(mode)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_mode.bind(mode))
		modes.add_child(button)
		_mode_buttons[mode] = button
	body.add_child(modes)
	body.add_child(PixelMenuPanel.make_label("Build (toque para trocar o conjunto):", DIM_COLOR))
	for slot: String in ColosseumData.SLOTS:
		var button: Button = PixelMenuPanel.make_button("", true)
		button.pressed.connect(_next_set.bind(slot))
		body.add_child(button)
		_slot_buttons[slot] = button
	_role = PixelMenuPanel.make_label("", GOLD_COLOR)
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_role)
	_queue_button = PixelMenuPanel.make_button("Entrar na fila")
	_queue_button.pressed.connect(_on_queue_pressed)
	body.add_child(_queue_button)
	_message = PixelMenuPanel.make_label("", OK_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_message)
	body.add_child(PixelMenuPanel.make_label("Entre na fila nas pedras da praça. Na arena todos ficam no nível 20 com os itens +0 da build; nada dos seus itens é usado nem perdido.", DIM_COLOR))
	_refresh()
	visibility_changed.connect(func() -> void:
		if visible:
			_message.text = ""
			open_requested.emit())


## Estado novo vindo do servidor (ranking, fila, bloqueio).
func show_info(info: ColosseumData.Info) -> void:
	_info = info
	if not info.queued.is_empty():
		_mode = info.queued
	_refresh()


## Aviso curto embaixo do botão (recusa do servidor, partida que caiu...).
func show_message(text: String, warning: bool = true) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", WARN_COLOR if warning else OK_COLOR)


## Papel da build atual: a mão decide.
func _role_id() -> String:
	return "healer" if _build["hand"] == ColosseumData.HEALER_SET else "dps"


func _set_mode(mode: String) -> void:
	if _info != null and not _info.queued.is_empty():
		return
	_mode = mode
	_message.text = ""
	_refresh()


## Troca o conjunto do [param slot] pelo próximo da lista.
func _next_set(slot: String) -> void:
	if _info != null and not _info.queued.is_empty():
		return
	var index: int = ColosseumData.SETS.find(_build[slot])
	_build[slot] = ColosseumData.SETS[(index + 1) % ColosseumData.SETS.size()]
	_message.text = ""
	_refresh()


func _on_queue_pressed() -> void:
	if _info != null and not _info.queued.is_empty():
		leave_requested.emit()
		return
	if _mode == "1x1" and _role_id() == "healer":
		show_message("O 1x1 não aceita Curandeiro na mão.")
		return
	var build: Dictionary[String, String] = _build.duplicate()
	queue_requested.emit(_mode, build)


func _refresh() -> void:
	var queued: bool = _info != null and not _info.queued.is_empty()
	for mode: String in _mode_buttons:
		var waiting: int = 0 if _info == null else _info.waiting.get(mode, 0)
		var rating: int = 0 if _info == null else _info.rating.get(mode, 0)
		_mode_buttons[mode].text = ("✓ " if mode == _mode else "") + "%s" % mode
		_mode_buttons[mode].tooltip_text = "Ranking %d · %d na fila" % [rating, waiting]
		_mode_buttons[mode].disabled = queued and mode != _mode
	for slot: String in _slot_buttons:
		_slot_buttons[slot].text = "%s: %s" % [ColosseumData.SLOT_NAMES[slot], _build[slot]]
		_slot_buttons[slot].disabled = queued
	var role: String = _role_id()
	_role.text = "Papel: %s" % _ROLE_TEXT[role]
	if _mode == "1x1" and role == "healer":
		_role.text += " (o 1x1 não aceita healer)"
	_queue_button.text = "Sair da fila" if queued else "Entrar na fila"
	if _info == null:
		_status.text = "Carregando…"
		return
	var lines: Array[String] = []
	lines.append("Ranking %s: %d  ·  Pontos de Coliseu: %d" % [_mode, _info.rating.get(_mode, 0), _info.points])
	lines.append("Na fila do %s: %d  ·  Partidas premiadas hoje: %d/%d" % [_mode, _info.waiting.get(_mode, 0), _info.rewards_today, _info.rewards_limit])
	if queued:
		lines.append("Procurando partida %s…" % _info.queued)
	if _info.ban_seconds > 0:
		lines.append("Coliseu bloqueado por mais %d min." % ceili(_info.ban_seconds / 60.0))
	_status.text = "\n".join(lines)
