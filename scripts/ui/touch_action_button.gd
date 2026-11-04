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

## Fração do raio do círculo que é o "miolo" do botão redondo pixel art (`round_button.png`): o relógio de
## recarga cobre só ele, não o aro dourado.
const CIRCLE_CORE_RATIO: float = 0.72

@export var shape: Shape = Shape.CARD
## Fundo do botão redondo (pixel art, [code]assets/ui/pixel/round_button.png[/code]), esticado no tamanho do botão.
## null = círculo liso na [member fill_color].
@export var button_texture: Texture2D = null
## Fundo do botão redondo enquanto apertado. null = usa [member button_texture].
@export var button_pressed_texture: Texture2D = null
## Símbolo pixel art: no centro do círculo (ataque = espada, "Desfocar" = espada riscada) ou, na carta com texto,
## à direita do texto (Menu = ☰). Desenhado sem filtro.
@export var icon_texture: Texture2D = null
## Lado do símbolo como fração do lado menor do botão (0,5 = metade).
@export_range(0.1, 1.0) var icon_size: float = 0.5
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
## Imagem da habilidade (pixel art, [ItemIcons]) no alto da carta, com o nome embaixo. null = só o texto.
## Desenhada sem filtro (pixels nítidos) e apagada junto com a carta em recarga/desligada.
@export var picture: Texture2D = null:
	set(value):
		picture = value
		if _label != null:
			_layout_labels()
			queue_redraw()
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label = _make_label(text, font_size, 0.0, 1.0 if caption.is_empty() else 0.72)
	_caption_label = _make_label(caption, maxi(14, font_size - 10), 0.66, 0.96)
	_layout_labels()
	_cooldown_label = _make_label("", font_size + 10, 0.0, 1.0)
	_cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	_cooldown_label.add_theme_constant_override("outline_size", 6)
	_cooldown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	set_process(false)
	_update_cooldown_visual()


## Com imagem: o nome desce para a faixa de baixo da carta (a imagem ocupa o alto) e a legenda some (a imagem já
## diz de onde vem a carta; não cabe tudo em 104 px).
func _layout_labels() -> void:
	_caption_label.visible = picture == null or shape != Shape.CARD
	# Carta com símbolo (Menu ☰): o texto fica na parte esquerda, o símbolo à direita ([method _icon_rect]).
	_label.anchor_right = 0.6 if icon_texture != null and shape == Shape.CARD else 1.0
	if picture != null and shape == Shape.CARD:
		_label.anchor_top = 0.62
		_label.anchor_bottom = 0.98
		_label.add_theme_font_size_override("font_size", maxi(12, font_size - 3))
		_label.add_theme_constant_override("outline_size", 4)
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	else:
		_label.anchor_top = 0.0
		_label.anchor_bottom = 1.0 if caption.is_empty() else 0.72
		_caption_label.anchor_top = 0.66
		_caption_label.anchor_bottom = 0.96
		_label.add_theme_font_size_override("font_size", font_size)


## Retângulo (px) da imagem na carta: quadrado no alto, centrado.
func _picture_rect() -> Rect2:
	var side: float = minf(size.x - 2.0 * (frame_width + 6.0), size.y * 0.58)
	return Rect2(Vector2((size.x - side) / 2.0, frame_width + 5.0), Vector2(side, side))


## Retângulo (px) do símbolo: centrado no círculo; na carta, centrado na faixa da direita (de 58% a 100% da largura).
func _icon_rect() -> Rect2:
	var side: float = minf(size.x, size.y) * icon_size
	var center: Vector2 = size / 2.0
	if shape == Shape.CARD:
		center.x = size.x * 0.79
	return Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side))


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
		if picture != null:
			var rect: Rect2 = _picture_rect()
			draw_rect(rect.grow(2.0), _dim(Color(0.05, 0.04, 0.08, 0.9)))
			draw_texture_rect(picture, rect, false, _dim(Color.WHITE))
	if icon_texture != null:
		draw_texture_rect(icon_texture, _icon_rect(), false, _dim(Color.WHITE))
	if cooling:
		_draw_cooldown_clock(cooldown_remaining() / _cooldown_total_s)


## Multiplica a opacidade de [param color] quando desligado/recarregando (tudo "apagado" junto).
func _dim(color: Color) -> Color:
	var faded: Color = color
	if not enabled or cooldown_remaining() > 0.0:
		faded.a *= 0.45
	return faded


## Botão redondo: a textura pixel art ([member button_texture], ou a de apertado) esticada no botão; sem textura,
## um círculo liso na cor [param color].
func _draw_round_button(color: Color, held: bool) -> void:
	var texture: Texture2D = button_pressed_texture if held and button_pressed_texture != null else button_texture
	if texture != null:
		var side: float = minf(size.x, size.y)
		draw_texture_rect(texture, Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), false, _dim(Color.WHITE))
	else:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, _dim(color))


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
		var radius: float = minf(size.x, size.y) / 2.0 * (CIRCLE_CORE_RATIO if button_texture != null else 1.0)
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
