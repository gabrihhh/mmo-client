class_name ItemSlot
extends Button
## Um quadro de item do inventário ([CLI-10]): fundo escuro, moldura na cor do conjunto do item e o ícone pixel art
## no meio. Vazio: moldura apagada com o nome do slot ("Cabeça"). Toque = [signal BaseButton.pressed].
##
## É um [Button] (sem estilo próprio, desenho em [method _draw]) para funcionar com toque dentro do
## [ScrollContainer] da mochila (arrastar rola, tocar aperta).

## Espessura da moldura, em px.
const BORDER_PX: int = 4
## Margem entre a moldura e o ícone, em px.
const ICON_MARGIN_PX: float = 10.0
## Cor do fundo do quadro.
const BACKGROUND: Color = Color(0.11, 0.08, 0.06, 0.95)
## Moldura do slot vazio.
const EMPTY_BORDER: Color = Color(0.45, 0.36, 0.26, 0.55)

## Item mostrado; null = slot vazio.
var item: InventoryState.Item = null
## Texto do slot vazio (ex.: "Cabeça").
var empty_text: String = ""


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(104, 104)


## Mostra [param shown] (null = vazio, com [param empty_label] no meio).
func show_item(shown: InventoryState.Item, empty_label: String = "") -> void:
	item = shown
	empty_text = empty_label
	tooltip_text = shown.name if shown != null else empty_label
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var held: bool = is_pressed() or (button_pressed and toggle_mode)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BACKGROUND.lightened(0.12) if held else BACKGROUND
	box.set_corner_radius_all(12)
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
