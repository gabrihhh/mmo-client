class_name MarketPanel
extends PanelContainer
## Tela do **Mercado** entre jogadores ([JOGO-25]), em tela inteira (variação `FullScreenPanel`, [CLI-07]), feita por
## código. Abre pelo botão "Mercado" (moeda) que aparece perto da tenda do Mercador ([Hud]). Um mercado só para o jogo
## inteiro: tudo vem do servidor, que confere a distância, as moedas, a mochila e quem compra primeiro.
##
## Abas:
## - **Comprar:** busca (nome do item ou do conjunto), filtro por slot, ordem (menor preço / mais novos), páginas de
##   20. Cada linha: ícone, nome +N com os atributos, vendedor e quando vence, e o botão do preço (1º toque pede
##   confirmação, 2º compra).
## - **Vender:** escolher um item da mochila, digitar o preço; mostra a taxa de 5% (paga agora, volta se cancelar ou
##   vencer); "Anunciar" desliga sem moedas para a taxa.
## - **Meus anúncios:** ativos (Cancelar), vencidos (Retirar) e vendidos (para quem), com o contador N/10.

signal list_requested(query: String, slot: String, sort: String, page: int)
signal mine_requested
signal sell_requested(uid: String, price: int)
signal buy_requested(listing_id: String)
signal cancel_requested(listing_id: String)
signal close_pressed

## Taxa de anunciar. ATENÇÃO: = MARKET_FEE_RATE / MAX_PRICE em mmo-server/src/items/market.ts (só para a prévia).
const FEE_RATE: float = 0.05
const MAX_PRICE: int = 1000000000
const SLOT_PX: float = 96.0
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const FAIL_COLOR: Color = Color(1.0, 0.45, 0.4)
const OK_COLOR: Color = Color(0.5, 1.0, 0.5)
const HINT_COLOR: Color = Color(1, 1, 1, 0.6)
## Filtros de slot (id → rótulo; "" = todos).
const SLOT_FILTERS: Dictionary[String, String] = {"": "Todos", "hand": "Arma", "head": "Cabeça", "chest": "Peito", "feet": "Pés"}
## Ícone pixel art de cada filtro e de cada aba (`assets/ui/pixel/`, de `tools/ui/make_pixel_ui.gd`).
const SLOT_ICONS: Dictionary[String, String] = {"": "icon_bag", "hand": "sword", "head": "icon_helm", "chest": "icon_armor", "feet": "icon_boot"}
const TAB_ICONS: Dictionary[String, String] = {"buy": "icon_bag", "sell": "icon_coin", "mine": "icon_list"}
## Abas (id → rótulo).
const TAB_TITLES: Dictionary[String, String] = {"buy": "Comprar", "sell": "Vender", "mine": "Meus anúncios"}

var _inventory: InventoryState = null
var _gold: int = 0
var _tab: String = "buy"
var _query: String = ""
var _slot: String = ""
var _sort: String = "price"
var _page: int = 0
var _pages: int = 1
var _confirm_id: String = ""
var _sell_uid: String = ""
var _page_listings: Array[MarketListing] = []
var _mine: Array[MarketListing] = []
var _max_listings: int = 10

var _gold_label: Label = null
var _tab_buttons: Dictionary[String, Button] = {}
var _sections: Dictionary[String, Control] = {}
var _search: LineEdit = null
var _slot_buttons: Dictionary[String, Button] = {}
var _sort_button: Button = null
var _buy_list: VBoxContainer = null
var _page_label: Label = null
var _sell_grid: GridContainer = null
var _sell_selected: Label = null
var _price_field: LineEdit = null
var _fee_label: Label = null
var _sell_button: Button = null
var _mine_label: Label = null
var _mine_list: VBoxContainer = null
var _message: Label = null


func _init() -> void:
	theme_type_variation = &"FullScreenPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	visibility_changed.connect(func() -> void:
		if visible:
			_message.text = ""
			_request_page()
			mine_requested.emit())
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header: Control = Control.new()
	header.custom_minimum_size = Vector2(0.0, 72.0)
	column.add_child(header)
	var title: Label = _label("Mercado", 44, Color.WHITE)
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
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(_gold_label)
	column.add_child(gold_row)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for tab: String in ["buy", "sell", "mine"]:
		var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(TAB_TITLES[tab]), TAB_ICONS[tab], 36)
		button.custom_minimum_size = Vector2(0.0, 68.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_set_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button

	_sections["buy"] = _build_buy()
	_sections["sell"] = _build_sell()
	_sections["mine"] = _build_mine()
	for tab: String in _sections:
		column.add_child(_sections[tab])

	_message = _label("", 24, HINT_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var back: Button = PixelMenuPanel.make_button("Voltar")
	back.custom_minimum_size = Vector2(0.0, 84.0)
	back.pressed.connect(close_pressed.emit)
	column.add_child(back)
	_set_tab("buy")


func _build_buy() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var search_row: HBoxContainer = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	box.add_child(search_row)
	_search = LineEdit.new()
	_search.theme_type_variation = &"PixelLineEdit"
	_search.placeholder_text = "Buscar item ou conjunto…"
	_search.max_length = 40
	_search.custom_minimum_size = Vector2(0.0, 72.0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_t: String) -> void: _do_search())
	search_row.add_child(_search)
	var go: Button = PixelMenuPanel.make_button("Buscar")
	go.custom_minimum_size = Vector2(150.0, 72.0)
	go.pressed.connect(_do_search)
	search_row.add_child(go)
	var filters: HFlowContainer = HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 6)
	filters.add_theme_constant_override("v_separation", 6)
	box.add_child(filters)
	for slot: String in SLOT_FILTERS:
		var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(SLOT_FILTERS[slot]), SLOT_ICONS[slot], 32)
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func() -> void:
			_slot = slot
			_page = 0
			_refresh_filters()
			_request_page())
		filters.add_child(button)
		_slot_buttons[slot] = button
	_sort_button = PixelMenuPanel.make_button("")
	_sort_button.custom_minimum_size = Vector2(0.0, 56.0)
	_sort_button.add_theme_font_size_override("font_size", 22)
	_sort_button.pressed.connect(func() -> void:
		_sort = "new" if _sort == "price" else "price"
		_page = 0
		_refresh_filters()
		_request_page())
	filters.add_child(_sort_button)
	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 8)
	box.add_child(_scroll(_buy_list))
	var pager: HBoxContainer = HBoxContainer.new()
	pager.add_theme_constant_override("separation", 8)
	box.add_child(pager)
	var prev: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(""), "icon_arrow_left", 40)
	prev.custom_minimum_size = Vector2(110.0, 60.0)
	prev.pressed.connect(func() -> void:
		if _page > 0:
			_page -= 1
			_request_page())
	pager.add_child(prev)
	_page_label = _label("", 22, HINT_COLOR)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(_page_label)
	var next: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(""), "icon_arrow_right", 40)
	next.custom_minimum_size = Vector2(110.0, 60.0)
	next.pressed.connect(func() -> void:
		if _page + 1 < _pages:
			_page += 1
			_request_page())
	pager.add_child(next)
	_refresh_filters()
	return box


func _build_sell() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.add_child(_label("Escolha um item da mochila:", 22, HINT_COLOR))
	_sell_grid = GridContainer.new()
	_sell_grid.columns = 5
	_sell_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_sell_grid.add_theme_constant_override("h_separation", 12)
	_sell_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_scroll(_sell_grid))
	_sell_selected = _label("Nenhum item escolhido.", 26, Color.WHITE)
	box.add_child(_sell_selected)
	_price_field = LineEdit.new()
	_price_field.theme_type_variation = &"PixelLineEdit"
	_price_field.placeholder_text = "Preço em moedas"
	_price_field.max_length = 10
	_price_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_price_field.custom_minimum_size = Vector2(0.0, 72.0)
	_price_field.text_changed.connect(func(text: String) -> void:
		var digits: String = ""
		for c: String in text:
			if c >= "0" and c <= "9":
				digits += c
		if digits != text:
			_price_field.text = digits
			_price_field.caret_column = digits.length()
		_refresh_sell_button())
	box.add_child(_price_field)
	_fee_label = _label("", 22, GOLD_COLOR)
	box.add_child(_fee_label)
	_sell_button = PixelMenuPanel.make_button("Anunciar")
	_sell_button.custom_minimum_size = Vector2(0.0, 84.0)
	_sell_button.pressed.connect(func() -> void:
		if not _sell_uid.is_empty() and _price() > 0:
			sell_requested.emit(_sell_uid, _price())
			_sell_button.disabled = true)
	box.add_child(_sell_button)
	return box


func _build_mine() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_mine_label = _label("", 22, HINT_COLOR)
	box.add_child(_mine_label)
	_mine_list = VBoxContainer.new()
	_mine_list.add_theme_constant_override("separation", 8)
	box.add_child(_scroll(_mine_list))
	return box


# --- Dados que chegam ---

## Inventário novo: refaz a grade de vender (o item anunciado saiu da mochila).
func show_inventory(inventory: InventoryState) -> void:
	_inventory = inventory
	if is_node_ready():
		_refresh_sell()


func set_gold(amount: int) -> void:
	_gold = amount
	if is_node_ready():
		_gold_label.text = "%s moedas" % InventoryView.format_gold(amount)
		_refresh_sell_button()
		_refresh_buy_list()


## Página da busca chegou.
func show_page(listings: Array[MarketListing], total: int, page: int, page_size: int) -> void:
	_page_listings = listings
	_page = page
	_pages = maxi(1, ceili(float(total) / maxi(page_size, 1)))
	_confirm_id = ""
	if is_node_ready():
		_page_label.text = "Página %d/%d · %d à venda" % [_page + 1, _pages, total]
		_refresh_buy_list()


## Seus anúncios chegaram.
func show_mine(listings: Array[MarketListing], max_listings: int) -> void:
	_mine = listings
	_max_listings = max_listings
	if is_node_ready():
		_refresh_mine()


## Ação feita: mensagem e listas atualizadas.
func show_result(action: String, item_name: String, price: int, gold: int) -> void:
	match action:
		"sell":
			_show_message("Anunciado: %s por %s (taxa %s paga)." % [item_name, _fmt(price), _fmt(gold)], OK_COLOR)
			_sell_uid = ""
			_price_field.text = ""
			_refresh_sell()
		"buy":
			_show_message("Comprou %s por %s moedas (foi para a mochila)." % [item_name, _fmt(price)], OK_COLOR)
			_request_page()
		"cancel":
			_show_message("%s voltou para a mochila e a taxa (%s) voltou." % [item_name, _fmt(gold)], OK_COLOR)


## Recusa do servidor (longe, sem moedas, já vendido…).
func show_notice(text: String) -> void:
	_confirm_id = ""
	if is_node_ready():
		_show_message(text, FAIL_COLOR)
		_refresh_sell_button()
		if _tab == "buy":
			_request_page()


# --- Telas ---

func _set_tab(tab: String) -> void:
	_tab = tab
	_confirm_id = ""
	for key: String in _tab_buttons:
		_tab_buttons[key].modulate = Color(1, 1, 1) if key == tab else Color(1, 1, 1, 0.5)
		_sections[key].visible = key == tab
	if tab == "sell":
		_refresh_sell()
	elif tab == "mine":
		mine_requested.emit()


func _do_search() -> void:
	_query = _search.text.strip_edges()
	_page = 0
	_request_page()


func _request_page() -> void:
	list_requested.emit(_query, _slot, _sort, _page)


func _refresh_filters() -> void:
	for slot: String in _slot_buttons:
		_slot_buttons[slot].modulate = Color(1, 1, 1) if slot == _slot else Color(1, 1, 1, 0.5)
	_sort_button.text = "Ordem: menor preço" if _sort == "price" else "Ordem: mais novos"


func _refresh_buy_list() -> void:
	_clear(_buy_list)
	if _page_listings.is_empty():
		_buy_list.add_child(_label("Nada à venda com esse filtro.", 22, HINT_COLOR))
		return
	for listing: MarketListing in _page_listings:
		var subtitle: String = "%s · vence em %s" % [listing.seller_name, _duration(listing.expires_in)]
		var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button("Confirmar?" if _confirm_id == listing.id else _fmt(listing.price)), "icon_coin", 32)
		button.custom_minimum_size = Vector2(220.0, 72.0)
		button.disabled = _gold < listing.price or listing.seller_name == Network.instance.username
		button.pressed.connect(_on_buy_pressed.bind(listing.id))
		_buy_list.add_child(_row(listing.item, subtitle, button))


func _on_buy_pressed(listing_id: String) -> void:
	if _confirm_id != listing_id:
		_confirm_id = listing_id
		_refresh_buy_list()
		return
	_confirm_id = ""
	buy_requested.emit(listing_id)


func _refresh_sell() -> void:
	_clear(_sell_grid)
	var bag: Array[InventoryState.Item] = _inventory.bag if _inventory != null else []
	var chosen: InventoryState.Item = null
	for item: InventoryState.Item in bag:
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		view.show_item(item)
		view.drop_highlight = 1 if item.uid == _sell_uid else 0
		view.pressed.connect(func() -> void:
			_sell_uid = item.uid
			_refresh_sell())
		_sell_grid.add_child(view)
		if item.uid == _sell_uid:
			chosen = item
	if chosen == null:
		_sell_uid = ""
		_sell_selected.text = "Nenhum item escolhido." if not bag.is_empty() else "Mochila vazia."
	else:
		_sell_selected.text = chosen.display_name()
	_refresh_sell_button()


func _refresh_sell_button() -> void:
	if _sell_button == null:
		return
	var price: int = _price()
	var fee: int = fee_for(price)
	if price <= 0:
		_fee_label.text = "Taxa: 5% do preço, paga agora (volta se cancelar ou vencer)."
	else:
		_fee_label.text = "Taxa: %s moedas (5%%), paga agora · volta se cancelar ou vencer." % _fmt(fee)
	_sell_button.disabled = _sell_uid.is_empty() or price <= 0 or price > MAX_PRICE or _gold < fee
	_sell_button.text = "Anunciar" if _gold >= fee or price <= 0 else "Faltam moedas para a taxa"


func _refresh_mine() -> void:
	var open: int = 0
	for listing: MarketListing in _mine:
		if listing.status != "sold":
			open += 1
	_mine_label.text = "Anúncios: %d/%d (ativos + vencidos)" % [open, _max_listings]
	_clear(_mine_list)
	if _mine.is_empty():
		_mine_list.add_child(_label("Você não tem anúncios.", 22, HINT_COLOR))
		return
	for listing: MarketListing in _mine:
		var subtitle: String = ""
		var button: Button = null
		match listing.status:
			"active":
				subtitle = "%s moedas · vence em %s" % [_fmt(listing.price), _duration(listing.expires_in)]
				button = PixelMenuPanel.make_button("Cancelar")
			"expired":
				subtitle = "%s moedas · venceu" % _fmt(listing.price)
				button = PixelMenuPanel.make_button("Retirar")
			_:
				subtitle = "Vendido por %s moedas para %s" % [_fmt(listing.price), listing.buyer_name]
		if button != null:
			button.custom_minimum_size = Vector2(200.0, 72.0)
			button.pressed.connect(cancel_requested.emit.bind(listing.id))
		_mine_list.add_child(_row(listing.item, subtitle, button))


## Linha: ícone, nome +N (com os atributos embaixo), [param subtitle] e o botão [param action] (pode ser null).
func _row(item: InventoryState.Item, subtitle: String, action: Button) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"PixelCard"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var slot: ItemSlot = ItemSlot.new()
	slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	slot.disabled = true
	slot.show_item(item)
	row.add_child(slot)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_child(_label(item.display_name(), 26, ItemIcons.set_color(item.set_name).lightened(0.35)))
	var attrs: Array[String] = []
	for id: String in ItemAttributes.IDS:
		if item.attrs.has(id):
			attrs.append("%s %d" % [ItemAttributes.title(id), item.attrs[id]])
	if not attrs.is_empty():
		texts.add_child(_label(" · ".join(attrs), 18, Color(1, 1, 1, 0.75)))
	texts.add_child(_label(subtitle, 20, HINT_COLOR))
	row.add_child(texts)
	if action != null:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
	return panel


# --- Ajudantes ---

## Taxa de anunciar por [param price] (5%, para cima, mínimo 1). ATENÇÃO: = listingFee no servidor.
static func fee_for(price: int) -> int:
	return maxi(1, ceili(price * FEE_RATE)) if price > 0 else 0


func _price() -> int:
	var text: String = _price_field.text if _price_field != null else ""
	return text.to_int() if text.is_valid_int() else 0


static func _duration(seconds: int) -> String:
	if seconds >= 86400:
		return "%d d" % (seconds / 86400)
	if seconds >= 3600:
		return "%d h" % (seconds / 3600)
	return "%d min" % maxi(1, seconds / 60)


static func _fmt(amount: int) -> String:
	return InventoryView.format_gold(amount)


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


static func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _scroll(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
