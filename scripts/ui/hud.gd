class_name Hud
extends CanvasLayer
## HUD do jogo em retrato ([CLI-08]): vida/mana numa moldura de madeira ([WoodPanel]) no topo; embaixo, outra
## moldura de madeira junta as 6 cartas e a linha joystick | ataque simples (+ "Desfocar" embaixo) | menu,
## com espaços iguais entre eles e nas bordas. O Menu (Inventário, Configuração, "Sair da conta") fecha
## pelo X no canto ou tocando fora dele (no fundo escurecido).
##
## Só mostra e repassa toques: quem decide o que fazer com ataque/cartas é o [CombatController].

## O jogador pediu para sair da conta (botão "Sair da conta" no Menu).
signal logout_requested
## Tocou num item da mochila: vestir ([param uid]).
signal equip_requested(uid: String)
## Tocou num slot vestido: tirar para a mochila ([param slot] = "hand", "head", "chest", "feet").
signal unequip_requested(slot: String)

## Quantas cartas de habilidade a HUD mostra ([JOGO-01]: 3 da arma + cabeça + peito + pés).
const CARD_COUNT: int = 6
## Tempo (s) que um aviso fica na tela.
const _TOAST_SECONDS: float = 1.8

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _mana_label: Label = %ManaLabel
@onready var _status_label: Label = %StatusLabel
@onready var _toast: Label = %Toast
@onready var _card_row: HBoxContainer = %CardRow
@onready var _menu_panel: PanelContainer = %MenuPanel
## Fundo escurecido atrás dos painéis do menu: bloqueia toques no jogo e, tocado, fecha o menu.
@onready var _menu_dimmer: Panel = %MenuDimmer
@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _logout_button: Button = %LogoutButton
@onready var _equipped_grid: GridContainer = %EquippedGrid
@onready var _bag_title: Label = %BagTitle
@onready var _bag_list: VBoxContainer = %BagList

## Joystick de movimento (o [LocalPlayer] lê dele).
@onready var joystick: TouchJoystick = %TouchJoystick
## Botão do ataque simples.
@onready var attack_button: TouchActionButton = %AttackButton
## Botão pequeno embaixo do ataque: solta o alvo fixo ([JOGO-02]). Apagado sem alvo.
@onready var clear_target_button: TouchActionButton = %ClearTargetButton
@onready var _menu_button: TouchActionButton = %MenuButton

var _cards: Array[TouchActionButton] = []
var _toast_left: float = 0.0
## Há alvo fixo agora (liga o "Desfocar"); ver [method set_target_active].
var _has_target: bool = false


func _ready() -> void:
	for child: Node in _card_row.get_children():
		if child is TouchActionButton:
			var card: TouchActionButton = child
			_cards.append(card)
	_set_bar_color(_health_bar, Color(0.8, 0.22, 0.22))
	_set_bar_color(_mana_bar, Color(0.25, 0.45, 0.9))

	_menu_button.tapped.connect(_open_panel.bind(_menu_panel))
	(%InventoryButton as Button).pressed.connect(_open_panel.bind(_inventory_panel))
	(%SettingsButton as Button).pressed.connect(_open_panel.bind(_settings_panel))
	(%CloseMenuButton as Button).pressed.connect(_open_panel.bind(null))
	(%InventoryBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	(%SettingsBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	_logout_button.pressed.connect(_on_logout_pressed)
	_menu_dimmer.gui_input.connect(_on_dimmer_input)
	_toast.text = ""


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


## Carta [param index] (0..5).
func get_card(index: int) -> TouchActionButton:
	return _cards[index]


## Mostra as habilidades nas cartas, na ordem da HUD (até [constant CARD_COUNT]). null = slot vazio
## (carta apagada, sem texto).
func set_abilities(abilities: Array[AbilityView]) -> void:
	for i: int in range(_cards.size()):
		var ability: AbilityView = abilities[i] if i < abilities.size() else null
		_cards[i].text = ability.title if ability != null else ""
		_cards[i].caption = ability.slot_label if ability != null else ""
		_cards[i].enabled = ability != null and not is_menu_open()
		_cards[i].queue_redraw()


## Monta a tela de Inventário: os 4 slots vestidos e a mochila. Ver mmo-docs [JOGO-04].
func set_inventory(inventory: InventoryState) -> void:
	for child: Node in _equipped_grid.get_children() + _bag_list.get_children():
		child.queue_free()
	for slot: String in InventoryState.SLOTS:
		var item: InventoryState.Item = inventory.item_in(slot)
		var slot_label: String = AbilityView.SLOT_LABELS[slot]
		var button: Button = _inventory_button("%s\n%s" % [slot_label, item.name if item != null else "(vazio)"])
		button.disabled = item == null
		button.pressed.connect(unequip_requested.emit.bind(slot))
		_equipped_grid.add_child(button)
	_bag_title.text = "Mochila %d/%d (toque para vestir)" % [inventory.bag.size(), inventory.bag_capacity]
	if inventory.bag.is_empty():
		var empty: Label = Label.new()
		empty.text = "(vazia)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bag_list.add_child(empty)
	for item: InventoryState.Item in inventory.bag:
		var button: Button = _inventory_button("%s · %s" % [item.name, AbilityView.SLOT_LABELS[item.slot]])
		button.pressed.connect(equip_requested.emit.bind(item.uid))
		_bag_list.add_child(button)


func _inventory_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	return button


## Atualiza a barra de vida (valores absolutos).
func set_health(current: float, maximum: float) -> void:
	_set_bar(_health_bar, _health_label, current, maximum)


## Atualiza a barra de mana (valores absolutos).
func set_mana(current: float, maximum: float) -> void:
	_set_bar(_mana_bar, _mana_label, current, maximum)


## Texto pequeno do topo (ex.: "Username · Online: 3").
func set_status(text: String) -> void:
	_status_label.text = text


## Aviso curto no topo da tela, que some sozinho.
func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = _TOAST_SECONDS


## Liga/apaga o "Desfocar" conforme há alvo fixo ([param active]). Chamado a cada quadro pelo
## [CombatController]; só redesenha quando muda.
func set_target_active(active: bool) -> void:
	if active == _has_target:
		return
	_has_target = active
	_refresh_clear_target()


func _refresh_clear_target() -> void:
	clear_target_button.enabled = _has_target and not is_menu_open()
	clear_target_button.queue_redraw()


## true com algum painel do menu aberto.
func is_menu_open() -> bool:
	return _menu_panel.visible or _inventory_panel.visible or _settings_panel.visible


## Abre [param panel] e fecha os outros; null fecha tudo. Com menu aberto, os controles do jogo param.
func _open_panel(panel: PanelContainer) -> void:
	for candidate: PanelContainer in [_menu_panel, _inventory_panel, _settings_panel]:
		candidate.visible = candidate == panel
	var playing: bool = panel == null
	_menu_dimmer.visible = not playing
	joystick.set_process_input(playing)
	attack_button.enabled = playing
	_menu_button.enabled = playing
	_refresh_clear_target()
	for card: TouchActionButton in _cards:
		card.enabled = playing and not card.text.is_empty()
	# Solta o joystick se estava sendo usado quando o menu abriu.
	if not playing:
		joystick.release()


## Toque fora dos painéis (no fundo escurecido) fecha o menu. Só no apertar: o soltar do toque que abriu o
## menu não pode fechá-lo de novo.
func _on_dimmer_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		_menu_dimmer.accept_event()
		_open_panel(null)


func _on_logout_pressed() -> void:
	_logout_button.disabled = true
	logout_requested.emit()


func _set_bar(bar: ProgressBar, label: Label, current: float, maximum: float) -> void:
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(current, 0.0, maximum)
	label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("fill", fill)
