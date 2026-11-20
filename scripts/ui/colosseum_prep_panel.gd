class_name ColosseumPrepPanel
extends PanelContainer
## Preparação do Coliseu ([JOGO-28]): as **20 escolhas**, uma por vez. Aparecem as **4 peças** da build (conjunto e
## os pontos que cada uma já tem) → toca numa → aparecem os **atributos do conjunto dela** com quanto cada um dá
## (+1 se a peça ainda não tem, +2 se já tem; conta do Ferreiro, [JOGO-16]) → toca num → a escolha vai ao servidor e
## volta às 4 peças. Não dá para desfazer; o que sobrar no fim do minuto o servidor sorteia.
##
## Fica embaixo da tela e **não pausa o jogo** (dá para andar no seu lado da arena enquanto escolhe). "Esconder"
## recolhe; a [Hud] mostra de novo pelo botão "Escolhas". Quem decide é o servidor: os pontos e as escolhas que faltam
## vêm no placar ([ColosseumData.MatchState]).

## Escolheu [param attribute] na peça [param slot].
signal point_chosen(slot: String, attribute: String)
## Tocou em "Esconder".
signal hide_pressed

## Largura (px no espaço de referência 720×1280) e distância do pé da tela (acima dos controles).
const WIDTH_PX: float = 680.0
const BOTTOM_PX: float = 330.0
const DIM_COLOR: Color = Color(1, 1, 1, 0.7)
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)

var _state: ColosseumData.MatchState = null
## Peça aberta (mostrando os atributos); "" = mostrando as 4 peças.
var _open_slot: String = ""
## Esperando o servidor confirmar a última escolha (evita dois toques virarem duas escolhas na mesma peça errada).
var _waiting: bool = false
var _title: Label = null
var _list: VBoxContainer = null


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
	_title.text = "Escolhas: faltam %d de 20" % _state.choices_left
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
		var label: String = "%s  +%d" % [ItemAttributes.title(attribute), piece.gain(attribute)]
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
	point_chosen.emit(slot, attribute)
	_refresh()


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
