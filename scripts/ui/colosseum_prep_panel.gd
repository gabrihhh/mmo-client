class_name ColosseumPrepPanel
extends PanelContainer
## Preparação do Coliseu ([JOGO-28]): as **20 escolhas**. Em cima, **quantas por toque** (- N +, "Máx" = todas as que
## faltam). Aparecem as **4 peças** da build (conjunto e os pontos que cada uma já tem) → toca numa → aparecem os
## **atributos do conjunto dela** com quanto as N escolhas dão (cada uma: +1 se a peça ainda não tem, +2 se já tem;
## conta do Ferreiro, [JOGO-16]) → toca num → as N escolhas vão ao servidor e volta às 4 peças. Não dá para desfazer;
## o que sobrar no fim do minuto o servidor sorteia.
##
## Fica embaixo da tela e **não pausa o jogo** (dá para andar no seu lado da arena enquanto escolhe). "Esconder"
## recolhe; a [Hud] mostra de novo pelo botão "Escolhas". Quem decide é o servidor: os pontos e as escolhas que faltam
## vêm no placar ([ColosseumData.MatchState]).

## Escolheu [param attribute] na peça [param slot], [param count] vezes.
signal point_chosen(slot: String, attribute: String, count: int)
## Tocou em "Esconder".
signal hide_pressed

## Largura (px no espaço de referência 720×1280) e distância do pé da tela (acima dos controles).
const WIDTH_PX: float = 680.0
const BOTTOM_PX: float = 330.0
const DIM_COLOR: Color = Color(1, 1, 1, 0.7)
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
## Escolhas por preparação. ATENÇÃO: = PREP_CHOICES em mmo-server/src/arena/build.ts.
const PREP_CHOICES: int = 20

var _state: ColosseumData.MatchState = null
## Peça aberta (mostrando os atributos); "" = mostrando as 4 peças.
var _open_slot: String = ""
## Esperando o servidor confirmar a última escolha (evita dois toques virarem duas escolhas na mesma peça errada).
var _waiting: bool = false
var _title: Label = null
var _list: VBoxContainer = null
## Quantas escolhas cada toque num atributo usa (1 até as que faltam).
var _count: int = 1
var _count_label: Label = null


func _init() -> void:
	theme_type_variation = &"PixelPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -BOTTOM_PX
	custom_minimum_size = Vector2(WIDTH_PX, 0.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	_title = PixelMenuPanel.make_label("", GOLD_COLOR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var hide: Button = PixelMenuPanel.make_button("Esconder")
	hide.custom_minimum_size = Vector2(200.0, 72.0)
	hide.pressed.connect(hide_pressed.emit)
	header.add_child(hide)
	var amount: HBoxContainer = HBoxContainer.new()
	amount.add_theme_constant_override("separation", 10)
	column.add_child(amount)
	var minus: Button = _small_button("-")
	minus.custom_minimum_size = Vector2(88.0, 72.0)
	minus.alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.pressed.connect(_change_count.bind(-1))
	amount.add_child(minus)
	_count_label = PixelMenuPanel.make_label("", GOLD_COLOR)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.add_child(_count_label)
	var plus: Button = _small_button("+")
	plus.custom_minimum_size = Vector2(88.0, 72.0)
	plus.alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.pressed.connect(_change_count.bind(1))
	amount.add_child(plus)
	var max_button: Button = _small_button("Máx")
	max_button.custom_minimum_size = Vector2(120.0, 72.0)
	max_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	max_button.pressed.connect(_change_count.bind(PREP_CHOICES))
	amount.add_child(max_button)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	column.add_child(_list)


## Placar novo (pontos das peças e escolhas restantes).
func set_state(state: ColosseumData.MatchState) -> void:
	_state = state
	_waiting = false
	_refresh()


## true se ainda há escolhas a fazer nesta preparação.
func has_choices() -> bool:
	return _state != null and _state.phase == ColosseumData.PHASE_PREP and _state.choices_left > 0


func _refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	if _state == null:
		return
	if not has_choices():
		_title.text = "Escolhas feitas!" if _state.phase == ColosseumData.PHASE_PREP else ""
		_open_slot = ""
		return
	_title.text = "Escolhas: faltam %d de %d" % [_state.choices_left, PREP_CHOICES]
	_count = clampi(_count, 1, _state.choices_left)
	_count_label.text = "%d por toque" % _count
	var piece: ColosseumData.Piece = _piece(_open_slot)
	if piece == null:
		_open_slot = ""
		for each: ColosseumData.Piece in _state.pieces:
			var button: Button = _small_button("%s · %s  %s" % [ColosseumData.SLOT_NAMES.get(each.slot, each.slot), each.set_name, _attrs_text(each)])
			button.pressed.connect(_open_piece.bind(each.slot))
			_list.add_child(button)
		return
	_list.add_child(PixelMenuPanel.make_label("%s (%s): escolha um atributo" % [ColosseumData.SLOT_NAMES.get(piece.slot, piece.slot), piece.set_name], DIM_COLOR))
	for attribute: String in piece.allowed:
		var have: int = piece.attrs.get(attribute, 0)
		var label: String = "%s  +%d" % [ItemAttributes.title(attribute), _total_gain(have, _count)]
		if have > 0:
			label += "  (tem %d)" % have
		var button: Button = _small_button(label)
		button.disabled = _waiting
		button.pressed.connect(_choose.bind(piece.slot, attribute))
		_list.add_child(button)
	var back: Button = _small_button("Voltar às peças")
	back.pressed.connect(_open_piece.bind(""))
	_list.add_child(back)


func _open_piece(slot: String) -> void:
	_open_slot = slot
	_refresh()


func _choose(slot: String, attribute: String) -> void:
	if _waiting:
		return
	_waiting = true
	_open_slot = ""
	point_chosen.emit(slot, attribute, _count)
	_refresh()


## Muda quantas escolhas cada toque usa ([param delta] = ±1, ou [constant PREP_CHOICES] = todas as que faltam).
func _change_count(delta: int) -> void:
	var left: int = PREP_CHOICES if _state == null else maxi(1, _state.choices_left)
	_count = left if delta >= PREP_CHOICES else clampi(_count + delta, 1, left)
	_refresh()


## Pontos que [param count] escolhas dão num atributo em que a peça já tem [param have]: a 1ª num atributo novo vale
## +1, todas as outras +2 (mesma regra do servidor).
static func _total_gain(have: int, count: int) -> int:
	if count <= 0:
		return 0
	return 2 * count if have > 0 else 1 + 2 * (count - 1)


func _piece(slot: String) -> ColosseumData.Piece:
	if _state == null or slot.is_empty():
		return null
	for piece: ColosseumData.Piece in _state.pieces:
		if piece.slot == slot:
			return piece
	return null


## "Dano 3 · Crítico 1" (ou "sem pontos").
static func _attrs_text(piece: ColosseumData.Piece) -> String:
	var parts: Array[String] = []
	for attribute: String in ItemAttributes.IDS:
		var points: int = piece.attrs.get(attribute, 0)
		if points > 0:
			parts.append("%s %d" % [ItemAttributes.title(attribute), points])
	return "(sem pontos)" if parts.is_empty() else "(" + " · ".join(parts) + ")"


## Botão de lista mais baixo que o do Menu (cabe mais na tela).
static func _small_button(text: String) -> Button:
	var button: Button = PixelMenuPanel.make_button(text, true)
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.add_theme_font_size_override("font_size", 28)
	return button
