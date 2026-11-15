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
## "Melhorar" abre a forja ([UpgradeForge]): a carga demora ~1,8 s e o resultado (e o inventário novo, com o "+N") só
## aparece no ápice, mesmo que o servidor tenha respondido antes.

## Apertou "Melhorar": item [param uid] com o atributo [param attribute].
signal upgrade_requested(uid: String, attribute: String)
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

var _gold_label: Label = null
var _selected_slot: ItemSlot = null
var _selected_name: Label = null
var _selected_attrs: Label = null
var _attribute_box: VBoxContainer = null
var _upgrade_button: Button = null
var _result_label: Label = null
var _pick_grid: GridContainer = null
var _forge: UpgradeForge = null
## Guardados enquanto a forja anima: o inventário novo e a mensagem do resultado (aplicados no fim).
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
	var close: Button = PixelMenuPanel.make_button("✕")
	close.custom_minimum_size = Vector2(72.0, 72.0)
	close.clip_text = false
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

	column.add_child(_label("Escolha o que melhorar (novo = +1, reforçar = +2):", 20, Color(1, 1, 1, 0.6)))
	_attribute_box = VBoxContainer.new()
	_attribute_box.add_theme_constant_override("separation", 8)
	column.add_child(_attribute_box)

	_upgrade_button = PixelMenuPanel.make_button("Melhorar")
	_upgrade_button.custom_minimum_size = Vector2(0.0, UPGRADE_BUTTON_PX)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	column.add_child(_upgrade_button)
	_result_label = _label("", 24, SUCCESS_COLOR)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_label)

	column.add_child(_label("Seus itens:", 20, Color(1, 1, 1, 0.6)))
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
	_refresh()


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
	_show_message(text, FAIL_COLOR)
	_refresh_button()


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
	for item: InventoryState.Item in _all_items():
		if item.uid == uid:
			return item
	return null


func _refresh() -> void:
	_gold_label.text = "%s moedas" % InventoryView.format_gold(_gold)
	for child: Node in _pick_grid.get_children():
		child.queue_free()
	for item: InventoryState.Item in _all_items():
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(PICK_SLOT_PX, PICK_SLOT_PX)
		view.show_item(item)
		view.drop_highlight = 1 if item.uid == _selected_uid else 0
		view.pressed.connect(_select.bind(item.uid))
		_pick_grid.add_child(view)
	_refresh_selected()


func _select(uid: String) -> void:
	if uid != _selected_uid:
		_selected_attribute = ""
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
		return
	_selected_name.text = item.display_name()
	var parts: Array[String] = []
	for id: String in ItemAttributes.IDS:
		if item.attrs.has(id):
			parts.append("%s %d (%s)" % [ItemAttributes.title(id), item.attrs[id], ItemAttributes.effect_text(id, item.attrs[id])])
	_selected_attrs.text = "Sem melhorias ainda." if parts.is_empty() else "\n".join(parts)
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


func _choose_attribute(id: String) -> void:
	_selected_attribute = id
	_result_label.text = ""
	_refresh_selected()


## Texto e estado do "Melhorar": preço e chance do item escolhido; desligado sem item/atributo, sem moedas ou esperando.
func _refresh_button() -> void:
	var item: InventoryState.Item = _find(_selected_uid)
	if item == null:
		_upgrade_button.text = "Melhorar"
		_upgrade_button.disabled = true
		return
	var chance: String = "%d%%" % roundi(item.upgrade_chance * 100.0) if item.upgrade_chance >= 0.01 else "1%"
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
	upgrade_requested.emit(_selected_uid, _selected_attribute)


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
