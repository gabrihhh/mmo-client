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

## Formato: carta (retângulo arredondado) ou círculo (ataque, "Desfocar").
enum Shape { CARD, CIRCLE }
## Símbolo desenhado no centro do botão (por código, sem textura). NONE = só o texto.
enum Icon { NONE, SWORD }

@export var shape: Shape = Shape.CARD
## Símbolo no centro (ataque = espada).
@export var icon: Icon = Icon.NONE
## Risca o símbolo com um traço na diagonal ("Desfocar" = espada riscada: parar de atacar).
@export var icon_crossed: bool = false
## Aro metálico em volta do círculo ([constant Shape.CIRCLE]).
@export var rim_color: Color = Color(0.85, 0.66, 0.32, 1.0)
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
## Desligado: ignora toques (ex.: menu aberto, "Desfocar" sem alvo) e fica apagado (fundo e texto).
@export var enabled: bool = true:
	set(value):
		enabled = value
		if _label != null:
			_update_cooldown_visual()
## Cor do "relógio" de recarga (setor escuro que vai encolhendo).
@export var cooldown_color: Color = Color(0.0, 0.0, 0.0, 0.62)

var _touch_index: int = -1
var _aiming: bool = false
var _label: Label = null
var _caption_label: Label = null
var _cooldown_label: Label = null
## Recarga: instante (ms do Time.get_ticks_msec) em que fica pronta e a duração total (s). 0 = pronta.
var _cooldown_end_ms: int = 0
var _cooldown_total_s: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = _make_label(text, font_size, 0.0, 1.0 if caption.is_empty() else 0.72)
	_caption_label = _make_label(caption, maxi(14, font_size - 10), 0.66, 0.96)
	_cooldown_label = _make_label("", font_size + 10, 0.0, 1.0)
	_cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	_cooldown_label.add_theme_constant_override("outline_size", 6)
	_cooldown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	set_process(false)
	_update_cooldown_visual()


## Começa a recarga: [param remaining] segundos de [param total]. O botão fica apagado com o relógio
## girando até ficar pronto. [param remaining] <= 0 limpa.
func set_cooldown(remaining: float, total: float) -> void:
	if remaining <= 0.0 or total <= 0.0:
		_cooldown_end_ms = 0
		_cooldown_total_s = 0.0
	else:
		_cooldown_end_ms = Time.get_ticks_msec() + int(remaining * 1000.0)
		_cooldown_total_s = total
	set_process(_cooldown_end_ms != 0)
	_update_cooldown_visual()


## Segundos que faltam para ficar pronto (0 = pronto).
func cooldown_remaining() -> float:
	if _cooldown_end_ms == 0:
		return 0.0
	return maxf(0.0, float(_cooldown_end_ms - Time.get_ticks_msec()) / 1000.0)


func _process(_delta: float) -> void:
	if cooldown_remaining() <= 0.0:
		_cooldown_end_ms = 0
		set_process(false)
	_update_cooldown_visual()


## Opacidade reduzida no texto (recarregando ou desligado) e contagem regressiva enquanto recarrega.
func _update_cooldown_visual() -> void:
	var remaining: float = cooldown_remaining()
	var cooling: bool = remaining > 0.0
	var faded: Color = Color(1, 1, 1, 0.25) if cooling or not enabled else Color.WHITE
	_label.modulate = faded
	_caption_label.modulate = faded
	# Abaixo de 1 s mostra uma casa decimal (ex.: "0.4"); acima, segundos inteiros arredondados para cima.
	_cooldown_label.text = ("%.1f" % remaining if remaining < 1.0 else str(ceili(remaining))) if cooling else ""
	queue_redraw()


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
	var cooling: bool = cooldown_remaining() > 0.0
	if shape == Shape.CIRCLE:
		_draw_round_button(color, held)
	else:
		color = _dim(color)
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(16)
		# Moldura sempre visível; pressionada fica dourada e um pouco mais grossa.
		box.set_border_width_all(frame_width + 1 if held else frame_width)
		box.border_color = border_color if held else frame_color
		if not enabled:
			box.border_color.a *= 0.45
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	if icon == Icon.SWORD:
		_draw_sword(held)
	if cooling:
		_draw_cooldown_clock(cooldown_remaining() / _cooldown_total_s)


## Leva [param points] (em unidades de raio, espada em pé) para a tela: escala por [param r], gira
## [param turn] rad e centraliza em [param center].
func _place(points: PackedVector2Array, center: Vector2, r: float, turn: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for point: Vector2 in points:
		out.append(center + (point * r).rotated(turn))
	return out


## Multiplica a opacidade de [param color] quando desligado/recarregando (tudo "apagado" junto).
func _dim(color: Color) -> Color:
	var faded: Color = color
	if not enabled or cooldown_remaining() > 0.0:
		faded.a *= 0.45
	return faded


## Botão redondo: sombra embaixo, aro metálico, anel escuro, miolo na cor [param color] e um brilho
## na metade de cima (parece abaulado). Apertado: aro mais claro.
func _draw_round_button(color: Color, held: bool) -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	draw_circle(center + Vector2(0.0, radius * 0.05), radius * 0.98, _dim(Color(0, 0, 0, 0.35)))
	draw_circle(center, radius * 0.96, _dim(rim_color.lightened(0.25) if held else rim_color))
	# Filete claro no alto do aro (luz de cima).
	draw_arc(center, radius * 0.92, PI * 1.15, PI * 1.85, 24, _dim(Color(1, 0.95, 0.8, 0.6)), maxf(1.5, radius * 0.04), true)
	draw_circle(center, radius * 0.86, _dim(Color(0.14, 0.08, 0.05, 1.0)))
	draw_circle(center, radius * 0.8, _dim(color))
	var shine: Color = color.lightened(0.35)
	shine.a = 0.35
	draw_circle(center + Vector2(0.0, -radius * 0.24), radius * 0.52, _dim(shine))


## Espada na diagonal (ponta para cima/direita): lâmina prateada com fio mais escuro, guarda e pomo
## dourados, cabo de couro. Com [member icon_crossed], um traço por cima na outra diagonal.
func _draw_sword(held: bool) -> void:
	var center: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 * (0.95 if shape == Shape.CIRCLE else 0.6)
	var turn: float = PI / 4.0
	var outline: Color = _dim(Color(0.1, 0.06, 0.04, 0.95))
	var line_width: float = maxf(1.5, r * 0.05)
	# Pontos em "unidades de raio", espada em pé (y negativo = ponta); [method _place] gira 45° e escala.
	var blade: PackedVector2Array = _place(PackedVector2Array([Vector2(0, -0.72), Vector2(0.11, -0.55), Vector2(0.11, 0.18), Vector2(-0.11, 0.18), Vector2(-0.11, -0.55)]), center, r, turn)
	var blade_shadow: PackedVector2Array = _place(PackedVector2Array([Vector2(0, -0.72), Vector2(0.11, -0.55), Vector2(0.11, 0.18), Vector2(0, 0.18)]), center, r, turn)
	var guard: PackedVector2Array = _place(PackedVector2Array([Vector2(-0.34, 0.16), Vector2(0.34, 0.16), Vector2(0.3, 0.27), Vector2(-0.3, 0.27)]), center, r, turn)
	var grip: PackedVector2Array = _place(PackedVector2Array([Vector2(-0.06, 0.27), Vector2(0.06, 0.27), Vector2(0.06, 0.54), Vector2(-0.06, 0.54)]), center, r, turn)
	var steel: Color = Color(0.93, 0.94, 0.97) if not held else Color(1, 1, 1)
	var gold: Color = Color(0.95, 0.76, 0.32)
	for part: Array in [[blade, steel], [blade_shadow, Color(0.68, 0.71, 0.78)], [guard, gold], [grip, Color(0.42, 0.25, 0.12)]]:
		var polygon: PackedVector2Array = part[0]
		var fill: Color = part[1]
		draw_colored_polygon(polygon, _dim(fill))
		var closed: PackedVector2Array = polygon.duplicate()
		closed.append(polygon[0])
		draw_polyline(closed, outline, line_width, true)
	# Fio central da lâmina e faixas do cabo.
	var ridge: PackedVector2Array = _place(PackedVector2Array([Vector2(0, -0.6), Vector2(0, 0.14)]), center, r, turn)
	draw_line(ridge[0], ridge[1], _dim(Color(0.55, 0.58, 0.66, 0.9)), maxf(1.0, r * 0.025), true)
	for y: float in [0.35, 0.45]:
		var wrap: PackedVector2Array = _place(PackedVector2Array([Vector2(-0.06, y), Vector2(0.06, y)]), center, r, turn)
		draw_line(wrap[0], wrap[1], outline, maxf(1.0, r * 0.03), true)
	var pommel: Vector2 = _place(PackedVector2Array([Vector2(0, 0.61)]), center, r, turn)[0]
	draw_circle(pommel, r * 0.09, outline)
	draw_circle(pommel, r * 0.065, _dim(gold))
	if icon_crossed:
		# Traço na outra diagonal (de cima/esquerda para baixo/direita), com contorno escuro.
		var from: Vector2 = center + Vector2(-0.62, -0.62) * r
		var to: Vector2 = center + Vector2(0.62, 0.62) * r
		draw_line(from, to, outline, r * 0.2, true)
		draw_line(from, to, _dim(Color(0.98, 0.93, 0.86)), r * 0.11, true)


## Relógio de recarga: setor escuro que começa no "meio-dia" e cobre a fração [param fraction] que falta,
## no sentido horário, recortado no formato do botão.
func _draw_cooldown_clock(fraction: float) -> void:
	var center: Vector2 = size / 2.0
	var radius: float = size.length()  # grande o bastante para cobrir o retângulo inteiro
	var start: float = -PI / 2.0 + TAU * (1.0 - clampf(fraction, 0.0, 1.0))
	var finish: float = PI * 1.5
	var sector: PackedVector2Array = [center]
	var steps: int = maxi(2, int(48.0 * fraction))
	for i: int in range(steps + 1):
		var angle: float = lerpf(start, finish, float(i) / float(steps))
		sector.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var shape_polygon: PackedVector2Array = _shape_polygon()
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(sector, shape_polygon):
		draw_colored_polygon(piece, cooldown_color)


## Contorno do botão como polígono (retângulo ou círculo), para recortar o relógio.
func _shape_polygon() -> PackedVector2Array:
	if shape == Shape.CIRCLE:
		var points: PackedVector2Array = []
		var radius: float = minf(size.x, size.y) / 2.0 * 0.86
		for i: int in range(48):
			var angle: float = TAU * float(i) / 48.0
			points.append(size / 2.0 + Vector2(cos(angle), sin(angle)) * radius)
		return points
	var inset: float = float(frame_width)
	return PackedVector2Array([
		Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(size.x - inset, size.y - inset), Vector2(inset, size.y - inset),
	])


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
