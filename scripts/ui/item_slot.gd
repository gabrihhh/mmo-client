class_name ItemSlot
extends Control
## Um quadro de item do inventário ([CLI-10]): fundo escuro, moldura na cor do conjunto do item e o ícone pixel art
## no meio. Vazio: moldura apagada com o nome do slot ("Cabeça"). Toque = [signal pressed].
##
## Funciona dentro do [ScrollContainer] da mochila: o quadro **não segura** o toque (`MOUSE_FILTER_PASS`), então o
## arrasto chega ao ScrollContainer e rola a grade; e se o dedo andar mais que [constant DRAG_CANCEL_PX] o toque
## vira rolagem e **não** abre o item ao soltar. (Como [Button] ele parava o arrasto: a grade não rolava.)

## Tocou e soltou em cima do quadro, sem arrastar.
signal pressed

## Espessura da moldura, em px.
const BORDER_PX: int = 4
## Margem entre a moldura e o ícone, em px.
const ICON_MARGIN_PX: float = 10.0
## Quanto (px) o dedo pode andar e ainda contar como toque; mais que isso = rolando.
const DRAG_CANCEL_PX: float = 14.0
## Cor do fundo do quadro.
const BACKGROUND: Color = Color(0.11, 0.08, 0.06, 0.95)
## Moldura do slot vazio.
const EMPTY_BORDER: Color = Color(0.45, 0.36, 0.26, 0.55)

## Item mostrado; null = slot vazio.
var item: InventoryState.Item = null
## Texto do slot vazio (ex.: "Cabeça").
var empty_text: String = ""
## Desligado: ignora toques (vaga livre da mochila, ícone grande da ficha).
var disabled: bool = false

## Dedo apertado em cima do quadro (e ainda não virou rolagem).
var _held: bool = false
## Onde o toque começou (px, local).
var _press_position: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(104, 104)


## Mostra [param shown] (null = vazio, com [param empty_label] no meio).
func show_item(shown: InventoryState.Item, empty_label: String = "") -> void:
	item = shown
	empty_text = empty_label
	queue_redraw()


## Toque (o toque chega aqui como clique emulado). Não chama accept_event: o ScrollContainer pai também recebe e rola.
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed:
			_held = true
			_press_position = button.position
		elif _held:
			_held = false
			if Rect2(Vector2.ZERO, size).has_point(button.position):
				pressed.emit()
		queue_redraw()
	elif event is InputEventMouseMotion and _held:
		if (event as InputEventMouseMotion).position.distance_to(_press_position) > DRAG_CANCEL_PX:
			_held = false
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_held = false


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var held: bool = _held
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BACKGROUND.lightened(0.12) if held else BACKGROUND
	# Cantos retos: combina com as molduras pixel art.
	box.set_border_width_all(BORDER_PX)
	box.border_color = ItemIcons.set_color(item.set_name) if item != null else EMPTY_BORDER
	if held:
		box.border_color = box.border_color.lightened(0.3)
	# Sombra interna embaixo (parece um encaixe fundo).
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 3
	draw_style_box(box, rect)
	if item == null:
		var font: Font = get_theme_default_font()
		var font_size: int = 18
		var text_size: Vector2 = font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2((size.x - text_size.x) / 2.0, size.y / 2.0 + font_size / 3.0), empty_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.92, 0.8, 0.35))
		return
	var icon_texture: Texture2D = ItemIcons.item(item.item_id)
	var inner: Rect2 = rect.grow(-ICON_MARGIN_PX)
	if icon_texture != null:
		var side: float = minf(inner.size.x, inner.size.y)
		draw_texture_rect(icon_texture, Rect2(inner.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false)
	else:
		draw_string(get_theme_default_font(), inner.position + Vector2(0, inner.size.y / 2.0), item.name,
			HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, Color.WHITE)
