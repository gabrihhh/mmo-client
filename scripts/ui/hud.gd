class_name Hud
extends CanvasLayer
## HUD do jogo em retrato ([CLI-08]): vida/mana no topo, 6 cartas acima do joystick, ataque simples no
## canto inferior esquerdo e menu no direito (Inventário e Configuração, com o "Sair").
##
## Só mostra e repassa toques: quem decide o que fazer com ataque/cartas é o [CombatController].

## O jogador pediu para sair da conta (botão em Configuração).
signal logout_requested

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
@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _logout_button: Button = %LogoutButton

## Joystick de movimento (o [LocalPlayer] lê dele).
@onready var joystick: TouchJoystick = %TouchJoystick
## Botão do ataque simples.
@onready var attack_button: TouchActionButton = %AttackButton
@onready var _menu_button: TouchActionButton = %MenuButton

var _cards: Array[TouchActionButton] = []
var _toast_left: float = 0.0


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
	_toast.text = ""


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


## Carta [param index] (0..5).
func get_card(index: int) -> TouchActionButton:
	return _cards[index]


## Mostra as habilidades nas cartas, na ordem da HUD (até [constant CARD_COUNT]).
func set_abilities(abilities: Array[AbilityView]) -> void:
	for i: int in range(_cards.size()):
		var has_ability: bool = i < abilities.size()
		_cards[i].text = abilities[i].title if has_ability else ""
		_cards[i].caption = abilities[i].slot_label if has_ability else ""
		_cards[i].enabled = has_ability


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


## true com algum painel do menu aberto.
func is_menu_open() -> bool:
	return _menu_panel.visible or _inventory_panel.visible or _settings_panel.visible


## Abre [param panel] e fecha os outros; null fecha tudo. Com menu aberto, os controles do jogo param.
func _open_panel(panel: PanelContainer) -> void:
	for candidate: PanelContainer in [_menu_panel, _inventory_panel, _settings_panel]:
		candidate.visible = candidate == panel
	var playing: bool = panel == null
	joystick.set_process_input(playing)
	attack_button.enabled = playing
	_menu_button.enabled = playing
	for card: TouchActionButton in _cards:
		card.enabled = playing and not card.text.is_empty()
	# Solta o joystick se estava sendo usado quando o menu abriu.
	if not playing:
		joystick.release()


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
