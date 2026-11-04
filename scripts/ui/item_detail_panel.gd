class_name ItemDetailPanel
extends PanelContainer
## Ficha de um item ([CLI-10]): abre ao tocar num item do inventário. Mostra o ícone, nome, conjunto, slot e a
## descrição; depois o ataque simples (armas) e cada habilidade com a imagem dela e os números: dano, cura,
## escudo e quanto dura, alcance, raio, tempo de lançamento, recarga e mana ([method AbilityView.stats]).
## Embaixo: "Vestir" (item da mochila) ou "Tirar" (item vestido) e "Voltar".
##
## Montada em código a cada [method show_item]; os números vêm do servidor (só exibição, [JOGO-04]).

## Apertou "Vestir" ([param equipped] false: item da mochila) ou "Tirar" ([param equipped] true).
signal action_pressed(item: InventoryState.Item, equipped: bool)
## Apertou "Voltar" (volta para o inventário).
signal back_pressed

## Cor da etiqueta de cada tipo de número.
const STAT_COLORS: Dictionary[AbilityView.StatKind, Color] = {
	AbilityView.StatKind.DAMAGE: Color(0.62, 0.18, 0.14),
	AbilityView.StatKind.HEAL: Color(0.18, 0.5, 0.2),
	AbilityView.StatKind.SHIELD: Color(0.2, 0.36, 0.62),
	AbilityView.StatKind.MANA: Color(0.22, 0.3, 0.7),
	AbilityView.StatKind.TIME: Color(0.32, 0.3, 0.28),
	AbilityView.StatKind.OTHER: Color(0.38, 0.27, 0.16),
}
## Perfil do conjunto na ficha ([JOGO-09]): chave → rótulo.
## ATENÇÃO: chaves de SetProfile em mmo-server/src/items/catalog.ts.
const PROFILE_LABELS: Dictionary[String, String] = {"damage": "Dano", "health": "Vida", "healing": "Cura", "cooldown": "Recarga"}
## Nível → texto ("zero" aparece como traço).
const TIER_LABELS: Dictionary[String, String] = {"zero": "—", "low": "baixo", "medium": "médio", "high": "alto"}
## Nível → cor da etiqueta (mais forte = mais quente).
const TIER_COLORS: Dictionary[String, Color] = {
	"zero": Color(0.3, 0.3, 0.3),
	"low": Color(0.35, 0.42, 0.3),
	"medium": Color(0.55, 0.45, 0.15),
	"high": Color(0.6, 0.22, 0.14),
}
## Tamanho (px) da imagem da habilidade na ficha.
const ABILITY_ICON_PX: float = 84.0

var _item: InventoryState.Item = null
var _equipped: bool = false
var _content: VBoxContainer = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Mostra o item [param item]. [param equipped] true = está vestido (botão "Tirar"); [param replaces] = o que
## está vestido no mesmo slot (aviso "troca com"), ou null.
func show_item(item: InventoryState.Item, equipped: bool, replaces: InventoryState.Item = null) -> void:
	_item = item
	_equipped = equipped
	if _content != null:
		_content.queue_free()
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	add_child(_content)

	_content.add_child(_header(item))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	_content.add_child(scroll)
	if item.basic_attack != null:
		list.add_child(_ability_block(item.basic_attack, "Ataque simples"))
	for i: int in range(item.abilities.size()):
		list.add_child(_ability_block(item.abilities[i], "Carta %d" % (i + 1) if item.slot == "hand" else "Carta"))

	if not equipped and replaces != null:
		_content.add_child(_label("Vestir troca com: %s" % replaces.name, 20, Color(1, 0.9, 0.7, 0.8)))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var action: Button = _button("Tirar" if equipped else "Vestir")
	action.pressed.connect(func() -> void: action_pressed.emit(_item, _equipped))
	var back: Button = _button("Voltar")
	back.pressed.connect(back_pressed.emit)
	buttons.add_child(action)
	buttons.add_child(back)
	_content.add_child(buttons)


## Ícone grande + nome, "Conjunto · Slot" na cor do conjunto e a descrição.
func _header(item: InventoryState.Item) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var slot_view: ItemSlot = ItemSlot.new()
	slot_view.custom_minimum_size = Vector2(132, 132)
	slot_view.disabled = true
	slot_view.show_item(item)
	row.add_child(slot_view)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_child(_label(item.name, 34, Color.WHITE))
	texts.add_child(_label("%s · %s" % [item.set_name, AbilityView.SLOT_LABELS.get(item.slot, item.slot)], 22, ItemIcons.set_color(item.set_name).lightened(0.25)))
	texts.add_child(_label(item.description, 19, Color(1, 1, 1, 0.75)))
	# Perfil do conjunto (baixo/médio/alto) e vida extra da peça ([JOGO-09]).
	var chips: HFlowContainer = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for key: String in PROFILE_LABELS:
		if item.profile.has(key):
			var tier: String = item.profile[key]
			chips.add_child(_chip("%s: %s" % [PROFILE_LABELS[key], TIER_LABELS.get(tier, tier)], TIER_COLORS.get(tier, STAT_COLORS[AbilityView.StatKind.OTHER])))
	if item.bonus_hp > 0.0:
		chips.add_child(_chip("+%s de vida" % AbilityView.number(item.bonus_hp), STAT_COLORS[AbilityView.StatKind.HEAL]))
	if chips.get_child_count() > 0:
		texts.add_child(chips)
	row.add_child(texts)
	return row


## Bloco de uma habilidade: imagem, nome (com [param tag], ex. "Ataque simples"), descrição e as etiquetas.
func _ability_block(ability: AbilityView, tag: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	# Não segura o arrasto: rolar a ficha começando em cima de um bloco também funciona.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.07, 0.05, 0.75)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var picture: TextureRect = TextureRect.new()
	picture.custom_minimum_size = Vector2(ABILITY_ICON_PX, ABILITY_ICON_PX)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture.texture = ItemIcons.ability(ability.id)
	row.add_child(picture)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 6)
	texts.add_child(_label("%s  ·  %s" % [ability.title, tag], 26, Color(1, 0.92, 0.75)))
	if not ability.description.is_empty():
		texts.add_child(_label(ability.description, 19, Color(1, 1, 1, 0.75)))
	var chips: HFlowContainer = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for stat: Array in ability.stats():
		var text: String = stat[0]
		var kind: AbilityView.StatKind = stat[1]
		chips.add_child(_chip(text, STAT_COLORS[kind]))
	texts.add_child(chips)
	row.add_child(texts)
	return panel


## Etiqueta arredondada com [param text] em fundo [param color].
func _chip(text: String, color: Color) -> Control:
	var label: Label = _label(text, 18, Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", box)
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 32)
	return button
