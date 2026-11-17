class_name StoragePanel
extends PanelContainer
## Tela do **Armazém** ([JOGO-26]), em tela inteira (variação `FullScreenPanel`, [CLI-07]), feita por código. Abre
## pelo botão "📦 Armazém" que aparece perto do baú grande da praça ([Hud]).
##
## ```
## ┌──────── Armazém ──────── [X]┐
## │ (●) 1.234 moedas              │
## │ Armazém 12/40                 │
## │ [1][2]  [+ Aba · 7.500]       │  abas de 20 espaços; comprar pede 2º toque
## │ [■][■][■][■][■]               │  aba aberta (4 × 5): tocar tira p/ a mochila
## │ ...                           │
## │ Mochila 8/30 · toque p/ guardar│
## │ [■][■][■][■][■] (rola)        │  só a mochila (vestido não entra)
## │ mensagem                      │
## │ [Voltar]                      │
## └───────────────────────────────┘
## ```
## O armazém chega no próprio `inventory` ([member InventoryState.storage]); o servidor confere a distância, os
## espaços e as moedas.

## Tocou num item da mochila: guardar [param uid].
signal put_requested(uid: String)
## Tocou num item do armazém: tirar [param uid] para a mochila.
signal take_requested(uid: String)
## Confirmou a compra de mais uma aba.
signal buy_tab_requested
## Fechar (X ou Voltar).
signal close_pressed

## Espaços por aba. ATENÇÃO: = STORAGE_TAB_SIZE em mmo-server/src/items/storage.ts.
const TAB_SIZE: int = 20
## Lado (px) de cada espaço das grades.
const SLOT_PX: float = 104.0
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const FAIL_COLOR: Color = Color(1.0, 0.45, 0.4)
const HINT_COLOR: Color = Color(1, 1, 1, 0.6)

var _inventory: InventoryState = null
var _gold: int = 0
## Aba aberta (0 = primeira) e se o "+ Aba" já levou o 1º toque.
var _tab: int = 0
var _confirm_buy: bool = false
var _gold_label: Label = null
var _storage_label: Label = null
var _tabs_row: HBoxContainer = null
var _storage_grid: GridContainer = null
var _bag_label: Label = null
var _bag_grid: GridContainer = null
var _message: Label = null


func _init() -> void:
	theme_type_variation = &"FullScreenPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var header: Control = Control.new()
	header.custom_minimum_size = Vector2(0.0, 72.0)
	column.add_child(header)
	var title: Label = _label("Armazém", 44, Color.WHITE)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close: Button = PixelMenuPanel.make_close_button()
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -72.0
	close.offset_bottom = 72.0
	close.pressed.connect(close_pressed.emit)
	header.add_child(close)

	var gold_row: HBoxContainer = HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 10)
	var coin: InventoryView.CoinIcon = InventoryView.CoinIcon.new()
	coin.custom_minimum_size = Vector2(36.0, 36.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_row.add_child(coin)
	_gold_label = _label("0 moedas", 28, GOLD_COLOR)
	# Sem quebra de linha e ocupando a linha: com quebra, a HBox espreme o texto e ele sai uma letra por linha.
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(_gold_label)
	column.add_child(gold_row)

	_storage_label = _label("Armazém", 24, Color.WHITE)
	column.add_child(_storage_label)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 10)
	column.add_child(_tabs_row)
	_storage_grid = _grid()
	column.add_child(_storage_grid)

	_bag_label = _label("Mochila", 24, Color.WHITE)
	column.add_child(_bag_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_bag_grid = _grid()
	scroll.add_child(_bag_grid)

	_message = _label("", 24, HINT_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var back: Button = PixelMenuPanel.make_button("Voltar")
	back.custom_minimum_size = Vector2(0.0, 88.0)
	back.pressed.connect(close_pressed.emit)
	column.add_child(back)
	_refresh()


## Inventário novo (inclui o armazém): refaz as grades.
func show_inventory(inventory: InventoryState) -> void:
	_inventory = inventory
	_confirm_buy = false
	if is_node_ready():
		_refresh()


## Moedas do personagem (o "+ Aba" desliga sem moedas).
func set_gold(amount: int) -> void:
	if amount == _gold:
		return
	_gold = amount
	if is_node_ready():
		_refresh()


## Aviso (recusa do servidor: longe, cheio, sem moedas...).
func show_notice(text: String) -> void:
	_confirm_buy = false
	if is_node_ready():
		_refresh()
		_show_message(text, FAIL_COLOR)


func _refresh() -> void:
	_gold_label.text = "%s moedas" % InventoryView.format_gold(_gold)
	var storage: Array[InventoryState.Item] = []
	var capacity: int = TAB_SIZE
	var tab_cost: int = 0
	var bag: Array[InventoryState.Item] = []
	var bag_capacity: int = 0
	if _inventory != null:
		storage = _inventory.storage
		capacity = maxi(TAB_SIZE, _inventory.storage_capacity)
		tab_cost = _inventory.storage_tab_cost
		bag = _inventory.bag
		bag_capacity = _inventory.bag_capacity
	var tabs: int = ceili(float(capacity) / TAB_SIZE)
	_tab = clampi(_tab, 0, tabs - 1)
	_storage_label.text = "Armazém %d/%d · toque para tirar" % [storage.size(), capacity]
	_bag_label.text = "Mochila %d/%d · toque para guardar" % [bag.size(), bag_capacity]

	for child: Node in _tabs_row.get_children():
		_tabs_row.remove_child(child)
		child.queue_free()
	for i: int in range(tabs):
		var tab: Button = PixelMenuPanel.make_button(str(i + 1))
		tab.custom_minimum_size = Vector2(72.0, 64.0)
		tab.modulate = Color(1, 1, 1) if i == _tab else Color(1, 1, 1, 0.5)
		tab.pressed.connect(_open_tab.bind(i))
		_tabs_row.add_child(tab)
	var buy: Button = PixelMenuPanel.make_button(("Confirmar: %s moedas?" if _confirm_buy else "+ Aba · %s") % InventoryView.format_gold(tab_cost))
	buy.custom_minimum_size = Vector2(0.0, 64.0)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.disabled = _gold < tab_cost
	buy.pressed.connect(_on_buy_pressed)
	_tabs_row.add_child(buy)

	_fill(_storage_grid, storage.slice(_tab * TAB_SIZE, (_tab + 1) * TAB_SIZE), TAB_SIZE, take_requested)
	_fill(_bag_grid, bag, bag.size(), put_requested)
	if _confirm_buy:
		_show_message("Toque de novo para comprar mais 20 espaços.", GOLD_COLOR)
	elif _gold < tab_cost:
		_show_message("Aba nova: %s moedas." % InventoryView.format_gold(tab_cost), HINT_COLOR)
	else:
		_show_message("", HINT_COLOR)


## Enche [param grid] com [param items] e espaços vazios até [param slots]; tocar num item emite [param action].
func _fill(grid: GridContainer, items: Array[InventoryState.Item], slots: int, action: Signal) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for i: int in range(maxi(slots, items.size())):
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		if i < items.size():
			var item: InventoryState.Item = items[i]
			view.show_item(item)
			view.pressed.connect(func() -> void: action.emit(item.uid))
		else:
			view.show_item(null)
			view.disabled = true
		grid.add_child(view)


func _open_tab(index: int) -> void:
	_tab = index
	_confirm_buy = false
	_refresh()


func _on_buy_pressed() -> void:
	if _confirm_buy:
		_confirm_buy = false
		buy_tab_requested.emit()
		_show_message("Comprando…", HINT_COLOR)
		return
	_confirm_buy = true
	_refresh()


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
