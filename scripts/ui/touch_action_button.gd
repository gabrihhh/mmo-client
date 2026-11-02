class_name TouchActionButton
extends Control
## Botão de ação por toque: ataque simples e cartas de habilidade. Ver mmo-docs [JOGO-02], [CLI-08].
##
## Gestos:
## - toque rápido (sem arrastar)          → [signal tapped]
## - segurar e arrastar além do limite     → [signal aim_started], depois [signal aim_moved] a cada movimento
## - soltar arrastando                     → [signal aim_released] com o deslocamento final
## - soltar com o dedo de volta no botão   → [signal aim_cancelled] (desistiu de mirar)
## O deslocamento é em pixels da tela a partir do centro do botão (y negativo = para cima/frente).
##
## MULTITOQUE: como o [TouchJoystick], lê os toques em [method _input] e acompanha o próprio dedo.

## Tocou e soltou sem arrastar.
signal tapped
## Começou a mirar (arrastou além de [constant DRAG_THRESHOLD_PX]).
signal aim_started
## Mira mudou; [param offset] em px a partir do centro do botão.
signal aim_moved(offset: Vector2)
## Soltou mirando; [param offset] final em px.
signal aim_released(offset: Vector2)
## Soltou com o dedo de volta em cima do botão: cancela a mira.
signal aim_cancelled

## Distância (px) que o dedo precisa andar para virar "mira" em vez de toque.
const DRAG_THRESHOLD_PX: float = 24.0

## Formato: carta (retângulo arredondado) ou círculo (ataque, menu).
enum Shape { CARD, CIRCLE }

@export var shape: Shape = Shape.CARD
## Texto principal (nome curto da habilidade/ação).
@export var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value
## Texto pequeno embaixo (ex.: slot de origem: "Arma", "Pés").
@export var caption: String = "":
	set(value):
		caption = value
		if _caption_label != null:
			_caption_label.text = value
@export var fill_color: Color = Color(0.22, 0.29, 0.4, 0.92)
@export var pressed_color: Color = Color(0.34, 0.43, 0.58, 0.95)
@export var border_color: Color = Color(1.0, 0.85, 0.6, 1.0)
## Moldura da carta (sempre visível em [constant Shape.CARD]; dentro dela vai a imagem da habilidade).
@export var frame_color: Color = Color(0.62, 0.68, 0.8, 0.9)
## Espessura da moldura da carta, em px.
@export var frame_width: int = 3
@export var font_size: int = 26
## Desligado: ignora toques (ex.: menu aberto).
@export var enabled: bool = true

var _touch_index: int = -1
var _aiming: bool = false
var _label: Label = null
var _caption_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = _make_label(text, font_size, 0.0, 1.0 if caption.is_empty() else 0.72)
	_caption_label = _make_label(caption, maxi(14, font_size - 10), 0.66, 0.96)


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _contains(touch.position):
			_touch_index = touch.index
			_aiming = false
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_finish(touch.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		var offset: Vector2 = drag.position - _center()
		if not _aiming and offset.length() > DRAG_THRESHOLD_PX:
			_aiming = true
			aim_started.emit()
		if _aiming:
			aim_moved.emit(offset)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# App em segundo plano / botão escondido: solta sem disparar nada.
	if (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED) and _touch_index != -1:
		if _aiming:
			aim_cancelled.emit()
		_touch_index = -1
		_aiming = false
		queue_redraw()


func _draw() -> void:
	var held: bool = _touch_index != -1
	var color: Color = pressed_color if held else fill_color
	if not enabled:
		color.a *= 0.45
	if shape == Shape.CIRCLE:
		var radius: float = minf(size.x, size.y) / 2.0
		draw_circle(size / 2.0, radius, color)
		if held:
			draw_arc(size / 2.0, radius - 2.0, 0.0, TAU, 48, border_color, 3.0, true)
	else:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(16)
		# Moldura sempre visível; pressionada fica dourada e um pouco mais grossa.
		box.set_border_width_all(frame_width + 1 if held else frame_width)
		box.border_color = border_color if held else frame_color
		if not enabled:
			box.border_color.a *= 0.45
		draw_style_box(box, Rect2(Vector2.ZERO, size))


func _finish(release_position: Vector2) -> void:
	var offset: Vector2 = release_position - _center()
	if not _aiming:
		tapped.emit()
	elif _contains(release_position):
		aim_cancelled.emit()
	else:
		aim_released.emit(offset)
	_touch_index = -1
	_aiming = false
	queue_redraw()


func _center() -> Vector2:
	return global_position + size / 2.0


func _contains(point: Vector2) -> bool:
	if shape == Shape.CIRCLE:
		return point.distance_to(_center()) <= minf(size.x, size.y) / 2.0
	return get_global_rect().has_point(point)


## Label centralizado na faixa vertical [param top]..[param bottom] (frações da altura do botão).
func _make_label(value: String, label_font_size: int, top: float, bottom: float) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Quebra só entre palavras (nunca no meio: "Dispara-da").
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", label_font_size)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.offset_left = 4.0
	label.offset_right = -4.0
	add_child(label)
	return label
