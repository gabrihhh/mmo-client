class_name BlacksmithPanel
extends PanelContainer
## Tela do **Ferreiro** ([JOGO-16]), em tela inteira (variação `FullScreenPanel`, [CLI-07]), feita por código. Abre
## pelo botão "Ferreiro" que aparece perto dele ([Hud]).
##
## ```
## ┌──────── Ferreiro ─────── [X]┐
## │ (●) 1.234 moedas              │
## │ [ícone]  Espada Longa +3      │  item escolhido
## │          Dano 5 · Defesa 1    │
## │ Escolha o que melhorar:       │
## │ [Dano      5 → 7   (+2)]      │  um botão por atributo do conjunto
## │ [Crítico   novo    (+1)]      │  (novo = +1; o item já tem = +2)
## │ [ Melhorar · 118 · 59% ]      │
## │ Deu certo! Espada Longa +4    │  resultado
## │ Seus itens:                   │
## │ [■][■][■][■][■] (rola)        │  vestidos primeiro, depois a mochila
## │ [Voltar]                      │
## └───────────────────────────────┘
## ```
## Preço e chance vêm prontos do servidor (no inventário); o servidor confere tudo e sorteia ([JOGO-16]).
##
## Duas abas no topo: **Melhorar** (moedas, sobe 1 nível com chance) e **Fundir** ([JOGO-20]): escolhido o item, a lista
## mostra só os itens IGUAIS da mochila; tocar num deles mostra antes até onde o escolhido vai ("+9 → +10 · 37%");
## "Fundir" sacrifica o igual e passa a experiência dele (sem moedas, sem falhar).
## "Melhorar" abre a forja ([UpgradeForge]): a carga demora ~1,8 s e o resultado (e o inventário novo, com o "+N") só
## aparece no ápice, mesmo que o servidor tenha respondido antes.
## Terceira aba, **Loja** ([JOGO-23]): **Comprar** lista as peças +0 de todos os conjuntos (vem do servidor em
## [method show_shop]) e **Vender** usa os seus itens (vestido não vende; item +1 ou mais pede um segundo toque para
## confirmar). Preços prontos do servidor (oferta e [member InventoryState.Item.sell_price]).
## Pedra de melhoria garantida (Loja premium, [JOGO-27]): com pedras e chance menor que 100%, aparece o botão
## "Usar pedra garantida" embaixo do "Melhorar"; ligado, a melhoria não falha e gasta uma pedra (o servidor decide).

## Apertou "Melhorar": item [param uid] com o atributo [param attribute]; [param guaranteed] = usar a pedra garantida.
signal upgrade_requested(uid: String, attribute: String, guaranteed: bool)
## Apertou "Fundir": sacrificar [param material_uid] (da mochila) em [param target_uid] (o mesmo item). [JOGO-20]
signal fuse_requested(target_uid: String, material_uid: String)
## Abriu a aba Loja sem a lista ainda: pedir ao servidor ([JOGO-23]).
signal shop_open_requested
## Apertou "Comprar" na Loja: a peça [param item_id] (+0).
signal shop_buy_requested(item_id: String)
## Confirmou "Vender" na Loja: o item [param uid] da mochila.
signal shop_sell_requested(uid: String)
## Apertou X ou Voltar.
signal close_pressed

## Lado (px) dos quadros da lista de itens e do item escolhido.
const PICK_SLOT_PX: float = 104.0
const SELECTED_SLOT_PX: float = 128.0
## Altura (px) dos botões de atributo e do "Melhorar".
const ATTRIBUTE_BUTTON_PX: float = 64.0
const UPGRADE_BUTTON_PX: float = 88.0
## Cores do resultado.
const SUCCESS_COLOR: Color = Color(0.5, 1.0, 0.5)
const FAIL_COLOR: Color = Color(1.0, 0.45, 0.4)
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)

var _inventory: InventoryState = null
var _gold: int = 0
## Item e atributo escolhidos (uid vazio = nenhum).
var _selected_uid: String = ""
var _selected_attribute: String = ""
## Esperando a resposta de uma tentativa (o botão fica desligado).
var _waiting: bool = false
## Pedras de melhoria garantida da conta ([JOGO-27]) e se a próxima melhoria usa uma.
var _stones: int = 0
var _use_stone: bool = false
var _stone_button: Button = null

var _gold_label: Label = null
var _selected_slot: ItemSlot = null
var _selected_name: Label = null
var _selected_attrs: Label = null
var _attribute_box: VBoxContainer = null
var _upgrade_button: Button = null
var _result_label: Label = null
var _pick_grid: GridContainer = null
var _forge: UpgradeForge = null
## Aba aberta ("upgrade" = Melhorar, "fuse" = Fundir) e, na Fundir, o item igual escolhido para sacrificar.
var _mode: String = "upgrade"
var _material_uid: String = ""
var _tab_buttons: Dictionary[String, Button] = {}
var _upgrade_section: VBoxContainer = null
var _fuse_section: VBoxContainer = null
var _fuse_hint: Label = null
var _material_grid: GridContainer = null
var _fuse_button: Button = null
## Guardados enquanto a forja anima: o inventário novo e a mensagem do resultado (aplicados no fim).
## Loja ([JOGO-23]): peças à venda (uid "shop-<itemId>"), preço de cada uid, sub-aba e o 1º toque da venda de item +N.
var _offers: Array[InventoryState.Item] = []
var _offer_prices: Dictionary[String, int] = {}
var _shop_buy: bool = true
var _sell_confirm_uid: String = ""
var _shop_section: VBoxContainer = null
var _shop_tabs: Dictionary[bool, Button] = {}
var _shop_button: Button = null
var _pick_label: Label = null
var _pending_inventory: InventoryState = null
var _pending_message: String = ""
var _pending_color: Color = Color.WHITE


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
	var title: Label = Label.new()
	title.text = "Ferreiro"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 44)
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
	_gold_label = _label("0", 28, GOLD_COLOR)
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(_gold_label)
	column.add_child(gold_row)

	# Abas: Melhorar (moedas) e Fundir (item igual, [JOGO-20]).
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	for mode: String in ["upgrade", "fuse", "shop"]:
		var tab: Button = PixelMenuPanel.make_button(_tab_title(mode))
		tab.custom_minimum_size = Vector2(0.0, 72.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_mode.bind(mode))
		tabs.add_child(tab)
		_tab_buttons[mode] = tab
	column.add_child(tabs)

	var selected: HBoxContainer = HBoxContainer.new()
	selected.add_theme_constant_override("separation", 16)
	_selected_slot = ItemSlot.new()
	_selected_slot.custom_minimum_size = Vector2(SELECTED_SLOT_PX, SELECTED_SLOT_PX)
	_selected_slot.disabled = true
	selected.add_child(_selected_slot)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	_selected_name = _label("Escolha um item", 32, Color.WHITE)
	texts.add_child(_selected_name)
	_selected_attrs = _label("", 20, Color(1, 1, 1, 0.75))
	texts.add_child(_selected_attrs)
	selected.add_child(texts)
	column.add_child(selected)

	_upgrade_section = VBoxContainer.new()
	_upgrade_section.add_theme_constant_override("separation", 12)
	column.add_child(_upgrade_section)
	_upgrade_section.add_child(_label("Escolha o que melhorar (novo = +1, reforçar = +2):", 20, Color(1, 1, 1, 0.6)))
	_attribute_box = VBoxContainer.new()
	_attribute_box.add_theme_constant_override("separation", 8)
	_upgrade_section.add_child(_attribute_box)
	_upgrade_button = PixelMenuPanel.make_button("Melhorar")
	_upgrade_button.custom_minimum_size = Vector2(0.0, UPGRADE_BUTTON_PX)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_upgrade_section.add_child(_upgrade_button)
	_stone_button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(""), "icon_diamond", 40)
	_stone_button.custom_minimum_size = Vector2(0.0, ATTRIBUTE_BUTTON_PX)
	_stone_button.add_theme_font_size_override("font_size", 24)
	_stone_button.visible = false
	_stone_button.pressed.connect(func() -> void:
		_use_stone = not _use_stone
		_refresh_button())
	_upgrade_section.add_child(_stone_button)

	# Fundir ([JOGO-20]): itens iguais da mochila e o botão.
	_fuse_section = VBoxContainer.new()
	_fuse_section.add_theme_constant_override("separation", 12)
	column.add_child(_fuse_section)
	_fuse_hint = _label("", 20, Color(1, 1, 1, 0.75))
	_fuse_section.add_child(_fuse_hint)
	_material_grid = GridContainer.new()
	_material_grid.columns = 5
	_material_grid.add_theme_constant_override("h_separation", 12)
	_material_grid.add_theme_constant_override("v_separation", 12)
	_fuse_section.add_child(_material_grid)
	_fuse_button = PixelMenuPanel.make_button("Fundir")
	_fuse_button.custom_minimum_size = Vector2(0.0, UPGRADE_BUTTON_PX)
	_fuse_button.pressed.connect(_on_fuse_pressed)
	_fuse_section.add_child(_fuse_button)
	# Loja ([JOGO-23]): Comprar / Vender e o botão.
	_shop_section = VBoxContainer.new()
	_shop_section.add_theme_constant_override("separation", 12)
	column.add_child(_shop_section)
	var shop_tabs: HBoxContainer = HBoxContainer.new()
	shop_tabs.add_theme_constant_override("separation", 12)
	for buy: bool in [true, false]:
		var shop_tab: Button = PixelMenuPanel.make_button("Comprar" if buy else "Vender", true)
		shop_tab.custom_minimum_size = Vector2(0.0, ATTRIBUTE_BUTTON_PX)
		shop_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_tab.pressed.connect(_set_shop_buy.bind(buy))
		shop_tabs.add_child(shop_tab)
		_shop_tabs[buy] = shop_tab
	_shop_section.add_child(shop_tabs)
	_shop_button = PixelMenuPanel.make_button("Comprar")
	_shop_button.custom_minimum_size = Vector2(0.0, UPGRADE_BUTTON_PX)
	_shop_button.pressed.connect(_on_shop_pressed)
	_shop_section.add_child(_shop_button)
	_result_label = _label("", 24, SUCCESS_COLOR)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_label)

	_pick_label = _label("Seus itens:", 20, Color(1, 1, 1, 0.6))
	column.add_child(_pick_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_pick_grid = GridContainer.new()
	_pick_grid.columns = 5
	_pick_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_pick_grid.add_theme_constant_override("h_separation", 12)
	_pick_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_pick_grid)

	var back: Button = PixelMenuPanel.make_button("Voltar")
	back.custom_minimum_size = Vector2(0.0, 88.0)
	back.pressed.connect(close_pressed.emit)
	column.add_child(back)
	# Forja por cima de tudo (último filho: o PanelContainer a estica sobre o conteúdo).
	_forge = UpgradeForge.new()
	_forge.finished.connect(_on_forge_finished)
	add_child(_forge)
	_set_mode("upgrade")


## Inventário novo (troca, melhoria): refaz a lista e mantém o item escolhido, se ainda existir.
func show_inventory(inventory: InventoryState) -> void:
	# Forjando: o "+N" novo só aparece no ápice.
	if _forge != null and _forge.is_running():
		_pending_inventory = inventory
		return
	_inventory = inventory
	_waiting = false
	if is_node_ready():
		_refresh()


## Moedas do personagem (atualiza o botão: faltando moedas ele desliga).
func set_gold(amount: int) -> void:
	if amount == _gold:
		return
	_gold = amount
	if is_node_ready():
		_gold_label.text = "%s moedas" % InventoryView.format_gold(amount)
		_refresh_button()


## Pedras de melhoria garantida da conta (Loja premium, [JOGO-27]); acabaram → desliga o "usar pedra".
func set_upgrade_stones(count: int) -> void:
	_stones = count
	if _stones <= 0:
		_use_stone = false
	if is_node_ready():
		_refresh_button()


## Resposta do servidor a uma tentativa ([signal Network.upgrade_result]).
func show_result(uid: String, success: bool, cost: int, attribute: String, level: int, points: int) -> void:
	var item: InventoryState.Item = _find(uid)
	var item_name: String = item.name if item != null else "Item"
	var message: String = ""
	if success:
		message = "Deu certo! %s +%d · %s +%d" % [item_name, level, ItemAttributes.title(attribute), points]
	else:
		message = "Falhou... perdeu %s moedas (continua +%d)" % [InventoryView.format_gold(cost), level]
	var color: Color = SUCCESS_COLOR if success else FAIL_COLOR
	if _forge.is_running():
		# Mostra no ápice da forja; a linha de resultado só depois que ela fechar.
		if success:
			_forge.set_result(true, "+%d!" % level, "%s +%d · %s +%d" % [item_name, level, ItemAttributes.title(attribute), points])
		else:
			_forge.set_result(false, "Falhou", "perdeu %s moedas · continua +%d" % [InventoryView.format_gold(cost), level])
		_pending_message = message
		_pending_color = color
		return
	_waiting = false
	_show_message(message, color)
	_refresh_button()


## Aviso (recusa do servidor: longe, sem moedas...).
func show_notice(text: String) -> void:
	# Recusa (longe, sem moedas...) no meio da forja: fecha ela sem resultado.
	if _forge != null and _forge.is_running():
		_forge.abort()
		_apply_pending()
	_waiting = false
	_sell_confirm_uid = ""
	_show_message(text, FAIL_COLOR)
	_refresh_button()
	_refresh_shop()


## Forja fechou: aplica o inventário novo e a mensagem guardados.
func _on_forge_finished() -> void:
	_apply_pending()
	_waiting = false
	if not _pending_message.is_empty():
		_show_message(_pending_message, _pending_color)
	_pending_message = ""
	_refresh_button()


func _apply_pending() -> void:
	if _pending_inventory != null:
		_inventory = _pending_inventory
		_pending_inventory = null
		_refresh()


func _show_message(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)


## Todos os itens: vestidos primeiro (na ordem dos slots), depois a mochila.
func _all_items() -> Array[InventoryState.Item]:
	var items: Array[InventoryState.Item] = []
	if _inventory == null:
		return items
	for slot: String in InventoryState.SLOTS:
		var worn: InventoryState.Item = _inventory.item_in(slot)
		if worn != null:
			items.append(worn)
	items.append_array(_inventory.bag)
	return items


func _find(uid: String) -> InventoryState.Item:
	for item: InventoryState.Item in _pick_items():
		if item.uid == uid:
			return item
	return null


func _refresh() -> void:
	_gold_label.text = "%s moedas" % InventoryView.format_gold(_gold)
	for child: Node in _pick_grid.get_children():
		child.queue_free()
	_pick_label.text = "À venda (peças +0):" if _in_shop_buy() else "Seus itens:"
	for item: InventoryState.Item in _pick_items():
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(PICK_SLOT_PX, PICK_SLOT_PX)
		view.show_item(item)
		view.drop_highlight = 1 if item.uid == _selected_uid else 0
		view.pressed.connect(_select.bind(item.uid))
		_pick_grid.add_child(view)
	_refresh_selected()


func _select(uid: String) -> void:
	if uid != _selected_uid:
		_sell_confirm_uid = ""
		_selected_attribute = ""
		_material_uid = ""
		_result_label.text = ""
	_selected_uid = uid
	_refresh()


## Item escolhido, a lista de atributos e o botão.
func _refresh_selected() -> void:
	var item: InventoryState.Item = _find(_selected_uid)
	for child: Node in _attribute_box.get_children():
		child.queue_free()
	_selected_slot.show_item(item)
	if item == null:
		_selected_uid = ""
		_selected_name.text = "Escolha um item"
		_selected_attrs.text = "Toque num item da lista embaixo."
		_refresh_button()
		_refresh_shop()
		return
	_selected_name.text = item.display_name()
	var parts: Array[String] = []
	for id: String in ItemAttributes.IDS:
		if item.attrs.has(id):
			parts.append("%s %d (%s)" % [ItemAttributes.title(id), item.attrs[id], ItemAttributes.effect_text(id, item.attrs[id])])
	_selected_attrs.text = "Sem melhorias ainda." if parts.is_empty() else "\n".join(parts)
	if item.xp_next > 0.0:
		_selected_attrs.text += "\nExperiência %d / %d rumo ao +%d" % [roundi(item.xp), roundi(item.xp_next), item.level + 1]
	_refresh_fuse()
	for id: String in item.upgrade_attributes:
		var have: int = item.attrs.get(id, 0)
		var text: String = ("%s   %d → %d   (+2)" % [ItemAttributes.title(id), have, have + 2]) if have > 0 else ("%s   novo   (+1)" % ItemAttributes.title(id))
		var button: Button = PixelMenuPanel.make_button(text, true)
		button.custom_minimum_size = Vector2(0.0, ATTRIBUTE_BUTTON_PX)
		button.add_theme_font_size_override("font_size", 26)
		button.toggle_mode = true
		button.button_pressed = id == _selected_attribute
		if id == _selected_attribute:
			button.add_theme_color_override("font_color", GOLD_COLOR)
			button.add_theme_color_override("font_pressed_color", GOLD_COLOR)
		button.pressed.connect(_choose_attribute.bind(id))
		_attribute_box.add_child(button)
	_refresh_button()
	_refresh_shop()


func _choose_attribute(id: String) -> void:
	_selected_attribute = id
	_result_label.text = ""
	_refresh_selected()


## Texto e estado do "Melhorar": preço e chance do item escolhido; desligado sem item/atributo, sem moedas ou esperando.
func _refresh_button() -> void:
	var item: InventoryState.Item = _find(_selected_uid)
	# Pedra garantida ([JOGO-27]): só quando há pedra e a chance não é 100%.
	var stone_useful: bool = item != null and _stones > 0 and item.upgrade_chance < 1.0
	_stone_button.visible = stone_useful
	if not stone_useful:
		_use_stone = false
	_stone_button.text = ("✓ Usando pedra garantida (%d)" if _use_stone else "Usar pedra garantida (%d)") % _stones
	_stone_button.modulate = Color(1, 1, 1) if _use_stone else Color(1, 1, 1, 0.6)
	if item == null:
		_upgrade_button.text = "Melhorar"
		_upgrade_button.disabled = true
		return
	var chance: String = "%d%%" % roundi(item.upgrade_chance * 100.0) if item.upgrade_chance >= 0.01 else "1%"
	if _use_stone:
		chance = "100%"
	_upgrade_button.text = "Melhorar para +%d · %s moedas · %s" % [item.level + 1, InventoryView.format_gold(item.upgrade_cost), chance]
	_upgrade_button.disabled = _waiting or _selected_attribute.is_empty() or _gold < item.upgrade_cost
	if not _waiting and _selected_attribute.is_empty() and _result_label.text.is_empty():
		_show_message("Escolha um atributo acima.", Color(1, 1, 1, 0.55))
	elif not _waiting and _gold < item.upgrade_cost and _result_label.text.is_empty():
		_show_message("Moedas insuficientes.", FAIL_COLOR)


func _on_upgrade_pressed() -> void:
	if _selected_uid.is_empty() or _selected_attribute.is_empty() or _waiting:
		return
	_waiting = true
	_result_label.text = ""
	_pending_message = ""
	_refresh_button()
	var item: InventoryState.Item = _find(_selected_uid)
	_forge.start(ItemIcons.item(item.item_id) if item != null else null, ItemIcons.set_color(item.set_name) if item != null else GOLD_COLOR)
	upgrade_requested.emit(_selected_uid, _selected_attribute, _use_stone)
	_use_stone = false


# --- Fundir ([JOGO-20]) ---

## Experiência para ir do nível [param level] ao seguinte (50 no +0, 10% a mais por nível, inteiro).
## ATENÇÃO: = levelXp/upgradeCost em mmo-server/src/items/fusion.ts e upgrade.ts (só para a prévia; o servidor decide).
static func level_xp(level: int) -> int:
	return roundi(50.0 * pow(1.1, maxi(level, 0)))


## Onde [param item] fica depois de receber [param xp]: [nível, experiência guardada, níveis ganhos].
static func preview_fusion(item: InventoryState.Item, xp: float) -> Array[float]:
	var level: int = item.level
	var banked: float = item.xp + xp
	var gained: int = 0
	while banked >= float(level_xp(level)):
		banked -= float(level_xp(level))
		level += 1
		gained += 1
	return [float(level), banked, float(gained)]


func _set_mode(mode: String) -> void:
	_mode = mode
	_material_uid = ""
	_result_label.text = ""
	for key: String in _tab_buttons.keys():
		var tab: Button = _tab_buttons[key]
		tab.modulate = Color(1, 1, 1) if key == mode else Color(1, 1, 1, 0.5)
		tab.text = ("✓ " if key == mode else "") + _tab_title(key)
	_upgrade_section.visible = mode == "upgrade"
	_fuse_section.visible = mode == "fuse"
	_shop_section.visible = mode == "shop"
	if mode == "shop" and _offers.is_empty():
		shop_open_requested.emit()
	_set_shop_buy(_shop_buy)


static func _tab_title(mode: String) -> String:
	match mode:
		"upgrade":
			return "Melhorar"
		"fuse":
			return "Fundir"
	return "Loja"


# --- Loja ([JOGO-23]) ---

## Lista da Loja chegou do servidor: [param items] (+0) e o preço de cada um ([param prices], mesma ordem).
func show_shop(items: Array[InventoryState.Item], prices: Array[int]) -> void:
	_offers = items
	_offer_prices.clear()
	for i: int in range(mini(items.size(), prices.size())):
		_offer_prices[items[i].uid] = prices[i]
	if is_node_ready() and _in_shop_buy():
		_refresh()


## Compra/venda feita ([signal Network.shop_result]): mensagem com o item e as moedas.
func show_shop_result(action: String, item_id: String, gold: int) -> void:
	var item_name: String = "Item"
	for offer: InventoryState.Item in _offers:
		if offer.item_id == item_id:
			item_name = offer.name
	_waiting = false
	_sell_confirm_uid = ""
	if action == "buy":
		_show_message("Comprou %s por %s moedas (foi para a mochila)." % [item_name, InventoryView.format_gold(gold)], SUCCESS_COLOR)
	else:
		_show_message("Vendeu %s por %s moedas." % [item_name, InventoryView.format_gold(gold)], GOLD_COLOR)
	_refresh_shop()


func _in_shop_buy() -> bool:
	return _mode == "shop" and _shop_buy


## O que a lista de baixo mostra: as peças à venda (Loja → Comprar) ou os seus itens.
func _pick_items() -> Array[InventoryState.Item]:
	return _offers if _in_shop_buy() else _all_items()


func _set_shop_buy(buy: bool) -> void:
	if buy != _shop_buy:
		_selected_uid = ""
	_shop_buy = buy
	_sell_confirm_uid = ""
	for key: bool in _shop_tabs.keys():
		var tab: Button = _shop_tabs[key]
		tab.button_pressed = key == buy
		tab.modulate = Color(1, 1, 1) if key == buy else Color(1, 1, 1, 0.5)
	_refresh()


## Texto e estado do botão da Loja: preço da peça (Comprar) ou quanto o ferreiro paga (Vender).
func _refresh_shop() -> void:
	if _shop_button == null or _mode != "shop":
		return
	var item: InventoryState.Item = _find(_selected_uid)
	if item == null:
		_shop_button.text = "Comprar" if _shop_buy else "Vender"
		_shop_button.disabled = true
		return
	if _shop_buy:
		var price: int = _offer_prices.get(item.uid, 0)
		_shop_button.text = "Comprar · %s moedas" % InventoryView.format_gold(price)
		_shop_button.disabled = _waiting or _gold < price
		if not _waiting and _gold < price and _result_label.text.is_empty():
			_show_message("Moedas insuficientes.", FAIL_COLOR)
		return
	var worn: bool = _inventory != null and not _inventory.bag.has(item)
	if worn:
		_shop_button.text = "Tire o item antes de vender"
		_shop_button.disabled = true
		return
	if _sell_confirm_uid == item.uid:
		_shop_button.text = "Confirmar: vender %s por %s?" % [item.display_name(), InventoryView.format_gold(item.sell_price)]
	else:
		_shop_button.text = "Vender por %s moedas" % InventoryView.format_gold(item.sell_price)
	_shop_button.disabled = _waiting


func _on_shop_pressed() -> void:
	var item: InventoryState.Item = _find(_selected_uid)
	if item == null or _waiting:
		return
	if _shop_buy:
		_waiting = true
		_result_label.text = ""
		shop_buy_requested.emit(item.item_id)
	elif item.level > 0 and _sell_confirm_uid != item.uid:
		# Item melhorado: o primeiro toque só pede confirmação ([JOGO-23]).
		_sell_confirm_uid = item.uid
	else:
		_waiting = true
		_result_label.text = ""
		shop_sell_requested.emit(item.uid)
	_refresh_shop()


## Itens iguais ao escolhido na mochila (os que podem ser sacrificados).
func _materials(item: InventoryState.Item) -> Array[InventoryState.Item]:
	var result: Array[InventoryState.Item] = []
	if item == null or _inventory == null:
		return result
	for other: InventoryState.Item in _inventory.bag:
		if other.uid != item.uid and other.item_id == item.item_id:
			result.append(other)
	return result


## Lista dos iguais, a prévia e o botão "Fundir".
func _refresh_fuse() -> void:
	if _fuse_section == null:
		return
	for child: Node in _material_grid.get_children():
		child.queue_free()
	var item: InventoryState.Item = _find(_selected_uid)
	var materials: Array[InventoryState.Item] = _materials(item)
	if _find(_material_uid) == null:
		_material_uid = ""
	for other: InventoryState.Item in materials:
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(PICK_SLOT_PX, PICK_SLOT_PX)
		view.show_item(other)
		view.drop_highlight = 1 if other.uid == _material_uid else 0
		view.pressed.connect(_choose_material.bind(other.uid))
		_material_grid.add_child(view)
	_fuse_button.disabled = true
	_fuse_button.text = "Fundir"
	if item == null:
		_fuse_hint.text = "Escolha o item que vai subir (lista de baixo)."
		return
	if materials.is_empty():
		_fuse_hint.text = "Nenhum %s igual na mochila para fundir." % item.name
		return
	var material: InventoryState.Item = _find(_material_uid)
	if material == null:
		_fuse_hint.text = "Escolha o item igual que vai ser sacrificado:"
		return
	var after: Array[float] = preview_fusion(item, material.fusion_xp)
	var level_after: int = int(after[0])
	var percent: int = roundi(after[1] / float(level_xp(level_after)) * 100.0)
	_fuse_hint.text = "%s some · +%d de experiência
%s +%d → +%d · %d%% do caminho para o +%d" % [
		material.display_name(), roundi(material.fusion_xp), item.name, item.level, level_after, percent, level_after + 1]
	_fuse_button.text = "Fundir (%s some)" % material.display_name()
	_fuse_button.disabled = _waiting


func _choose_material(uid: String) -> void:
	_material_uid = uid
	_result_label.text = ""
	_refresh_fuse()


func _on_fuse_pressed() -> void:
	if _selected_uid.is_empty() or _material_uid.is_empty() or _waiting:
		return
	_waiting = true
	_result_label.text = ""
	_pending_message = ""
	_fuse_button.disabled = true
	var item: InventoryState.Item = _find(_selected_uid)
	_forge.start(ItemIcons.item(item.item_id) if item != null else null, ItemIcons.set_color(item.set_name) if item != null else GOLD_COLOR)
	fuse_requested.emit(_selected_uid, _material_uid)


## Resposta do servidor a uma fusão ([signal Network.fuse_result]).
func show_fuse_result(uid: String, levels_gained: int, xp_gained: float, level: int, xp: float, xp_next: float) -> void:
	var item: InventoryState.Item = _find(uid)
	var item_name: String = item.name if item != null else "Item"
	var detail: String = "%s +%d · experiência %d / %d" % [item_name, level, roundi(xp), roundi(xp_next)]
	var big: String = ("+%d!" % level) if levels_gained > 0 else ("+%d exp" % roundi(xp_gained))
	var message: String = ("Fundiu! %s (+%d nível%s)" % [detail, levels_gained, "" if levels_gained == 1 else "s"]) if levels_gained > 0 else "Fundiu! %s" % detail
	_material_uid = ""
	if _forge.is_running():
		_forge.set_result(true, big, detail)
		_pending_message = message
		_pending_color = SUCCESS_COLOR
		return
	_waiting = false
	_show_message(message, SUCCESS_COLOR)


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
