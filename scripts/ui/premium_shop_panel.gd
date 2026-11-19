class_name PremiumShopPanel
extends PixelMenuPanel
## Menu → "Loja" ([JOGO-27]): a Loja premium, aberta de qualquer lugar (sem NPC). No topo o saldo de Diamantes e o que
## está ativo (VIP, poção de XP, pedras, proteções). Abas: **Visual** (em breve), **VIP**, **Conveniência**, **Poder**,
## **Diamantes** (os pacotes) e **Histórico**. Cada produto mostra descrição e preço; comprar pede **confirmação**
## (1º toque arma, 2º compra). Sem Diamantes, o botão leva aos pacotes. Tudo vem do servidor ([PremiumState]); o
## servidor decide a compra. Hoje os pacotes só funcionam com a compra de TESTE do servidor de dev (sem dinheiro); a
## compra pela Google Play / App Store é a etapa 2 ([INFRA-14]).

## Abriu a Loja: pede saldo/catálogo ([method Network.send_premium_open]).
signal open_requested
## Comprar o produto [param product_id] (já confirmado).
signal buy_requested(product_id: String)
## Comprar o pacote de Diamantes [param pack_id].
signal pack_requested(pack_id: String)
## Abriu a aba Histórico: pede a lista.
signal history_requested

## Altura do painel (px).
const HEIGHT_PX: float = 1180.0
## Fonte (px) das abas (6 abas em 2 linhas no painel de 640 px).
const TAB_FONT_PX: int = 26
const NAME_COLOR: Color = Color(1.0, 0.84, 0.3)
const DIM_COLOR: Color = Color(1, 1, 1, 0.7)
const DIAMOND_COLOR: Color = Color(0.55, 0.9, 1.0)
const OK_COLOR: Color = Color(0.5, 1.0, 0.5)
## Abas: id → texto. As três de produto usam os ids de [PremiumState] CATEGORY_*.
const _TABS: Dictionary[String, String] = {
	"visual": "Visual",
	PremiumState.CATEGORY_VIP: "VIP",
	PremiumState.CATEGORY_CONVENIENCE: "Conveniência",
	PremiumState.CATEGORY_POWER: "Poder",
	"packs": "Diamantes",
	"history": "Histórico",
}

var _state: PremiumState = null
var _tab: String = PremiumState.CATEGORY_VIP
## Produto com a compra "armada" (1º toque); vazio = nenhum.
var _confirm_id: String = ""
var _history: Array[PremiumState.HistoryEntry] = []
var _tab_buttons: Dictionary[String, Button] = {}
var _balance: Button = null
var _status: Label = null
var _message: Label = null
var _list: VBoxContainer = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Loja")
	_balance = PixelMenuPanel.set_icon(PixelMenuPanel.make_button("0 Diamantes"), "icon_diamond", 48)
	_balance.add_theme_color_override("font_color", DIAMOND_COLOR)
	_balance.pressed.connect(_set_tab.bind("packs"))
	body.add_child(_balance)
	_status = PixelMenuPanel.make_label("", DIM_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	var ids: Array[String] = []
	ids.assign(_TABS.keys())
	body.add_child(_make_tab_row(ids.slice(0, 4)))
	body.add_child(_make_tab_row(ids.slice(4)))
	_message = PixelMenuPanel.make_label("", OK_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_message)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_list)
	_refresh()
	visibility_changed.connect(func() -> void:
		if visible:
			_confirm_id = ""
			_message.text = ""
			open_requested.emit()
			if _tab == "history":
				history_requested.emit())


## Chegou o estado da Loja (ao entrar, ao abrir e a cada compra).
func show_state(state: PremiumState) -> void:
	_state = state
	_refresh()


## Chegou o histórico de compras.
func show_history(entries: Array[PremiumState.HistoryEntry]) -> void:
	_history = entries
	if _tab == "history":
		_refresh()


## Compra feita: mensagem verde ([param kind] "pack" = ganhou [param diamonds]; "product" = gastou).
func show_result(kind: String, item_name: String, diamonds: int) -> void:
	_confirm_id = ""
	if kind == "pack":
		_message.text = "+%s Diamantes!" % InventoryView.format_gold(diamonds)
	else:
		_message.text = "Comprado: %s" % item_name
	_message.add_theme_color_override("font_color", OK_COLOR)
	if _tab == "history":
		history_requested.emit()


## O servidor recusou por falta de Diamantes: leva aos pacotes.
func show_not_enough() -> void:
	_confirm_id = ""
	_message.text = "Diamantes insuficientes."
	_message.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_set_tab("packs")


func _make_tab_row(ids: Array[String]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for id: String in ids:
		var button: Button = PixelMenuPanel.make_button(_TABS[id])
		button.add_theme_font_size_override("font_size", TAB_FONT_PX)
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_tab.bind(id))
		row.add_child(button)
		_tab_buttons[id] = button
	return row


func _set_tab(id: String) -> void:
	if id == _tab:
		return
	_tab = id
	_confirm_id = ""
	if id == "history":
		_history = []
		history_requested.emit()
	_refresh()


## Redesenha saldo, abas e a lista da aba aberta.
func _refresh() -> void:
	for id: String in _tab_buttons.keys():
		var on: bool = id == _tab
		_tab_buttons[id].modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.5)
	for child: Node in _list.get_children():
		child.queue_free()
	if _state == null:
		_balance.text = "… Diamantes"
		_status.text = "Carregando…"
		return
	_balance.text = "%s Diamantes" % InventoryView.format_gold(_state.diamonds)
	_status.text = _status_text()
	match _tab:
		"visual":
			_add_text("Em breve: tintas para os itens, aura em volta do personagem e efeito no nome.", DIM_COLOR)
		"packs":
			_fill_packs()
		"history":
			_fill_history()
		_:
			for product: PremiumState.Product in _state.products_in(_tab):
				_add_product(product)


## "VIP: 29 d 23 h · XP ×2: 45 min · 2 pedras · 1 proteção" (ou "Nada ativo").
func _status_text() -> String:
	var parts: Array[String] = []
	var vip: int = _state.vip_seconds_left()
	if vip > 0:
		parts.append("VIP: %s" % PremiumState.duration_text(vip))
	var boost: int = _state.xp_boost_seconds_left()
	if boost > 0:
		parts.append("XP ×2: %s" % PremiumState.duration_text(boost))
	if _state.upgrade_stones > 0:
		parts.append("%d pedra%s" % [_state.upgrade_stones, "" if _state.upgrade_stones == 1 else "s"])
	if _state.death_protections > 0:
		parts.append("%d proteç%s" % [_state.death_protections, "ão" if _state.death_protections == 1 else "ões"])
	return "Nada ativo" if parts.is_empty() else " · ".join(parts)


## Ficha de um produto: nome, descrição e o botão de compra (com confirmação).
func _add_product(product: PremiumState.Product) -> void:
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.add_child(PixelMenuPanel.make_label(product.name, NAME_COLOR))
	card.add_child(PixelMenuPanel.make_label(product.description, DIM_COLOR))
	var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(""), "icon_diamond", 40)
	if product.owned:
		button.text = "Comprado"
		button.disabled = true
	elif _state.diamonds < product.price:
		button.text = "%s · faltam %s" % [InventoryView.format_gold(product.price), InventoryView.format_gold(product.price - _state.diamonds)]
		button.pressed.connect(_set_tab.bind("packs"))
	elif _confirm_id == product.id:
		button.text = "Confirmar: gastar %s?" % InventoryView.format_gold(product.price)
		button.add_theme_color_override("font_color", NAME_COLOR)
		button.pressed.connect(_buy.bind(product.id))
	else:
		button.text = "Comprar · %s" % InventoryView.format_gold(product.price)
		button.pressed.connect(_arm.bind(product.id))
	card.add_child(button)
	_list.add_child(card)


func _arm(product_id: String) -> void:
	_confirm_id = product_id
	_message.text = ""
	_refresh()


func _buy(product_id: String) -> void:
	_confirm_id = ""
	_message.text = "Comprando…"
	_message.add_theme_color_override("font_color", DIM_COLOR)
	buy_requested.emit(product_id)
	_refresh()


## Pacotes de Diamantes: "220 Diamantes (1ª compra: 440!)" + preço. Sem compra de teste no servidor: "Em breve".
func _fill_packs() -> void:
	if _state.test_purchases:
		_add_text("Compra de TESTE (servidor de desenvolvimento): os Diamantes saem de graça.", NAME_COLOR)
	else:
		_add_text("A compra de Diamantes pela loja do celular chega em breve.", DIM_COLOR)
	for pack: PremiumState.Pack in _state.packs:
		var card: VBoxContainer = VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var title: String = "%s Diamantes" % InventoryView.format_gold(pack.diamonds)
		if pack.doubled:
			title += " · 1ª compra: %s!" % InventoryView.format_gold(pack.diamonds * 2)
		card.add_child(PixelMenuPanel.make_label(title, DIAMOND_COLOR))
		var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(pack.price_label), "icon_diamond", 40)
		button.disabled = not _state.test_purchases
		if not _state.test_purchases:
			button.text = "%s · em breve" % pack.price_label
		button.pressed.connect(func() -> void:
			_message.text = "Comprando…"
			_message.add_theme_color_override("font_color", DIM_COLOR)
			pack_requested.emit(pack.id))
		card.add_child(button)
		_list.add_child(card)


## Histórico: "18/11 14:03 · VIP 30 dias · −300" (mais nova primeiro).
func _fill_history() -> void:
	if _history.is_empty():
		_add_text("Nenhuma compra ainda.", DIM_COLOR)
		return
	var bias_s: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	for entry: PremiumState.HistoryEntry in _history:
		var when: Dictionary = Time.get_datetime_dict_from_unix_time(entry.at_unix + bias_s)
		var prefix: String = "+" if entry.diamonds >= 0 else "−"
		var text: String = "%02d/%02d %02d:%02d · %s · %s%s%s" % [
			int(when.get("day", 0)), int(when.get("month", 0)), int(when.get("hour", 0)), int(when.get("minute", 0)),
			entry.name, prefix, InventoryView.format_gold(absi(entry.diamonds)), " (teste)" if entry.test else "",
		]
		_add_text(text, DIAMOND_COLOR if entry.diamonds >= 0 else Color(1, 1, 1))


func _add_text(text: String, color: Color) -> void:
	var label: Label = PixelMenuPanel.make_label(text, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(label)
