class_name AttributesPanel
extends PixelMenuPanel
## Tela de Atributos de um jogador ([SOC-02]): nome (título), nível, vida e mana máximas, força pelo nível (dano,
## cura e escudo, em % a mais que no nível 0, [JOGO-12]) e os itens vestidos (ícone na cor do conjunto + nome).
## O servidor responde sob pedido ([constant Protocol.MSG_INSPECT] → [PlayerAttributes]); enquanto não chega,
## mostra "Carregando…".

## Lado do ícone de cada item (px).
const ICON_PX: float = 64.0
## Cor dos nomes dos atributos (à esquerda) e dos valores (à direita).
const KEY_COLOR: Color = Color(1, 1, 1, 0.7)
const VALUE_COLOR: Color = Color(1, 0.85, 0.6)

## Jogador pedido agora (a resposta de outro pedido antigo é ignorada).
var player_id: String = ""

var _content: VBoxContainer = null


func _init() -> void:
	super(0.0)
	set_title("Atributos")
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	body.add_child(_content)


## Pedido feito para [param id]: título com [param title] e "Carregando…" até a resposta.
func show_loading(id: String, title: String) -> void:
	player_id = id
	set_title(title)
	_clear()
	_content.add_child(PixelMenuPanel.make_label("Carregando…", KEY_COLOR))


## Mostra [param message] no lugar dos atributos (ex.: o jogador saiu da zona).
func show_error(message: String) -> void:
	_clear()
	_content.add_child(PixelMenuPanel.make_label(message, Color(1, 0.6, 0.5)))


## Mostra os atributos que chegaram. Ignora se forem de outro jogador (resposta atrasada de um pedido antigo).
func show_attributes(attributes: PlayerAttributes) -> void:
	if attributes.id != player_id:
		return
	set_title(attributes.name)
	_clear()
	_add_row("Nível", str(attributes.level))
	_add_row("Vida máxima", str(roundi(attributes.max_hp)))
	_add_row("Mana máxima", str(roundi(attributes.max_mana)))
	_add_row("Dano", _power_text(attributes.damage_power))
	_add_row("Cura", _power_text(attributes.healing_power))
	_add_row("Escudo", _power_text(attributes.shield_power))
	var equipped_title: Label = PixelMenuPanel.make_label("Equipado", KEY_COLOR)
	equipped_title.add_theme_font_size_override("font_size", 24)
	_content.add_child(equipped_title)
	for slot: String in InventoryState.SLOTS:
		var item: PlayerAttributes.EquippedItem = attributes.equipped[slot] if attributes.equipped.has(slot) else null
		_add_item_row(slot, item)


## Força pelo nível como texto: 1,03 → "+3%" (nível 0: "+0%").
static func _power_text(multiplier: float) -> String:
	return "+%d%%" % roundi((multiplier - 1.0) * 100.0)


func _clear() -> void:
	for child: Node in _content.get_children():
		child.queue_free()


## Linha "Nome ........ valor".
func _add_row(key: String, value: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var key_label: Label = PixelMenuPanel.make_label(key, KEY_COLOR)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	var value_label: Label = PixelMenuPanel.make_label(value, VALUE_COLOR)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value_label)
	_content.add_child(row)


## Linha de um slot vestido: ícone do item (moldura na cor do conjunto) + "Slot: nome"; vazio = "—".
func _add_item_row(slot: String, item: PlayerAttributes.EquippedItem) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var frame: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ItemSlot.BACKGROUND
	style.border_color = ItemIcons.set_color(item.set_name) if item != null else ItemSlot.EMPTY_BORDER
	style.set_border_width_all(ItemSlot.BORDER_PX)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemIcons.item(item.item_id) if item != null else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(icon)
	row.add_child(frame)
	var slot_label: String = AbilityView.SLOT_LABELS[slot] if AbilityView.SLOT_LABELS.has(slot) else slot
	var label: Label = PixelMenuPanel.make_label("%s: %s" % [slot_label, item.name if item != null else "—"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_content.add_child(row)
