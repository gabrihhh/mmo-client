class_name ColosseumFoundPanel
extends PanelContainer
## Janela "Partida encontrada — Aceitar / Recusar" do Coliseu ([JOGO-28]): no alto da tela (como os convites,
## [RequestPanel]), com o modo, o tempo que falta (15 s) e quantos já aceitaram. **Não pausa o jogo.** Aceitar
## mantém a janela ("Esperando os outros…") até a partida começar ou cair; recusar ou deixar o tempo acabar conta
## como recusa no servidor (2 seguidas = 2 min sem fila). A [Hud] cria e repassa a resposta para o [Network].

## Respondeu: [param accept] = Aceitar.
signal answered(accept: bool)

## Largura (px no espaço de referência 720×1280) e distância do topo (logo abaixo da linha de XP).
const WIDTH_PX: float = 640.0
const TOP_PX: float = 230.0

var _label: Label = null
var _accept: Button = null
var _decline: Button = null
var _mode: String = ""
var _seconds_left: float = 0.0
var _accepted: int = 0
var _total: int = 0
var _answered: bool = false


func _init() -> void:
	theme_type_variation = &"PixelPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP_PX
	custom_minimum_size = Vector2(WIDTH_PX, 0.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	_label = PixelMenuPanel.make_label("")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	_accept = PixelMenuPanel.make_button("Aceitar")
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.pressed.connect(_answer.bind(true))
	row.add_child(_accept)
	_decline = PixelMenuPanel.make_button("Recusar")
	_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline.pressed.connect(_answer.bind(false))
	row.add_child(_decline)
	set_process(false)


## Chegou "Partida encontrada" do [param mode] com [param seconds] para aceitar e [param total] jogadores.
func open(mode: String, seconds: int, total: int) -> void:
	_mode = mode
	_seconds_left = float(seconds)
	_accepted = 0
	_total = total
	_answered = false
	_accept.disabled = false
	_decline.disabled = false
	visible = true
	set_process(true)
	_refresh()


## Quantos já aceitaram (mensagem do servidor).
func set_accepted(accepted: int, total: int) -> void:
	_accepted = accepted
	_total = total
	_refresh()


## A partida começou ou caiu: some.
func close() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_refresh()
	# O servidor decide o fim do prazo; um pouco depois dele, a janela some mesmo sem resposta.
	if _seconds_left <= 0.0 and not _answered:
		close()


func _answer(accept: bool) -> void:
	if _answered:
		return
	_answered = true
	_accept.disabled = true
	_decline.disabled = true
	answered.emit(accept)
	if not accept:
		close()
	_refresh()


func _refresh() -> void:
	var text: String = "Partida do Coliseu encontrada (%s)!\n%d s" % [_mode, ceili(_seconds_left)]
	if _total > 0:
		text += "  ·  %d/%d aceitaram" % [_accepted, _total]
	if _answered:
		text += "\nEsperando os outros…"
	_label.text = text
