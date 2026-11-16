class_name ChestPanel
extends PixelMenuPanel
## Janela do **baú do acampamento** ([JOGO-19]): abre pelo botão "Abrir baú" que aparece perto de um baú aberto
## ([Hud]). Mostra o que sobrou para você (o sorteio é só seu): uma linha por item (ícone, nome, "+nível", classe) e as
## moedas. Tocar = pegar ([signal take_requested]); o servidor confere, põe na mochila e manda a lista atualizada.
##
## ```
## ┌──────── Baú (nv 7) ──────── [X]┐
## │ [ícone] Capuz do Atirador +3 · Atirador │
## │ [ícone] Túnica Arcana · Mago            │
## │ (●) 245 moedas                          │
## │ Toque para pegar.                       │
## │ [Fechar]                                │
## └─────────────────────────────────────────┘
## ```

## Tocou numa linha: pegar [param loot_id] do baú [param chest_id].
signal take_requested(chest_id: String, loot_id: String)

## Altura do painel (px): cabe ~5 linhas; mais que isso a lista rola.
const HEIGHT_PX: float = 860.0
## Lado (px) do ícone do item na linha.
const ICON_PX: int = 72
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)

var _chest_id: String = ""
var _list: VBoxContainer = null
var _hint: Label = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Baú")
	back_button.text = "Fechar"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_hint = PixelMenuPanel.make_label("", Color(1, 1, 1, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_hint)


## Baú cuja janela está aberta ("" = nenhum).
func chest_id() -> String:
	return _chest_id if visible else ""


## Mostra o que sobrou no baú [param chest] ([param entries]: itens e moedas).
func show_loot(chest: ChestInfo, entries: Array[LootEntry]) -> void:
	_chest_id = chest.id
	set_title(("Baú do chefe (nv %d)" if chest.boss else "Baú (nv %d)") % chest.level)
	for child: Node in _list.get_children():
		child.queue_free()
	for entry: LootEntry in entries:
		var button: Button = PixelMenuPanel.make_button(_entry_text(entry), true)
		# Deixa o arrasto chegar ao ScrollContainer (lista grande rola).
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.expand_icon = false
		if entry.item != null:
			button.icon = _small_icon(ItemIcons.item(entry.item.item_id))
			button.add_theme_color_override("font_color", ItemIcons.set_color(entry.item.set_name).lightened(0.35))
		else:
			button.add_theme_color_override("font_color", GOLD_COLOR)
		button.pressed.connect(take_requested.emit.bind(chest.id, entry.loot_id))
		_list.add_child(button)
	_hint.text = "Nada para você neste baú." if entries.is_empty() else "Toque para pegar."


func _entry_text(entry: LootEntry) -> String:
	if entry.item == null:
		return "  ● %d moedas" % entry.gold
	var level: String = " +%d" % entry.item.level if entry.item.level > 0 else ""
	return "  %s%s · %s" % [entry.item.name, level, entry.item.set_name]


## Ícone reduzido para caber na linha (o original é pixel art grande).
func _small_icon(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
