class_name ItemSlot
extends Control
## Um quadro de item do inventário ([CLI-10]): fundo escuro, moldura na cor do conjunto do item e o ícone pixel art
## no meio. Vazio: moldura apagada com o nome do slot ("Cabeça"). Toque = [signal pressed].
##
## Funciona dentro do [ScrollContainer] da mochila: o quadro **não segura** o toque (`MOUSE_FILTER_PASS`), então o
## arrasto chega ao ScrollContainer e rola a grade; e se o dedo andar mais que [constant DRAG_CANCEL_PX] o toque
## vira rolagem e **não** abre o item ao soltar. (Como [Button] ele parava o arrasto: a grade não rolava.)
##
## **Arrastar o item** ([member draggable], [CLI-10]): segurar o dedo parado [constant HOLD_TO_DRAG_S] s "pega" o
## item ([signal drag_started]); daí em diante o quadro segura o toque (a mochila não rola) e avisa por onde o dedo
## anda ([signal drag_moved]) e onde soltou ([signal drag_ended], posições globais). Quem decide o que acontece é o
## [InventoryView]. Deslizar logo de cara continua sendo rolagem.

## Tocou e soltou em cima do quadro, sem arrastar.
signal pressed
## Segurou parado e pegou o item para arrastar ([member draggable]).
signal drag_started
## Arrastando: o dedo está em [param global_position] (tela).
signal drag_moved(global_position: Vector2)
## Soltou o item arrastado em [param global_position] (tela).
signal drag_ended(global_position: Vector2)

## Espessura da moldura, em px.
const BORDER_PX: int = 4
## Margem entre a moldura e o ícone, em px.
const ICON_MARGIN_PX: float = 10.0
## Quanto (px) o dedo pode andar e ainda contar como toque; mais que isso = rolando.
const DRAG_CANCEL_PX: float = 14.0
## Quanto tempo (s) segurando parado até pegar o item para arrastar.
const HOLD_TO_DRAG_S: float = 0.25
## Cor do fundo do quadro.
const BACKGROUND: Color = Color(0.11, 0.08, 0.06, 0.95)
## Moldura do slot vazio.
const EMPTY_BORDER: Color = Color(0.45, 0.36, 0.26, 0.55)
## Moldura de alvo ao arrastar: pode soltar / não pode.
const DROP_OK: Color = Color(0.45, 0.95, 0.45)
const DROP_NO: Color = Color(0.95, 0.35, 0.3)
## Cor do "+N" (nível de melhoria, [JOGO-16]).
const LEVEL_COLOR: Color = Color(1.0, 0.84, 0.3)
## Transparência do item enquanto está sendo arrastado (fica o "buraco" de onde saiu).
const DRAGGING_ALPHA: float = 0.25

## Item mostrado; null = slot vazio.
var item: InventoryState.Item = null
## Texto do slot vazio (ex.: "Cabeça").
var empty_text: String = ""
## Desligado: ignora toques (vaga livre da mochila, ícone grande da ficha).
var disabled: bool = false
## true: segurar o item pega ele para arrastar (inventário). Sem item não arrasta.
var draggable: bool = false
## Destaque de alvo ao arrastar um item por cima: 0 = nenhum, 1 = pode soltar aqui (verde), −1 = não pode (vermelho).
var drop_highlight: int = 0:
	set(value):
		if value != drop_highlight:
			drop_highlight = value
			queue_redraw()

## Dedo apertado em cima do quadro (e ainda não virou rolagem).
var _held: bool = false
## Onde o toque começou (px, local).
var _press_position: Vector2 = Vector2.ZERO
## Tempo (s) segurando parado.
var _held_time: float = 0.0
## Item pego e sendo arrastado (o quadro fica apagado até soltar).
var _dragging: bool = false


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


## Toque (o toque chega aqui como clique emulado). Sem arrastar, não chama accept_event: o ScrollContainer pai também
## recebe e rola. Arrastando um item, segura tudo (a mochila para de rolar).
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if _dragging:
			if not button.pressed:
				accept_event()
				_dragging = false
				_held = false
				drag_ended.emit(button.global_position)
				queue_redraw()
			return
		if button.pressed:
			_held = true
			_held_time = 0.0
			_press_position = button.position
		elif _held:
			_held = false
			if Rect2(Vector2.ZERO, size).has_point(button.position):
				pressed.emit()
		queue_redraw()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging:
			accept_event()
			drag_moved.emit(motion.global_position)
		elif _held and motion.position.distance_to(_press_position) > DRAG_CANCEL_PX:
			_held = false
			queue_redraw()


## Segurando parado tempo bastante: pega o item para arrastar.
func _process(delta: float) -> void:
	if not _held or _dragging or not draggable or item == null:
		return
	_held_time += delta
	if _held_time >= HOLD_TO_DRAG_S:
		_dragging = true
		drag_started.emit()
		drag_moved.emit(get_global_rect().position + _press_position)
		queue_redraw()


## Arrastando um item agora.
func is_dragging() -> bool:
	return _dragging


func _notification(what: int) -> void:
	# Saindo de baixo do dedo NÃO solta um item arrastado (o dedo anda pela tela toda); escondido, solta sem efeito.
	if what == NOTIFICATION_MOUSE_EXIT and not _dragging:
		_held = false
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_held = false
		if _dragging:
			_dragging = false
			drag_ended.emit(Vector2.INF)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var held: bool = _held and not _dragging
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BACKGROUND.lightened(0.12) if held else BACKGROUND
	# Cantos retos: combina com as molduras pixel art.
	box.set_border_width_all(BORDER_PX)
	box.border_color = ItemIcons.set_color(item.set_name) if item != null else EMPTY_BORDER
	if held:
		box.border_color = box.border_color.lightened(0.3)
	if drop_highlight != 0:
		box.border_color = DROP_OK if drop_highlight > 0 else DROP_NO
		box.bg_color = box.bg_color.lerp(box.border_color, 0.18)
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
		var tint: Color = Color(1, 1, 1, DRAGGING_ALPHA) if _dragging else Color.WHITE
		draw_texture_rect(icon_texture, Rect2(inner.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false, tint)
	else:
		draw_string(get_theme_default_font(), inner.position + Vector2(0, inner.size.y / 2.0), item.name,
			HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, Color.WHITE)
	# Nível de melhoria ([JOGO-16]): "+3" dourado com contorno no canto de cima à direita.
	if item.level > 0:
		var font: Font = get_theme_default_font()
		var font_size: int = int(clampf(size.x * 0.2, 16.0, 30.0))
		var text: String = "+%d" % item.level
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at: Vector2 = Vector2(size.x - width - BORDER_PX - 4.0, BORDER_PX + font_size * 0.95)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color8(24, 16, 12))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LEVEL_COLOR)
