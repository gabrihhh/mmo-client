class_name Hud
extends CanvasLayer
## HUD do jogo em retrato ([CLI-08]): vida/mana numa moldura pixel art (variação de tema `PixelFrame`) no topo;
## logo abaixo dela, a linha de XP (cinza, enchendo de ciano) com o quadrado do nível na ponta direita ([JOGO-12]);
## embaixo, outra moldura igual junta as 6 cartas e a linha joystick | ataque simples (+ "Desfocar" embaixo) | menu,
## com espaços iguais entre eles e nas bordas. O Menu (Inventário, Configuração, "Sair da conta", cada um com ícone
## à esquerda) fecha pelo X no canto ou tocando fora dele (no fundo escurecido). Mapa ([CLI-11], [ZoneMap]): a zona
## inteira em pixel art, girada como a câmera, com você, monstros, bonecos/NPCs e jogadores ao vivo (tela inteira). Inventário ([CLI-10]), em tela
## inteira ([InventoryView]): o personagem em 3D com o que está vestido ([PaperDoll]), as moedas e a mochila em grade
## que rola; segurar e arrastar um item veste/tira/organiza; tocar num item abre
## a ficha dele ([ItemDetailPanel], também em tela inteira). Jogadores Próximos ([SOC-02], [NearbyPlayersPanel]):
## quem está a até 45 m; tocar num nome abre as opções sobre ele ([PlayerActionsPanel]: Atributos, Solicitar amizade
## se ainda não é amigo, Convidar para o grupo) e Atributos abre a tela dele ([AttributesPanel]). Grupo ([SOC-03],
## [GroupPanel]): botão no Menu só quando estou num grupo; lista os membros (líder marcado), tocar num membro abre as
## opções (Atributos, Solicitar amizade, Expulsar se sou o líder) e "Sair do grupo". Amigos ([SOC-04],
## [FriendsPanel]): botão sempre no Menu; lista com online/offline, tocar num amigo abre as opções (Atributos e
## Convidar para o grupo se ele está na minha zona; Remover amigo). Convite de grupo e pedido de amizade recebidos:
## janela Aceitar/Recusar no alto ([RequestPanel]), sem pausar o jogo. Configuração: "Solicitações de amizade" e
## "Convites de grupo", cada um Sempre/Ocultar (salvo na conta pelo servidor). Esses painéis são feitos por código
## ([PixelMenuPanel]) e criados no [method _ready].
##
## Só mostra e repassa toques: quem decide o que fazer com ataque/cartas é o [CombatController].

## O jogador pediu para sair da conta (botão "Sair da conta" no Menu).
signal logout_requested
## Apertou "Vestir" na ficha de um item da mochila ([param uid]).
signal equip_requested(uid: String)
## O espaço livre entre as molduras mudou (tela girou/redimensionou): ver [method play_area_center_ratio].
signal play_area_changed
## Tirar para a mochila ([param slot] = "hand", "head", "chest", "feet"): "Tirar" na ficha ([param index] = −1, no
## fim) ou arrastou o item vestido até a vaga [param index] da mochila ([CLI-10]).
signal unequip_requested(slot: String, index: int)
## Arrastou um item da mochila da vaga [param from] para a [param to] ([CLI-10]).
signal bag_move_requested(from: int, to: int)
## Pediu os Atributos do jogador [param player_id] ([SOC-02]); a resposta volta por [method show_attributes].
signal inspect_requested(player_id: String)
## Convidar [param player_id] para o grupo ([SOC-03]).
signal group_invite_requested(player_id: String)
## Respondeu ao convite de grupo de [param from_id] ([param accept] = Aceitar).
signal group_answered(from_id: String, accept: bool)
## Líder pediu para expulsar [param player_id] do grupo.
signal group_kick_requested(player_id: String)
## Tocou em "Sair do grupo".
signal group_leave_requested
## Pedir a amizade de [param player_id] ([SOC-04]).
signal friend_request_requested(player_id: String)
## Respondeu ao pedido de amizade de [param from_id] ([param accept] = Aceitar).
signal friend_answered(from_id: String, accept: bool)
## Remover [param player_id] dos amigos.
signal friend_remove_requested(player_id: String)
## Mudou a Configuração social ([constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE]); o servidor salva.
signal social_settings_requested(friend_requests: String, group_invites: String)

## Quantas cartas de habilidade a HUD mostra ([JOGO-01]: 3 da arma + cabeça + peito + pés).
const CARD_COUNT: int = 6
## Tempo (s) que um aviso fica na tela.
const _TOAST_SECONDS: float = 1.8
## Cores da linha de XP e do quadrado do nível ([CLI-08]): fundo cinza, preenchimento e número ciano, quadrado preto.
const XP_BACK_COLOR: Color = Color(0.35, 0.35, 0.38)
const XP_FILL_COLOR: Color = Color(0.0, 0.9, 1.0)
const LEVEL_BOX_COLOR: Color = Color(0.0, 0.0, 0.0)
## Linhas da Configuração social ([SOC-04]): campo do protocolo → texto, na ordem da tela.
const _SOCIAL_ROWS: Dictionary[String, String] = {
	"friendRequests": "Solicitações de amizade",
	"groupInvites": "Convites de grupo",
}

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _mana_label: Label = %ManaLabel
@onready var _xp_row: Control = %XpRow
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _level_box: PanelContainer = %LevelBox
@onready var _level_label: Label = %LevelLabel
@onready var _status_label: Label = %StatusLabel
@onready var _toast: Label = %Toast
@onready var _card_row: HBoxContainer = %CardRow
@onready var _vitals_frame: Control = $Root/VitalsFrame
@onready var _controls_frame: Control = $Root/ControlsFrame
@onready var _menu_panel: PanelContainer = %MenuPanel
## Fundo escurecido atrás dos painéis do menu: bloqueia toques no jogo e, tocado, fecha o menu.
@onready var _menu_dimmer: Panel = %MenuDimmer
@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
## Mapa da zona em tela inteira (Menu → Mapa).
@onready var _map_panel: PanelContainer = %MapPanel
@onready var _logout_button: Button = %LogoutButton
@onready var _inventory_view: InventoryView = %InventoryView
## Ficha do item tocado (abre por cima do inventário; "Voltar" volta para ele).
@onready var _item_detail: ItemDetailPanel = %ItemDetailPanel

## Joystick de movimento (o [LocalPlayer] lê dele).
@onready var joystick: TouchJoystick = %TouchJoystick
## Botão do ataque simples.
@onready var attack_button: TouchActionButton = %AttackButton
## Botão pequeno embaixo do ataque: solta o alvo fixo ([JOGO-02]). Apagado sem alvo.
@onready var clear_target_button: TouchActionButton = %ClearTargetButton
@onready var _menu_button: TouchActionButton = %MenuButton
## Barra de carregamento do lançamento (acima dos controles, [CLI-08]): o [CombatController] liga e desliga.
@onready var cast_bar: CastBar = %CastBar

var _cards: Array[TouchActionButton] = []
## Último inventário recebido (para a ficha saber o que está vestido no mesmo slot).
var _inventory: InventoryState = null
var _toast_left: float = 0.0
## Sobrevida do escudo por cima da barra de vida (criada no primeiro [method set_health]).
var _shield_fill: ColorRect = null
## Há alvo fixo agora (liga o "Desfocar"); ver [method set_target_active].
var _has_target: bool = false
## Painéis sociais ([SOC-02]), criados no [method _ready].
var _nearby_panel: NearbyPlayersPanel = null
var _actions_panel: PlayerActionsPanel = null
var _attributes_panel: AttributesPanel = null
## Grupo ([SOC-03]): painel do Menu → Grupo, janela do convite recebido e o botão "Grupo" do Menu (só com grupo).
var _group_panel: GroupPanel = null
## Janela dos pedidos recebidos (convite de grupo e pedido de amizade, [RequestPanel]).
var _invite_panel: RequestPanel = null
var _group_button: Button = null
## Meu grupo (null = sem grupo) e meu id, vindos da [Zone] por [method set_group].
var _group: GroupState = null
var _own_id: String = ""
## De onde as opções do jogador foram abertas (Jogadores Próximos ou Grupo): é para lá que o "Voltar" leva.
var _actions_origin: PanelContainer = null
## Altura do Menu com os botões da cena (px); os botões criados por código ("Amigos" e, com grupo, "Grupo") somam
## uma linha cada ([method _refresh_menu_height]).
var _menu_base_height: float = 0.0
## Amizade ([SOC-04]): painel do Menu → Amigos, o botão "Amigos" do Menu e a lista atual (vinda da [Zone]).
var _friends_panel: FriendsPanel = null
var _friends_button: Button = null
var _friends: FriendList = FriendList.new()
## Configuração social ([SOC-04]): opção atual de cada linha ("friendRequests"/"groupInvites" → SOCIAL_*) e os
## botões Sempre/Ocultar de cada uma (chave "linha|opção").
var _social: Dictionary[String, String] = {"friendRequests": Protocol.SOCIAL_ALWAYS, "groupInvites": Protocol.SOCIAL_ALWAYS}
var _social_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	for child: Node in _card_row.get_children():
		if child is TouchActionButton:
			var card: TouchActionButton = child
			_cards.append(card)
	_set_bar_color(_health_bar, Color(0.8, 0.22, 0.22))
	_set_bar_color(_mana_bar, Color(0.25, 0.45, 0.9))
	_style_experience()

	_build_social_panels()
	_menu_button.tapped.connect(_open_panel.bind(_menu_panel))
	(%PlayersButton as Button).pressed.connect(_open_panel.bind(_nearby_panel))
	(%InventoryButton as Button).pressed.connect(_open_panel.bind(_inventory_panel))
	(%SettingsButton as Button).pressed.connect(_open_panel.bind(_settings_panel))
	(%MapButton as Button).pressed.connect(_open_panel.bind(_map_panel))
	(%CloseMapButton as Button).pressed.connect(_open_panel.bind(null))
	(%MapBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	(%CloseMenuButton as Button).pressed.connect(_open_panel.bind(null))
	(%InventoryBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	(%CloseInventoryButton as Button).pressed.connect(_open_panel.bind(null))
	(%SettingsBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	_logout_button.pressed.connect(_on_logout_pressed)
	_inventory_view.item_pressed.connect(_show_item_detail)
	_inventory_view.empty_slot_pressed.connect(_on_empty_slot_pressed)
	_inventory_view.equip_requested.connect(equip_requested.emit)
	_inventory_view.unequip_requested.connect(unequip_requested.emit)
	_inventory_view.bag_move_requested.connect(bag_move_requested.emit)
	_item_detail.back_pressed.connect(_open_panel.bind(_inventory_panel))
	_item_detail.action_pressed.connect(_on_item_action)
	_menu_dimmer.gui_input.connect(_on_dimmer_input)
	_vitals_frame.resized.connect(play_area_changed.emit)
	_xp_row.resized.connect(play_area_changed.emit)
	_controls_frame.resized.connect(play_area_changed.emit)
	_toast.text = ""


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


## Altura (0 = topo, 1 = base da tela) do meio do espaço livre entre a moldura de vida/mana (com a linha de XP
## embaixo dela) e a dos controles. A câmera põe o boneco aí ([member IsometricCamera.screen_focus_y]), [CLI-08].
func play_area_center_ratio() -> float:
	var screen_height: float = _vitals_frame.get_viewport_rect().size.y
	if screen_height <= 0.0:
		return 0.5
	var top: float = maxf(_vitals_frame.get_global_rect().end.y, _xp_row.get_global_rect().end.y)
	var bottom: float = _controls_frame.get_global_rect().position.y
	return clampf((top + bottom) / 2.0 / screen_height, 0.0, 1.0)


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
		_cards[i].picture = ItemIcons.ability(ability.id) if ability != null else null
		_cards[i].enabled = ability != null and not is_menu_open()
		_cards[i].queue_redraw()


## Monta a tela de Inventário ([CLI-10]): personagem 3D, os 4 slots vestidos e a mochila ([InventoryView]).
## Ver mmo-docs [JOGO-04].
func set_inventory(inventory: InventoryState) -> void:
	_inventory = inventory
	_inventory_view.show_inventory(inventory)
	# A ficha aberta mostrava o inventário antigo: volta para a tela do inventário.
	if _item_detail.visible:
		_open_panel(_inventory_panel)


## Moedas do personagem ([JOGO-15]), mostradas no Inventário.
func set_gold(amount: int) -> void:
	_inventory_view.set_gold(amount)


## Abre a ficha de [param item] ([param equipped] = está vestido).
func _show_item_detail(item: InventoryState.Item, equipped: bool) -> void:
	var replaces: InventoryState.Item = null
	if not equipped and _inventory != null:
		replaces = _inventory.item_in(item.slot)
	_item_detail.show_item(item, equipped, replaces)
	_open_panel(_item_detail)


func _on_empty_slot_pressed(slot: String) -> void:
	_inventory_view.show_notice("Nada vestido em %s: arraste um item da mochila para cá" % AbilityView.SLOT_LABELS[slot].to_lower())


## "Vestir"/"Tirar" na ficha: pede ao servidor (a tela atualiza quando o inventário novo chegar).
func _on_item_action(item: InventoryState.Item, equipped: bool) -> void:
	if equipped:
		unequip_requested.emit(item.slot, -1)
	else:
		equip_requested.emit(item.uid)
	_open_panel(_inventory_panel)


## Atualiza a barra de vida (valores absolutos). [param shield] = escudo ativo: sobrevida azul-clara logo depois da
## vida, sem a barra crescer (com vida cheia cobre o fim dela), e "+N" no número ([JOGO-06]).
func set_health(current: float, maximum: float, shield: float = 0.0) -> void:
	_set_bar(_health_bar, _health_label, current, maximum)
	if _shield_fill == null:
		_shield_fill = ColorRect.new()
		_shield_fill.color = Color(0.55, 0.85, 1.0, 0.95)
		_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_bar.add_child(_shield_fill)
		_health_bar.move_child(_shield_fill, 0)  # embaixo do número
	var total: float = maxf(1.0, maximum)
	var shield_ratio: float = clampf(shield / total, 0.0, 1.0)
	_shield_fill.visible = shield_ratio > 0.001
	if _shield_fill.visible:
		var start: float = clampf(minf(current / total, 1.0 - shield_ratio), 0.0, 1.0)
		_shield_fill.position = Vector2(start * _health_bar.size.x, 0.0)
		_shield_fill.size = Vector2(shield_ratio * _health_bar.size.x, _health_bar.size.y)
		_health_label.text += "  +%d" % roundi(shield)


## Atualiza a barra de mana (valores absolutos).
func set_mana(current: float, maximum: float) -> void:
	_set_bar(_mana_bar, _mana_label, current, maximum)


## Atualiza a linha de XP e o quadrado do nível ([JOGO-12]): [param xp] juntada dentro do [param level] de
## [param xp_next] que ele pede (0 = linha cheia; hoje não acontece: sem nível máximo). Valores prontos do servidor.
func set_experience(level: int, xp: float, xp_next: float) -> void:
	_level_label.text = str(level)
	if xp_next <= 0.0:
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
	else:
		_xp_bar.max_value = xp_next
		_xp_bar.value = clampf(xp, 0.0, xp_next)


## Texto pequeno do topo (ex.: "Username · Online: 3").
func set_status(text: String) -> void:
	_status_label.text = text


## Aviso curto no topo da tela, que some sozinho.
func show_toast(text: String) -> void:
	# Com o Inventário aberto o aviso do topo fica atrás dele: aparece na linha de aviso do inventário.
	if _inventory_panel.visible:
		_inventory_view.show_notice(text)
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
	for panel: PanelContainer in _all_panels():
		if panel.visible:
			return true
	return false


## true com "Jogadores Próximos" aberto: a [Zone] manda a lista a cada snapshot ([method set_nearby_players]).
func is_nearby_open() -> bool:
	return _nearby_panel.visible


## Atualiza a lista de Jogadores Próximos ([param players] já em ordem de distância, [SOC-02]).
func set_nearby_players(players: Array[PlayerState]) -> void:
	_nearby_panel.show_players(players)


## Chegaram os Atributos pedidos: mostra se a tela deles ainda está esperando por esse jogador.
func show_attributes(attributes: PlayerAttributes) -> void:
	_attributes_panel.show_attributes(attributes)


## O pedido de Atributos falhou (ex.: o jogador saiu da zona): mostra [param message] na tela deles, se aberta.
func show_attributes_error(message: String) -> void:
	if _attributes_panel.visible:
		_attributes_panel.show_error(message)


## Cria os painéis sociais ([SOC-02]) por cima do fundo escurecido e liga X/"Voltar"/opções.
func _build_social_panels() -> void:
	var root: Control = $Root
	_nearby_panel = NearbyPlayersPanel.new()
	_actions_panel = PlayerActionsPanel.new()
	_attributes_panel = AttributesPanel.new()
	for panel: PixelMenuPanel in [_nearby_panel, _actions_panel, _attributes_panel]:
		root.add_child(panel)
		panel.close_pressed.connect(_open_panel.bind(null))
	_nearby_panel.back_pressed.connect(_open_panel.bind(_menu_panel))
	_actions_panel.back_pressed.connect(func() -> void: _open_panel(_actions_origin))
	_attributes_panel.back_pressed.connect(_open_panel.bind(_actions_panel))
	_nearby_panel.player_chosen.connect(_on_nearby_player_chosen)
	_actions_panel.option_chosen.connect(_on_player_option)
	_actions_origin = _nearby_panel
	_build_group_ui()
	_build_friends_ui()
	_build_social_settings()


## Grupo ([SOC-03]): painel do Menu → Grupo, botão "Grupo" no Menu (cópia do de Jogadores Próximos, logo depois dele;
## escondido sem grupo) e a janela do convite (acima de tudo, fora do ciclo do Menu: não pausa o jogo).
func _build_group_ui() -> void:
	var root: Control = $Root
	_group_panel = GroupPanel.new()
	root.add_child(_group_panel)
	_group_panel.close_pressed.connect(_open_panel.bind(null))
	_group_panel.back_pressed.connect(_open_panel.bind(_menu_panel))
	_group_panel.member_chosen.connect(_on_group_member_chosen)
	_group_panel.leave_pressed.connect(_on_leave_group_pressed)
	var players_button: Button = %PlayersButton
	_group_button = players_button.duplicate() as Button
	_group_button.name = "GroupButton"
	_group_button.unique_name_in_owner = false
	_group_button.text = "Grupo"
	_group_button.visible = false
	players_button.add_sibling(_group_button)
	_group_button.pressed.connect(_open_panel.bind(_group_panel))
	_menu_base_height = _menu_panel.offset_bottom - _menu_panel.offset_top
	_invite_panel = RequestPanel.new()
	root.add_child(_invite_panel)
	_invite_panel.answered.connect(_on_request_answered)


## Amizade ([SOC-04]): painel do Menu → Amigos e o botão "Amigos" (sempre visível, logo depois do "Grupo").
func _build_friends_ui() -> void:
	var root: Control = $Root
	_friends_panel = FriendsPanel.new()
	root.add_child(_friends_panel)
	_friends_panel.close_pressed.connect(_open_panel.bind(null))
	_friends_panel.back_pressed.connect(_open_panel.bind(_menu_panel))
	_friends_panel.friend_chosen.connect(_on_friend_chosen)
	_friends_panel.show_friends(_friends)
	var players_button: Button = %PlayersButton
	_friends_button = players_button.duplicate() as Button
	_friends_button.name = "FriendsButton"
	_friends_button.unique_name_in_owner = false
	_friends_button.text = "Amigos"
	_friends_button.visible = true
	_group_button.add_sibling(_friends_button)
	_friends_button.pressed.connect(_open_panel.bind(_friends_panel))
	_refresh_menu_height()


## Configuração ([SOC-04]): "Solicitações de amizade" e "Convites de grupo", cada uma com os botões Sempre/Ocultar
## (o escolhido aceso com ✓, o outro apagado), acima do "Voltar" do painel da cena.
func _build_social_settings() -> void:
	var back: Button = %SettingsBackButton
	var column: VBoxContainer = back.get_parent() as VBoxContainer
	for key: String in _SOCIAL_ROWS.keys():
		var label: Label = PixelMenuPanel.make_label(_SOCIAL_ROWS[key])
		column.add_child(label)
		column.move_child(label, back.get_index())
		var buttons: HBoxContainer = HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		column.add_child(buttons)
		column.move_child(buttons, back.get_index())
		for value: String in [Protocol.SOCIAL_ALWAYS, Protocol.SOCIAL_HIDE]:
			var button: Button = PixelMenuPanel.make_button("")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_social_option.bind(key, value))
			buttons.add_child(button)
			_social_buttons["%s|%s" % [key, value]] = button
	_refresh_social_buttons()


## Tocou em Sempre/Ocultar: manda a Configuração nova ao servidor (a tela muda quando ele confirmar).
func _on_social_option(key: String, value: String) -> void:
	if _social[key] == value:
		return
	var changed: Dictionary[String, String] = _social.duplicate()
	changed[key] = value
	social_settings_requested.emit(changed["friendRequests"], changed["groupInvites"])


## A Configuração social salva na conta mudou (auth_ok ou confirmação do servidor): acende a opção de cada linha.
func set_social_settings(friend_requests: String, group_invites: String) -> void:
	_social["friendRequests"] = friend_requests
	_social["groupInvites"] = group_invites
	_refresh_social_buttons()


func _refresh_social_buttons() -> void:
	for key: String in _social_buttons.keys():
		var parts: PackedStringArray = key.split("|")
		var selected: bool = _social.get(parts[0], Protocol.SOCIAL_ALWAYS) == parts[1]
		var text: String = "Sempre" if parts[1] == Protocol.SOCIAL_ALWAYS else "Ocultar"
		var button: Button = _social_buttons[key]
		button.text = ("✓ " + text) if selected else text
		button.modulate = Color(1, 1, 1) if selected else Color(1, 1, 1, 0.5)


## Altura do Menu: os botões da cena + "Amigos" + "Grupo" (só com grupo), centralizado.
func _refresh_menu_height() -> void:
	var extra_rows: int = (1 if _friends_button != null else 0) + (1 if _group != null else 0)
	var height: float = _menu_base_height + extra_rows * (PixelMenuPanel.BUTTON_HEIGHT_PX + 20.0)
	_menu_panel.offset_top = -height / 2.0
	_menu_panel.offset_bottom = height / 2.0


## Resposta na janela de pedidos: vai para o grupo ou para a amizade, conforme o tipo.
func _on_request_answered(kind: String, from_id: String, accept: bool) -> void:
	if kind == RequestPanel.KIND_FRIEND:
		friend_answered.emit(from_id, accept)
	else:
		group_answered.emit(from_id, accept)


## Chegou um pedido de amizade: janela Aceitar/Recusar no alto da tela ([RequestPanel]).
func show_friend_request(from_id: String, from_name: String, expires_in: float) -> void:
	_invite_panel.add_request(RequestPanel.KIND_FRIEND, from_id, from_name, expires_in)


## Minha lista de amigos mudou ([SOC-04]): atualiza o painel; se as opções abertas eram de um amigo que deixou de ser,
## volta para a lista. As opções de Jogadores Próximos/Grupo leem [member _friends] ao abrir.
func set_friends(list: FriendList) -> void:
	_friends = list
	_friends_panel.show_friends(list)
	if _actions_panel.visible and _actions_origin == _friends_panel and not list.has(_actions_panel.player_id):
		_open_panel(_friends_panel)


## Tocou num amigo: Atributos e Convidar para o grupo só se ele está na minha zona (o servidor só responde a quem
## está nela); Remover amigo sempre.
func _on_friend_chosen(player_id: String, title: String) -> void:
	var options: Array[PlayerActionsPanel.Option] = []
	var here: bool = Network.instance != null and Network.instance.get_player(player_id) != null
	if here:
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_ATTRIBUTES, "Atributos"))
		if _can_invite(player_id):
			options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GROUP_INVITE, "Convidar para o grupo"))
	options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_FRIEND_REMOVE, "Remover amigo"))
	_actions_origin = _friends_panel
	_actions_panel.show_options(player_id, title, options)
	_open_panel(_actions_panel)


## "Solicitar amizade" nas opções (Jogadores Próximos e Grupo), ou nada se ele já é meu amigo.
func _friend_request_options(player_id: String) -> Array[PlayerActionsPanel.Option]:
	var options: Array[PlayerActionsPanel.Option] = []
	if not _friends.has(player_id):
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_FRIEND, "Solicitar amizade"))
	return options


## Meu grupo mudou ([param group] null = sem grupo; [param own_id] = meu id): mostra/esconde o botão "Grupo" do Menu,
## atualiza o painel e, se saí do grupo com o painel dele aberto, volta ao Menu. Entrar num grupo descarta os outros
## convites pendentes (aceitar seria recusado).
func set_group(group: GroupState, own_id: String) -> void:
	var joined: bool = _group == null and group != null
	_group = group
	_own_id = own_id
	_group_button.visible = group != null
	_refresh_menu_height()
	_group_panel.show_group(group, own_id)
	if joined:
		_invite_panel.clear_kind(RequestPanel.KIND_GROUP)
	var from_group: bool = _actions_panel.visible and _actions_origin == _group_panel
	if group == null and (_group_panel.visible or from_group):
		_open_panel(_menu_panel)
	elif from_group and not group.has(_actions_panel.player_id):
		# O membro das opções abertas saiu do grupo: volta para a lista.
		_open_panel(_group_panel)


## Chegou um convite de grupo: janela Aceitar/Recusar no alto da tela ([RequestPanel]).
func show_group_invite(from_id: String, from_name: String, expires_in: float) -> void:
	_invite_panel.add_request(RequestPanel.KIND_GROUP, from_id, from_name, expires_in)


## true se posso convidar [param player_id]: sem grupo, ou sou o líder com vaga e ele não é do grupo ([SOC-03]).
func _can_invite(player_id: String) -> bool:
	if player_id == _own_id:
		return false
	if _group == null:
		return true
	return _group.leader_id == _own_id and not _group.has(player_id) and not _group.is_full()


## Tocou num membro no painel do Grupo: Atributos, Solicitar amizade (se ainda não é amigo) e, se sou o líder,
## Expulsar.
func _on_group_member_chosen(player_id: String, title: String) -> void:
	var options: Array[PlayerActionsPanel.Option] = [
		PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_ATTRIBUTES, "Atributos"),
	]
	options.append_array(_friend_request_options(player_id))
	if _group != null and _group.leader_id == _own_id:
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GROUP_KICK, "Expulsar do grupo"))
	_actions_origin = _group_panel
	_actions_panel.show_options(player_id, title, options)
	_open_panel(_actions_panel)


func _on_leave_group_pressed() -> void:
	group_leave_requested.emit()


## Tocou num jogador da lista: as opções sobre ele. "Convidar para o grupo" só aparece se posso convidar (sem grupo,
## ou líder com vaga) e ele não é do meu grupo ([SOC-03]); "Solicitar amizade" só se ainda não é amigo ([SOC-04]).
func _on_nearby_player_chosen(player_id: String, title: String) -> void:
	var options: Array[PlayerActionsPanel.Option] = [
		PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_ATTRIBUTES, "Atributos"),
	]
	options.append_array(_friend_request_options(player_id))
	if _can_invite(player_id):
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GROUP_INVITE, "Convidar para o grupo"))
	_actions_origin = _nearby_panel
	_actions_panel.show_options(player_id, title, options)
	_open_panel(_actions_panel)


func _on_player_option(option_id: String) -> void:
	var target: String = _actions_panel.player_id
	match option_id:
		PlayerActionsPanel.OPTION_ATTRIBUTES:
			_attributes_panel.show_loading(target, _actions_panel.player_title)
			_open_panel(_attributes_panel)
			inspect_requested.emit(target)
		PlayerActionsPanel.OPTION_GROUP_INVITE:
			# A resposta ("X aceitou/recusou") chega depois como aviso.
			# Continua nas opções da MESMA pessoa (voltar para a lista parecia perguntar "qual pessoa?").
			group_invite_requested.emit(target)
			show_toast("Convite enviado.")
		PlayerActionsPanel.OPTION_GROUP_KICK:
			group_kick_requested.emit(target)
			_open_panel(_group_panel)
		PlayerActionsPanel.OPTION_FRIEND:
			# A resposta ("X aceitou/recusou") chega depois como aviso.
			friend_request_requested.emit(target)
			show_toast("Pedido de amizade enviado.")
		PlayerActionsPanel.OPTION_FRIEND_REMOVE:
			# Volta à lista; ela se atualiza quando o servidor confirmar (e o aviso "X foi removido" aparece).
			friend_remove_requested.emit(target)
			_open_panel(_friends_panel)


## Todos os painéis do menu (um aberto por vez).
func _all_panels() -> Array[PanelContainer]:
	return [_menu_panel, _inventory_panel, _settings_panel, _item_detail, _map_panel, _nearby_panel, _actions_panel, _attributes_panel, _group_panel, _friends_panel]


## Abre [param panel] e fecha os outros; null fecha tudo. Com menu aberto, os controles do jogo param.
func _open_panel(panel: PanelContainer) -> void:
	for candidate: PanelContainer in _all_panels():
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


## Cores da linha de XP (cinza/ciano, cantos retos) e do quadrado do nível (preto, número ciano).
func _style_experience() -> void:
	_set_bar_color(_xp_bar, XP_FILL_COLOR)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = XP_BACK_COLOR
	_xp_bar.add_theme_stylebox_override("background", back)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = LEVEL_BOX_COLOR
	box.set_content_margin_all(2.0)
	_level_box.add_theme_stylebox_override("panel", box)
	_level_label.add_theme_color_override("font_color", XP_FILL_COLOR)


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	# Cantos retos: combina com a moldura pixel art.
	bar.add_theme_stylebox_override("fill", fill)
