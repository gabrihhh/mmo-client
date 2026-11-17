class_name TradePanel
extends PixelMenuPanel
## Janela da **troca entre jogadores** ([SOC-05]). Abre quando o servidor manda o primeiro estado da troca e fecha
## quando ela acaba (aconteceu, cancelada, longe, dano...). Só mostra e pede: quem decide tudo é o servidor.
##
## ```
## ┌──────── Troca com Fulano ──────── [X]┐
## │ Você oferece                          │
## │ [ícone][ícone][   ][   ][   ]         │  ← tocar num item tira da oferta
## │ [+ Adicionar item]                    │  ← abre a mochila: tocar num item põe na oferta
## │ [−100][−10]  30 moedas  [+10][+100]   │
## │ Fulano oferece                        │
## │ [ícone][   ]...   Espada Longa +3     │
## │ ● 0 moedas                            │
## │ Fulano confirmou ✓ / Trocando em 3…   │
## │ [Confirmar (2)]        [Cancelar]     │
## └───────────────────────────────────────┘
## ```
##
## "Confirmar" só acende [constant Protocol.TRADE_CONFIRM_DELAY] s depois da última mudança (o servidor diz quanto
## falta em `confirmIn`) e sem problema (mochila cheia). Qualquer mudança zera as confirmações (o servidor manda o
## estado novo). O X, "Cancelar" e tocar fora da janela cancelam a troca ([Hud]).

## Quero oferecer [param uids] (itens da mochila) e [param gold] moedas (a oferta inteira).
signal offer_changed(uids: Array[String], gold: int)
## Apertou "Confirmar".
signal confirm_pressed
## Apertou "Cancelar" ou o X.
signal cancel_pressed

## Altura do painel (px no espaço de referência 720×1280); o conteúdo rola se não couber.
const HEIGHT_PX: float = 1120.0
## Quadros por linha nas grades de itens.
const COLUMNS: int = 5
## Lado (px) de cada quadro de item.
const SLOT_PX: float = 100.0
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const OK_COLOR: Color = Color(0.5, 0.95, 0.5)
const PROBLEM_COLOR: Color = Color(1.0, 0.45, 0.4)
## Passos dos botões de moedas.
const GOLD_STEPS: Array[int] = [-100, -10, 10, 100]

var _state: TradeState = null
## Minha mochila atual (para escolher o que oferecer).
var _bag: Array[InventoryState.Item] = []
## Minhas moedas (todas, não só as oferecidas).
var _gold_total: int = 0
## Oferta que eu pedi por último (o servidor pode demorar a responder; toques seguidos partem daqui).
var _uids: Array[String] = []
var _gold: int = 0
## Segundos até "Confirmar" valer / da contagem final (−1 = sem contagem), contados aqui a partir do estado.
var _confirm_left: float = 0.0
var _countdown_left: float = -1.0

var _my_grid: GridContainer = null
var _add_button: Button = null
var _picker_label: Label = null
var _picker: GridContainer = null
var _gold_label: Label = null
var _their_title: Label = null
var _their_grid: GridContainer = null
var _their_names: Label = null
var _their_gold: Label = null
var _status: Label = null
var _confirm_button: Button = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Troca")
	back_button.visible = false
	close_pressed.connect(cancel_pressed.emit)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)

	column.add_child(PixelMenuPanel.make_label("Você oferece (toque para tirar)", GOLD_COLOR))
	_my_grid = _make_grid()
	column.add_child(_my_grid)
	_add_button = PixelMenuPanel.make_button("+ Adicionar item")
	_add_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_add_button.pressed.connect(_toggle_picker)
	column.add_child(_add_button)
	_picker_label = PixelMenuPanel.make_label("Sua mochila (toque para oferecer)", Color(1, 1, 1, 0.7))
	_picker_label.visible = false
	column.add_child(_picker_label)
	_picker = _make_grid()
	_picker.visible = false
	column.add_child(_picker)

	var gold_row: HBoxContainer = HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	column.add_child(gold_row)
	for i: int in GOLD_STEPS.size():
		var step: int = GOLD_STEPS[i]
		var button: Button = PixelMenuPanel.make_button(("%+d" % step).replace("-", "−"))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.custom_minimum_size = Vector2(110.0, 80.0)
		button.pressed.connect(_change_gold.bind(step))
		gold_row.add_child(button)
		# O número fica no meio: depois dos dois botões de tirar.
		if i == 1:
			_gold_label = PixelMenuPanel.make_label("", GOLD_COLOR)
			_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gold_row.add_child(_gold_label)

	_their_title = PixelMenuPanel.make_label("", GOLD_COLOR)
	column.add_child(_their_title)
	_their_grid = _make_grid()
	column.add_child(_their_grid)
	_their_names = PixelMenuPanel.make_label("", Color(1, 1, 1, 0.8))
	_their_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_their_names)
	_their_gold = PixelMenuPanel.make_label("", GOLD_COLOR)
	column.add_child(_their_gold)

	_status = PixelMenuPanel.make_label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	body.add_child(buttons)
	_confirm_button = PixelMenuPanel.make_button("Confirmar")
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(confirm_pressed.emit)
	buttons.add_child(_confirm_button)
	var cancel: Button = PixelMenuPanel.make_button("Cancelar")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(cancel_pressed.emit)
	buttons.add_child(cancel)


## true enquanto há uma troca aberta (do primeiro estado até [method clear]).
func is_active() -> bool:
	return _state != null


## Chegou o estado da troca (abriu ou mudou): redesenha tudo.
func show_state(state: TradeState) -> void:
	var opened: bool = _state == null
	_state = state
	_uids = state.my_uids()
	_gold = state.my_gold
	_confirm_left = state.confirm_in
	_countdown_left = state.countdown
	if opened:
		_set_picker_visible(false)
	set_title("Troca com %s" % state.partner_name)
	_their_title.text = "%s oferece" % state.partner_name
	_fill_grid(_my_grid, state.my_items, true)
	_fill_grid(_their_grid, state.their_items, false)
	var names: PackedStringArray = []
	for item: InventoryState.Item in state.their_items:
		names.append(item.display_name())
	_their_names.text = ", ".join(names) if not names.is_empty() else "Nenhum item."
	_their_gold.text = "● %d moedas" % state.their_gold
	_refresh_picker()
	_refresh_status()


## A troca acabou (aconteceu ou foi cancelada): esquece o estado.
func clear() -> void:
	_state = null
	_uids = []
	_gold = 0


## Minha mochila mudou (para a lista do "Adicionar item").
func show_inventory(inventory: InventoryState) -> void:
	_bag.clear()
	if inventory != null:
		_bag.append_array(inventory.bag)
	_refresh_picker()


## Minhas moedas mudaram.
func set_gold(amount: int) -> void:
	_gold_total = amount
	_refresh_status()


func _process(delta: float) -> void:
	if _state == null or not visible:
		return
	var before_confirm: int = ceili(_confirm_left)
	var before_count: int = ceili(_countdown_left)
	_confirm_left = maxf(0.0, _confirm_left - delta)
	if _countdown_left >= 0.0:
		_countdown_left = maxf(0.0, _countdown_left - delta)
	if ceili(_confirm_left) != before_confirm or ceili(_countdown_left) != before_count:
		_refresh_status()


func _make_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


## Enche [param grid] com um quadro por item (e quadros vazios até completar a linha). [param removable]: tocar tira
## o item da minha oferta.
func _fill_grid(grid: GridContainer, items: Array[InventoryState.Item], removable: bool) -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	var total: int = maxi(COLUMNS, ceili(float(items.size()) / COLUMNS) * COLUMNS)
	for i: int in total:
		var slot: ItemSlot = ItemSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		if i < items.size():
			var item: InventoryState.Item = items[i]
			slot.show_item(item)
			if removable:
				slot.pressed.connect(_remove_item.bind(item.uid))
		else:
			slot.show_item(null)
			slot.disabled = true
		grid.add_child(slot)


## Mochila sem o que já ofereci: tocar põe na oferta.
func _refresh_picker() -> void:
	if _picker == null or not _picker.visible:
		return
	var free: Array[InventoryState.Item] = []
	for item: InventoryState.Item in _bag:
		if not _uids.has(item.uid):
			free.append(item)
	for child: Node in _picker.get_children():
		child.queue_free()
	for item: InventoryState.Item in free:
		var slot: ItemSlot = ItemSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		slot.show_item(item)
		slot.pressed.connect(_add_item.bind(item.uid))
		_picker.add_child(slot)
	_picker_label.text = "Sua mochila (toque para oferecer)" if not free.is_empty() else "Nada mais na mochila."


func _toggle_picker() -> void:
	_set_picker_visible(not _picker.visible)


func _set_picker_visible(shown: bool) -> void:
	_picker.visible = shown
	_picker_label.visible = shown
	_add_button.text = "Fechar mochila" if shown else "+ Adicionar item"
	_refresh_picker()


func _add_item(uid: String) -> void:
	if _uids.has(uid):
		return
	_uids.append(uid)
	offer_changed.emit(_uids.duplicate(), _gold)


func _remove_item(uid: String) -> void:
	if not _uids.has(uid):
		return
	_uids.erase(uid)
	offer_changed.emit(_uids.duplicate(), _gold)


func _change_gold(step: int) -> void:
	var amount: int = clampi(_gold + step, 0, _gold_total)
	if amount == _gold:
		return
	_gold = amount
	_refresh_status()
	offer_changed.emit(_uids.duplicate(), _gold)


## Texto das moedas, a linha de situação e o botão "Confirmar".
func _refresh_status() -> void:
	if _gold_label != null:
		_gold_label.text = "%d de %d" % [_gold, _gold_total]
	if _state == null or _status == null:
		return
	var lines: PackedStringArray = []
	var color: Color = Color(1, 1, 1)
	if _countdown_left >= 0.0:
		lines.append("Trocando em %d…" % maxi(1, ceili(_countdown_left)))
		color = OK_COLOR
	else:
		if not _state.problem.is_empty():
			lines.append(_state.problem)
			color = PROBLEM_COLOR
		if _state.their_confirmed:
			lines.append("%s confirmou ✓" % _state.partner_name)
		if _state.my_confirmed:
			lines.append("Você confirmou ✓ — esperando %s" % _state.partner_name)
		if lines.is_empty():
			lines.append("Confira as duas ofertas e confirme.")
	_status.text = "\n".join(lines)
	_status.add_theme_color_override("font_color", color)
	var waiting: int = ceili(_confirm_left)
	_confirm_button.disabled = _state.my_confirmed or waiting > 0 or not _state.problem.is_empty() or _countdown_left >= 0.0
	_confirm_button.text = "Confirmar (%d)" % waiting if waiting > 0 else ("Confirmado ✓" if _state.my_confirmed else "Confirmar")
