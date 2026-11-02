class_name TouchJoystick
extends Control
## Joystick virtual de toque (controle principal no Android/iOS).
## Não se chama VirtualJoystick porque o Godot 4.7 já tem uma classe nativa com esse nome.
##
## Leia [member output]: vetor de -1 a 1 em cada eixo (y negativo = para cima/frente).
## Desenhado via _draw, sem texturas. No desktop funciona com o mouse
## (input_devices/pointing/emulate_touch_from_mouse).

## Raio da base, em pixels.
@export var base_radius: float = 90.0
## Raio do botão que o dedo arrasta, em pixels.
@export var knob_radius: float = 40.0
## Fração do raio ignorada no centro (evita drift).
@export_range(0.0, 0.9) var dead_zone: float = 0.15
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.5)

## Direção atual do joystick, comprimento entre 0 e 1.
var output: Vector2 = Vector2.ZERO

## Índice do dedo que está controlando; -1 = nenhum.
var _touch_index: int = -1
## Deslocamento do botão em relação ao centro, em pixels.
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * base_radius * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_update_knob(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
			accept_event()


func _notification(what: int) -> void:
	# Solta o joystick se o app for para segundo plano ou o controle sumir.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	draw_circle(center, base_radius, base_color)
	draw_circle(center + _knob_offset, knob_radius, knob_color)


func _update_knob(local_position: Vector2) -> void:
	_knob_offset = (local_position - size / 2.0).limit_length(base_radius)
	var raw: Vector2 = _knob_offset / base_radius
	if raw.length() < dead_zone:
		output = Vector2.ZERO
	else:
		# Reescala para que a saída comece em 0 logo após a dead zone.
		output = raw.normalized() * inverse_lerp(dead_zone, 1.0, raw.length())
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()
