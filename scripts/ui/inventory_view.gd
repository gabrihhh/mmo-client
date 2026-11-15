class_name InventoryView
extends VBoxContainer
## Conteúdo da tela de Inventário ([CLI-10]), feito por código: a vitrine com o personagem em 3D e os slots vestidos
## ([PaperDoll]), a barra com as **moedas** ([JOGO-15]) e a lotação da mochila, uma linha de dica/aviso e a mochila
## em grade que rola.
##
## **Arrastar itens** (segurar o item ~0,25 s e arrastar, [ItemSlot]): o ícone segue o dedo e o alvo embaixo dele
## acende (verde = pode, vermelho = não pode). Ao soltar:
## - mochila → quadro vestido do mesmo slot, ou → boneco 3D: **veste** (o que estava ali volta para o lugar dele);
## - mochila → outra vaga da mochila: **troca de lugar** (vaga livre = vai para o fim);
## - vestido → vaga da mochila: **tira** para aquela vaga; se a vaga tem um item do mesmo slot, **troca** com ele.
## Quem faz é o servidor ([JOGO-04]); esta tela só pede (sinais) e se refaz quando o inventário novo chega.
## Arrastando perto da borda de cima/baixo da mochila, ela rola sozinha. Toque rápido num item abre a ficha.

## Tocou num item ([param equipped] = vestido) para abrir a ficha.
signal item_pressed(item: InventoryState.Item, equipped: bool)
## Tocou num slot vestido vazio.
signal empty_slot_pressed(slot: String)
## Pedidos ao servidor (ver [Network]): vestir o item [param uid] da mochila.
signal equip_requested(uid: String)
## Tirar o item do [param slot] para a vaga [param index] da mochila.
signal unequip_requested(slot: String, index: int)
## Trocar de lugar os itens das vagas [param from] e [param to] da mochila.
signal bag_move_requested(from: int, to: int)

## Lado (px) de cada quadro da mochila e colunas da grade.
const BAG_SLOT_PX: float = 120.0
const BAG_COLUMNS: int = 5
## Altura (px) da vitrine do boneco.
const DOLL_HEIGHT_PX: float = 500.0
## Dica que fica na linha de aviso quando não há aviso.
const HINT: String = "Segure um item e arraste para vestir ou organizar"
## Quanto tempo (s) um aviso fica no lugar da dica.
const NOTICE_SECONDS: float = 3.0
## Rolagem automática ao arrastar perto da borda da mochila: faixa (px) e velocidade (px/s).
const AUTO_SCROLL_EDGE_PX: float = 70.0
const AUTO_SCROLL_SPEED: float = 700.0
## Lado (px) do ícone que segue o dedo.
const GHOST_PX: float = 132.0
## Cor das moedas.
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)

var _doll: PaperDoll = null
var _gold_label: Label = null
var _bag_label: Label = null
var _hint_label: Label = null
var _bag_scroll: ScrollContainer = null
var _bag_grid: GridContainer = null
var _bag_slots: Array[ItemSlot] = []
var _inventory: InventoryState = null
var _notice_left: float = 0.0

## Arrasto em andamento: de onde saiu (vaga da mochila ou slot vestido) e o item.
var _drag_item: InventoryState.Item = null
var _drag_from_bag: int = -1
var _drag_from_slot: String = ""
var _drag_point: Vector2 = Vector2.INF
var _ghost: TextureRect = null


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_doll = PaperDoll.new()
	_doll.custom_minimum_size = Vector2(0.0, DOLL_HEIGHT_PX)
	_doll.slot_pressed.connect(_on_equipped_pressed)
	add_child(_doll)
	for slot: String in _doll.slot_views():
		var view: ItemSlot = _doll.slot_view(slot)
		view.drag_started.connect(_on_drag_started.bind(-1, slot))
		view.drag_moved.connect(_on_drag_moved)
		view.drag_ended.connect(_on_drag_ended)

	add_child(_build_status_row())

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_hint(HINT, false)
	add_child(_hint_label)

	_bag_scroll = ScrollContainer.new()
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_scroll.custom_minimum_size = Vector2(0.0, 260.0)
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Mesma folga do toque do quadro: deslizar menos que isso ainda pode virar "segurar para arrastar".
	_bag_scroll.scroll_deadzone = int(ItemSlot.DRAG_CANCEL_PX)
	add_child(_bag_scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = BAG_COLUMNS
	_bag_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_bag_grid.add_theme_constant_override("h_separation", 12)
	_bag_grid.add_theme_constant_override("v_separation", 12)
	_bag_scroll.add_child(_bag_grid)

	_ghost = TextureRect.new()
	_ghost.top_level = true
	_ghost.visible = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2(GHOST_PX, GHOST_PX)
	_ghost.z_index = 100
	add_child(_ghost)


## Barra das moedas (moeda pixel art + valor) e "Mochila N/M", numa faixa escura.
func _build_status_row() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.42, 0.24)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var coin: CoinIcon = CoinIcon.new()
	coin.custom_minimum_size = Vector2(40.0, 40.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 30)
	_gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.text = "0"
	row.add_child(_gold_label)
	_bag_label = Label.new()
	_bag_label.add_theme_font_size_override("font_size", 24)
	_bag_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_bag_label.text = "Mochila"
	row.add_child(_bag_label)
	return panel


## Mostra [param inventory]: quadros vestidos, boneco 3D (do jogador local) e a grade da mochila (vagas livres vazias
## até a capacidade).
func show_inventory(inventory: InventoryState) -> void:
	_cancel_drag()
	_inventory = inventory
	_doll.show_inventory(inventory)
	_refresh_character()
	for child: Node in _bag_grid.get_children():
		child.queue_free()
	_bag_slots.clear()
	_bag_label.text = "Mochila %d/%d" % [inventory.bag.size(), inventory.bag_capacity]
	for i: int in range(maxi(inventory.bag_capacity, inventory.bag.size())):
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(BAG_SLOT_PX, BAG_SLOT_PX)
		if i < inventory.bag.size():
			var item: InventoryState.Item = inventory.bag[i]
			view.show_item(item)
			view.draggable = true
			view.pressed.connect(item_pressed.emit.bind(item, false))
			view.drag_started.connect(_on_drag_started.bind(i, ""))
			view.drag_moved.connect(_on_drag_moved)
			view.drag_ended.connect(_on_drag_ended)
		else:
			view.show_item(null)
			view.disabled = true
		_bag_grid.add_child(view)
		_bag_slots.append(view)


## Moedas do personagem ([JOGO-15]), com separador de milhar ("12.345").
func set_gold(amount: int) -> void:
	_gold_label.text = format_gold(amount)


## "1234567" → "1.234.567".
static func format_gold(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out


## Aviso curto no lugar da dica (ex.: recusa do servidor, item no slot errado).
func show_notice(text: String) -> void:
	_set_hint(text, true)
	_notice_left = NOTICE_SECONDS


func _set_hint(text: String, notice: bool) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45) if notice else Color(1, 1, 1, 0.55))


## Boneco 3D = o jogador local (corpo e aparência vindos do servidor).
func _refresh_character() -> void:
	var network: Network = Network.instance
	if network == null:
		return
	_doll.show_character(network.get_player(network.player_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_refresh_character()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_set_hint(HINT, false)
	if _drag_item == null or _drag_point == Vector2.INF:
		return
	# Rolagem automática perto das bordas da mochila.
	var rect: Rect2 = _bag_scroll.get_global_rect()
	if _drag_point.x >= rect.position.x and _drag_point.x <= rect.end.x:
		var step: float = 0.0
		if _drag_point.y < rect.position.y + AUTO_SCROLL_EDGE_PX and _drag_point.y > rect.position.y - AUTO_SCROLL_EDGE_PX:
			step = -AUTO_SCROLL_SPEED * delta
		elif _drag_point.y > rect.end.y - AUTO_SCROLL_EDGE_PX and _drag_point.y < rect.end.y + AUTO_SCROLL_EDGE_PX:
			step = AUTO_SCROLL_SPEED * delta
		if step != 0.0:
			_bag_scroll.scroll_vertical += int(step)
			_update_highlights()


func _on_equipped_pressed(slot: String) -> void:
	var item: InventoryState.Item = _inventory.item_in(slot) if _inventory != null else null
	if item == null:
		empty_slot_pressed.emit(slot)
	else:
		item_pressed.emit(item, true)


func _on_drag_started(bag_index: int, slot: String) -> void:
	if _inventory == null:
		return
	_drag_from_bag = bag_index
	_drag_from_slot = slot
	_drag_item = _inventory.bag[bag_index] if bag_index >= 0 else _inventory.item_in(slot)
	if _drag_item == null:
		_cancel_drag()
		return
	_ghost.texture = ItemIcons.item(_drag_item.item_id)
	_ghost.visible = _ghost.texture != null


func _on_drag_moved(point: Vector2) -> void:
	if _drag_item == null:
		return
	_drag_point = point
	# Ícone um pouco acima do dedo (o dedo não esconde o que está levando).
	_ghost.global_position = point - Vector2(GHOST_PX / 2.0, GHOST_PX * 0.85)
	_update_highlights()


func _on_drag_ended(point: Vector2) -> void:
	if _drag_item == null:
		return
	var item: InventoryState.Item = _drag_item
	var from_bag: int = _drag_from_bag
	var from_slot: String = _drag_from_slot
	var target: Dictionary = _target_at(point)
	_cancel_drag()
	if target.is_empty():
		return
	var verdict: String = _verdict(item, from_bag, from_slot, target)
	if verdict == "ok":
		_apply_drop(item, from_bag, from_slot, target)
	elif not verdict.is_empty():
		show_notice(verdict)


## Alvo embaixo de [param point]: {"bag": índice} (vaga da mochila visível), {"slot": slot} (quadro vestido) ou
## {"doll": true} (o boneco). Vazio = nada.
func _target_at(point: Vector2) -> Dictionary:
	if point == Vector2.INF:
		return {}
	for slot: String in _doll.slot_views():
		if _doll.slot_view(slot).get_global_rect().has_point(point):
			return {"slot": slot}
	if _doll.character_global_rect().has_point(point):
		return {"doll": true}
	if _bag_scroll.get_global_rect().has_point(point):
		for i: int in range(_bag_slots.size()):
			if _bag_slots[i].get_global_rect().has_point(point):
				return {"bag": i}
	return {}


## "ok" = pode soltar ali; "" = soltar ali não faz nada (sem aviso); outro texto = não pode (o aviso).
func _verdict(item: InventoryState.Item, from_bag: int, from_slot: String, target: Dictionary) -> String:
	var slot_name: String = String(AbilityView.SLOT_LABELS.get(item.slot, item.slot)).to_lower()
	if target.has("slot"):
		var slot: String = target["slot"]
		if from_bag < 0:
			return ""
		if slot != item.slot:
			return "%s vai no quadro de %s" % [item.name, slot_name]
		return "ok"
	if target.has("doll"):
		return "ok" if from_bag >= 0 else ""
	var index: int = target["bag"]
	if from_bag >= 0:
		return "" if index == from_bag else "ok"
	# Vestido → mochila: cabe se a vaga tem item do mesmo slot (troca) ou se há vaga livre.
	if index < _inventory.bag.size() and _inventory.bag[index].slot == from_slot:
		return "ok"
	if _inventory.bag.size() >= _inventory.bag_capacity:
		return "Mochila cheia"
	return "ok"


func _apply_drop(item: InventoryState.Item, from_bag: int, from_slot: String, target: Dictionary) -> void:
	if target.has("slot") or target.has("doll"):
		equip_requested.emit(item.uid)
		return
	var index: int = target["bag"]
	if from_bag >= 0:
		bag_move_requested.emit(from_bag, index)
	elif index < _inventory.bag.size() and _inventory.bag[index].slot == from_slot:
		# Solto em cima de um item do mesmo slot: veste aquele (o vestido vai para a vaga dele).
		equip_requested.emit(_inventory.bag[index].uid)
	else:
		unequip_requested.emit(from_slot, index)


## Acende o alvo embaixo do dedo (verde/vermelho) e apaga os outros.
func _update_highlights() -> void:
	var target: Dictionary = _target_at(_drag_point)
	var verdict: String = "" if target.is_empty() else _verdict(_drag_item, _drag_from_bag, _drag_from_slot, target)
	var level: int = 0 if verdict.is_empty() else (1 if verdict == "ok" else -1)
	for slot: String in _doll.slot_views():
		_doll.slot_view(slot).drop_highlight = level if target.get("slot", "") == slot else 0
	for i: int in range(_bag_slots.size()):
		_bag_slots[i].drop_highlight = level if target.has("bag") and int(target["bag"]) == i else 0
	_doll.set_character_highlight(target.has("doll") and level > 0)


func _cancel_drag() -> void:
	_drag_item = null
	_drag_from_bag = -1
	_drag_from_slot = ""
	_drag_point = Vector2.INF
	if _ghost != null:
		_ghost.visible = false
	if _doll != null:
		for slot: String in _doll.slot_views():
			_doll.slot_view(slot).drop_highlight = 0
		_doll.set_character_highlight(false)
	for view: ItemSlot in _bag_slots:
		if is_instance_valid(view):
			view.drop_highlight = 0


## Moeda pixel art (desenhada em blocos, como os ícones): disco dourado com contorno escuro e brilho.
class CoinIcon:
	extends Control
	## "o" = contorno, "g" = ouro, "d" = ouro escuro (borda de baixo/direita), "w" = brilho.
	const PATTERN: Array[String] = [
		"...oooo...",
		".oogggdoo.",
		".ogwggggdo",
		"ogwgddggdo",
		"oggdggdgdo",
		"oggdggdgdo",
		"ogggddggdo",
		".ogggggddo",
		".oodddddo.",
		"...oooo...",
	]
	const COLORS: Dictionary[String, Color] = {
		"o": Color8(40, 24, 10), "g": Color8(250, 200, 70), "d": Color8(196, 128, 32), "w": Color8(255, 246, 190),
	}

	func _draw() -> void:
		var cell: float = minf(size.x, size.y) / float(PATTERN.size())
		var origin: Vector2 = (size - Vector2(cell, cell) * float(PATTERN.size())) / 2.0
		for row: int in range(PATTERN.size()):
			var line: String = PATTERN[row]
			for column: int in range(line.length()):
				var key: String = line[column]
				if COLORS.has(key):
					draw_rect(Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell)), COLORS[key])
