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
## ([PixelMenuPanel]) e criados no [method _ready]. Troca ([SOC-05], [TradePanel]): "Trocar" nas opções de Jogadores
## Próximos (a até 10 m), pedido recebido na mesma janela Aceitar/Recusar e a janela da troca, que fechar = cancelar.
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
## Confirmou destruir o item [param uid] na ficha ([JOGO-24]).
signal item_destroy_requested(uid: String)
## Ferreiro ([JOGO-16]): apertou "Melhorar" no item [param uid] com o atributo [param attribute]; [param guaranteed] =
## gastar uma pedra garantida da Loja premium ([JOGO-27]).
signal upgrade_requested(uid: String, attribute: String, guaranteed: bool)
## Loja premium ([JOGO-27]): abriu (pede saldo/catálogo), comprar produto, comprar pacote, pedir o histórico.
signal premium_open_requested
signal premium_buy_requested(product_id: String)
signal premium_pack_requested(pack_id: String)
signal premium_history_requested
## Baú de acampamento ([JOGO-19]): apertou "Abrir baú" perto do baú [param chest_id] / tocou num item dele.
signal chest_open_requested(chest_id: String)
## Tela de morte → "Renascer" ([JOGO-21]).
signal respawn_requested
## Ferreiro → Fundir ([JOGO-20]): sacrificar [param material_uid] em [param target_uid].
signal fuse_requested(target_uid: String, material_uid: String)
## Loja do Ferreiro ([JOGO-23]): pedir a lista, comprar a peça [param item_id], vender o item [param uid].
signal shop_open_requested
signal shop_buy_requested(item_id: String)
signal shop_sell_requested(uid: String)
## Armazém ([JOGO-26]): guardar [param uid], tirar [param uid], comprar aba.
signal storage_put_requested(uid: String)
signal storage_take_requested(uid: String)
signal storage_buy_tab_requested
## Chat ([SOC-09]): mandar [param text] no [param channel] (para [param to], só no privado).
signal chat_send_requested(channel: String, text: String, to: String)
## Mercado ([JOGO-25]): buscar, meus anúncios, anunciar, comprar, cancelar/retirar.
signal market_list_requested(query: String, slot: String, sort: String, page: int)
signal market_mine_requested
signal market_sell_requested(uid: String, price: int)
signal market_buy_requested(listing_id: String)
signal market_cancel_requested(listing_id: String)
signal chest_take_requested(chest_id: String, loot_id: String)
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
## Mudou a Configuração social ([constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE]; [param profile] =
## PROFILE_*, [SOC-08]); o servidor salva.
signal social_settings_requested(friend_requests: String, group_invites: String, guild_invites: String, profile: String, trade_requests: String)
## Criar a guilda [param guild_name] / [param tag] ([SOC-06]).
signal guild_create_requested(guild_name: String, tag: String, description: String)
## Procurar guilda ([SOC-06]): pedir a lista / a ficha / enviar solicitação.
signal guild_list_requested(query: String)
signal guild_info_requested(guild_id: String)
signal guild_join_requested(guild_id: String)
## Líder/oficial respondeu ao pedido de [param player_id]; líder salvou a descrição.
signal guild_request_answered(player_id: String, accept: bool)
signal guild_description_saved(description: String)
## Convidar [param player_id] para a minha guilda.
signal guild_invite_requested(player_id: String)
## Respondeu ao convite de guilda de [param from_id].
signal guild_answered(from_id: String, accept: bool)
## Tocou em "Sair da guilda" (confirmado).
signal guild_leave_requested
## Expulsar [param player_id] da guilda.
signal guild_kick_requested(player_id: String)
## Líder muda o cargo de [param player_id] para [param role] (GuildState.ROLE_*).
signal guild_role_requested(player_id: String, role: String)
## Pediu a tabela de ranking [param category] / [param period] ([SOC-07]); a resposta volta por [method show_ranking].
signal ranking_requested(category: String, period: String)
## Troca ([SOC-05]): pedir para trocar com [param player_id] / responder ao pedido de [param from_id].
signal trade_request_requested(player_id: String)
signal trade_answered(from_id: String, accept: bool)
## Mudou a minha oferta (inteira): itens da mochila [param uids] e [param gold] moedas.
signal trade_offer_changed(uids: Array[String], gold: int)
## Apertou "Confirmar" / fechou a janela de troca (Cancelar, X ou tocando fora).
signal trade_confirm_requested
signal trade_cancel_requested

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
	"guildInvites": "Convites de guilda",
	"profile": "Perfil (quem vê seus Atributos)",
	"tradeRequests": "Pedidos de troca",
}
## Botões de cada linha da Configuração social: valor → texto (Perfil tem três, [SOC-08]).
const _SOCIAL_OPTIONS: Dictionary[String, Dictionary] = {
	"friendRequests": {Protocol.SOCIAL_ALWAYS: "Sempre", Protocol.SOCIAL_HIDE: "Ocultar"},
	"groupInvites": {Protocol.SOCIAL_ALWAYS: "Sempre", Protocol.SOCIAL_HIDE: "Ocultar"},
	"guildInvites": {Protocol.SOCIAL_ALWAYS: "Sempre", Protocol.SOCIAL_HIDE: "Ocultar"},
	"profile": {Protocol.PROFILE_PUBLIC: "Público", Protocol.PROFILE_FRIENDS: "Amigos", Protocol.PROFILE_NOBODY: "Ninguém"},
	"tradeRequests": {Protocol.SOCIAL_ALWAYS: "Sempre", Protocol.SOCIAL_HIDE: "Ocultar"},
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
@onready var _cast_bar_node: Control = %CastBar

## Distância (px no espaço de referência 720×1280) entre a HUD e a borda da ÁREA SEGURA da tela, em cima e embaixo
## (a mesma das laterais). Celular sem entalhe: a HUD fica quase na borda; com entalhe/câmera, desvia só o que o
## sistema reservar ([method _safe_insets], [CLI-08]).
const EDGE_MARGIN: float = 16.0
## Margens com que a cena foi desenhada (a moldura de cima a 80 px do topo, a de baixo a 120 px da base): o que é
## movido parte delas.
const SCENE_TOP_MARGIN: float = 80.0
const SCENE_BOTTOM_MARGIN: float = 120.0
## Maior reserva (px de referência) que aceitamos do sistema em cada borda (valor estranho de algum aparelho não
## esconde a HUD).
const MAX_SAFE_INSET: float = 160.0
## Offsets originais (cena) de quem acompanha a borda de cima / de baixo: nó → (offset_top, offset_bottom).
var _top_base: Dictionary[Control, Vector2] = {}
## Medidor de desempenho ([PerfOverlay], [INFRA-12]) e os botões Mostrar/Ocultar dele na Configuração.
var _perf_overlay: PerfOverlay = null
var _perf_buttons: Dictionary[bool, Button] = {}
var _bottom_base: Dictionary[Control, Vector2] = {}
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
## Altura do Menu com os botões da cena (px); os botões criados por código ("Amigos", "Guilda", "Ranking" e, com grupo, "Grupo") somam
## uma linha cada ([method _refresh_menu_height]).
var _menu_base_height: float = 0.0
## Amizade ([SOC-04]): painel do Menu → Amigos, o botão "Amigos" do Menu e a lista atual (vinda da [Zone]).
var _friends_panel: FriendsPanel = null
## Menu → Guilda ([SOC-06]) e a minha guilda (null = sem).
var _guild_panel: GuildPanel = null
var _guild_button: Button = null
var _guild: GuildState = null
## Menu → Ranking ([SOC-07]).
var _ranking_panel: RankingPanel = null
var _ranking_button: Button = null
## Menu → Loja premium ([JOGO-27]).
var _premium_panel: PremiumShopPanel = null
var _premium_button: Button = null
## Ferreiro ([JOGO-16]): tela de melhoria e o botão que aparece perto dele.
var _blacksmith_panel: BlacksmithPanel = null
## Baú do acampamento ([JOGO-19]): botão "Abrir baú" (perto de um baú aberto), a janela e o baú de perto ("" = nenhum).
var _chest_panel: ChestPanel = null
var _chest_button: Button = null
var _near_chest: String = ""
## Tela de morte ([JOGO-21]), por cima de tudo.
var _death_screen: DeathScreen = null
## Janela da troca ([SOC-05]): abre com o primeiro estado da troca, fecha quando ela acaba.
var _trade_panel: TradePanel = null
var _blacksmith_button: Button = null
## Armazém ([JOGO-26]): tela e botão (mesmo lugar do botão do Ferreiro; os dois ficam a 12 m, nunca juntos).
var _storage_panel: StoragePanel = null
var _storage_button: Button = null
## Mercado ([JOGO-25]): tela e botão (mesmo lugar do botão do Ferreiro/Armazém; ficam a 12 m um do outro).
var _market_panel: MarketPanel = null
var _market_button: Button = null
## Chat ([SOC-09]): painel, botão do chat (ícone de balões, com as não lidas) e o resumo das últimas mensagens em cima dos controles.
var _chat_panel: ChatPanel = null
var _chat_button: Button = null
## Bolinha vermelha com o número de não lidas, no canto de cima do balão do chat.
var _chat_badge: Label = null
var _chat_unread: int = 0
var _chat_feed: Label = null
var _chat_feed_lines: Array[String] = []
var _chat_feed_left: float = 0.0
## Quanto tempo (s) o resumo fica na tela depois da última mensagem.
const CHAT_FEED_SECONDS: float = 6.0
var _friends_button: Button = null
var _friends: FriendList = FriendList.new()
## Configuração social ([SOC-04]): opção atual de cada linha ("friendRequests"/"groupInvites" → SOCIAL_*) e os
## botões Sempre/Ocultar de cada uma (chave "linha|opção").
var _social: Dictionary[String, String] = {"friendRequests": Protocol.SOCIAL_ALWAYS, "groupInvites": Protocol.SOCIAL_ALWAYS, "guildInvites": Protocol.SOCIAL_ALWAYS, "profile": Protocol.PROFILE_PUBLIC, "tradeRequests": Protocol.SOCIAL_ALWAYS}
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
	# X vermelho em pixel art nos botões de fechar das cenas (a fonte não tem "✕").
	for close_name: String in ["CloseMapButton", "CloseMenuButton", "CloseInventoryButton"]:
		PixelMenuPanel.style_close_button(get_node("%" + close_name) as Button)
	(%SettingsBackButton as Button).pressed.connect(_open_panel.bind(_menu_panel))
	_logout_button.pressed.connect(_on_logout_pressed)
	_inventory_view.item_pressed.connect(_show_item_detail)
	_inventory_view.empty_slot_pressed.connect(_on_empty_slot_pressed)
	_inventory_view.equip_requested.connect(equip_requested.emit)
	_inventory_view.unequip_requested.connect(unequip_requested.emit)
	_inventory_view.bag_move_requested.connect(bag_move_requested.emit)
	_item_detail.back_pressed.connect(_open_panel.bind(_inventory_panel))
	_item_detail.action_pressed.connect(_on_item_action)
	_item_detail.destroy_confirmed.connect(_on_item_destroy)
	_menu_dimmer.gui_input.connect(_on_dimmer_input)
	_setup_safe_margins()
	_vitals_frame.resized.connect(play_area_changed.emit)
	_xp_row.resized.connect(play_area_changed.emit)
	_controls_frame.resized.connect(play_area_changed.emit)
	_toast.text = ""


func _process(delta: float) -> void:
	_fade_chat_feed(delta)
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


## Guarda as posições da cena e encosta a HUD nas bordas da área segura; refaz quando a tela muda de tamanho.
func _setup_safe_margins() -> void:
	for node: Control in [_vitals_frame, _xp_row, _status_label, _toast]:
		_top_base[node] = Vector2(node.offset_top, node.offset_bottom)
	for node: Control in [_controls_frame, _cast_bar_node]:
		_bottom_base[node] = Vector2(node.offset_top, node.offset_bottom)
	get_viewport().size_changed.connect(_apply_safe_margins)
	_apply_safe_margins()


## Parte de cima (vida/mana, XP, avisos) a [constant EDGE_MARGIN] px do topo da área segura e parte de baixo (cartas,
## joystick, ataque, menu e a barra de lançamento) a [constant EDGE_MARGIN] px da base dela. Mais espaço para o jogo
## no meio; a câmera recentraliza o boneco ([signal play_area_changed]).
func _apply_safe_margins() -> void:
	var insets: Vector2 = _safe_insets()
	var top_shift: float = insets.x + EDGE_MARGIN - SCENE_TOP_MARGIN
	var bottom_shift: float = SCENE_BOTTOM_MARGIN - (insets.y + EDGE_MARGIN)
	for node: Control in _top_base:
		node.offset_top = _top_base[node].x + top_shift
		node.offset_bottom = _top_base[node].y + top_shift
	for node: Control in _bottom_base:
		node.offset_top = _bottom_base[node].x + bottom_shift
		node.offset_bottom = _bottom_base[node].y + bottom_shift
	if _blacksmith_button != null:
		_place_blacksmith_button()
	if _storage_button != null:
		_place_storage_button()
	if _market_button != null:
		_place_market_button()
	if _chat_button != null:
		_place_chat_ui()
	if _perf_overlay != null:
		_perf_overlay.offset_bottom = _controls_frame.offset_top - 4.0
		_perf_overlay.offset_top = _controls_frame.offset_top - 30.0
	play_area_changed.emit()


## Quanto o sistema reserva em cima e embaixo (x = topo, y = base), em px do espaço de referência: entalhe/câmera
## frontal, cantos, barra de gestos. Lido de [method DisplayServer.get_display_safe_area] (só no celular; no PC, 0).
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.y <= 0:
		return Vector2.ZERO
	var window_position: Vector2i = DisplayServer.window_get_position()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var top_px: float = maxf(0.0, float(safe.position.y - window_position.y))
	var bottom_px: float = maxf(0.0, float(window_position.y + window_size.y - safe.end.y))
	var scale_factor: float = get_viewport().get_visible_rect().size.y / float(window_size.y)
	return Vector2(minf(top_px * scale_factor, MAX_SAFE_INSET), minf(bottom_px * scale_factor, MAX_SAFE_INSET))


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
	_blacksmith_panel.show_inventory(inventory)
	_storage_panel.show_inventory(inventory)
	_market_panel.show_inventory(inventory)
	_trade_panel.show_inventory(inventory)
	# A ficha aberta mostrava o inventário antigo: volta para a tela do inventário.
	if _item_detail.visible:
		_open_panel(_inventory_panel)


## Moedas do personagem ([JOGO-15]), mostradas no Inventário.
func set_gold(amount: int) -> void:
	_inventory_view.set_gold(amount)
	_blacksmith_panel.set_gold(amount)
	_storage_panel.set_gold(amount)
	_market_panel.set_gold(amount)
	_trade_panel.set_gold(amount)


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


## "Sim" em destruir: pede ao servidor e volta para o inventário (o item some quando o inventário novo chegar).
func _on_item_destroy(item: InventoryState.Item) -> void:
	item_destroy_requested.emit(item.uid)
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
	_level_label.text = LevelText.short(level)
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
	if _blacksmith_panel.visible:
		_blacksmith_panel.show_notice(text)
	if _storage_panel.visible:
		_storage_panel.show_notice(text)
	if _market_panel.visible:
		_market_panel.show_notice(text)
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
	_build_guild_ui()
	_build_ranking_ui()
	_build_premium_ui()
	_build_social_settings()
	_build_perf_setting()
	_build_blacksmith_ui()
	_build_storage_ui()
	_build_market_ui()
	_build_chat_ui()
	_build_chest_ui()
	_build_trade_ui()
	_death_screen = DeathScreen.new()
	_death_screen.respawn_pressed.connect(respawn_requested.emit)
	# Último filho da HUD: fica por cima de painéis, joystick e cartas.
	add_child(_death_screen)


## Ferreiro ([JOGO-16]): botão "Ferreiro" acima da moldura dos controles (só aparece perto dele,
## [method set_blacksmith_near]) e a tela de melhoria em tela inteira.
func _build_blacksmith_ui() -> void:
	var root: Control = $Root
	_blacksmith_panel = BlacksmithPanel.new()
	root.add_child(_blacksmith_panel)
	_blacksmith_panel.close_pressed.connect(_open_panel.bind(null))
	_blacksmith_panel.upgrade_requested.connect(upgrade_requested.emit)
	_blacksmith_panel.fuse_requested.connect(fuse_requested.emit)
	_blacksmith_panel.shop_open_requested.connect(shop_open_requested.emit)
	_blacksmith_panel.shop_buy_requested.connect(shop_buy_requested.emit)
	_blacksmith_panel.shop_sell_requested.connect(shop_sell_requested.emit)
	_blacksmith_button = PixelMenuPanel.make_button("⚒ Ferreiro")
	_blacksmith_button.custom_minimum_size = Vector2(260.0, 84.0)
	_blacksmith_button.visible = false
	_blacksmith_button.pressed.connect(_open_panel.bind(_blacksmith_panel))
	# Antes do fundo escurecido do Menu (fica atrás dos painéis).
	root.add_child(_blacksmith_button)
	root.move_child(_blacksmith_button, _menu_dimmer.get_index())
	_controls_frame.resized.connect(_place_blacksmith_button)
	_place_blacksmith_button()


func _place_blacksmith_button() -> void:
	var view: Vector2 = ($Root as Control).size
	_blacksmith_button.size = _blacksmith_button.custom_minimum_size
	_blacksmith_button.position = Vector2((view.x - _blacksmith_button.size.x) / 2.0, _controls_frame.position.y - _blacksmith_button.size.y - 16.0)


## Perto (ou longe) de um ferreiro vivo ([JOGO-16]): mostra/esconde o botão "Ferreiro"; longe, fecha a tela dele.
func set_blacksmith_near(near: bool) -> void:
	if _blacksmith_button.visible != near:
		_blacksmith_button.visible = near
		_place_blacksmith_button()
	if not near and _blacksmith_panel.visible:
		_open_panel(null)
		show_toast("Você se afastou do ferreiro")


## Mercado ([JOGO-25]): botão "Mercado" (moeda) no lugar do botão do Ferreiro (só perto da tenda,
## [method set_market_near]) e a tela do Mercado.
func _build_market_ui() -> void:
	var root: Control = $Root
	_market_panel = MarketPanel.new()
	root.add_child(_market_panel)
	_market_panel.close_pressed.connect(_open_panel.bind(null))
	_market_panel.list_requested.connect(market_list_requested.emit)
	_market_panel.mine_requested.connect(market_mine_requested.emit)
	_market_panel.sell_requested.connect(market_sell_requested.emit)
	_market_panel.buy_requested.connect(market_buy_requested.emit)
	_market_panel.cancel_requested.connect(market_cancel_requested.emit)
	_market_button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button("Mercado"), "icon_coin")
	_market_button.custom_minimum_size = Vector2(260.0, 84.0)
	_market_button.visible = false
	_market_button.pressed.connect(_open_panel.bind(_market_panel))
	root.add_child(_market_button)
	root.move_child(_market_button, _menu_dimmer.get_index())
	_controls_frame.resized.connect(_place_market_button)
	_place_market_button()


func _place_market_button() -> void:
	var view: Vector2 = ($Root as Control).size
	_market_button.size = _market_button.custom_minimum_size
	_market_button.position = Vector2((view.x - _market_button.size.x) / 2.0, _controls_frame.position.y - _market_button.size.y - 16.0)


## Perto (ou longe) da tenda do Mercador ([JOGO-25]): mostra/esconde o botão; longe, fecha a tela.
func set_market_near(near: bool) -> void:
	if _market_button.visible != near:
		_market_button.visible = near
		_place_market_button()
	if not near and _market_panel.visible:
		_open_panel(null)
		show_toast("Você se afastou do Mercador")


## Mercado: página da busca, seus anúncios e ação feita ([Network]).
func show_market_page(listings: Array[MarketListing], total: int, page: int, page_size: int) -> void:
	_market_panel.show_page(listings, total, page, page_size)


func show_market_mine(listings: Array[MarketListing], max_listings: int) -> void:
	_market_panel.show_mine(listings, max_listings)


func show_market_result(action: String, item_name: String, price: int, gold: int) -> void:
	_market_panel.show_result(action, item_name, price, gold)


## Um item seu vendeu no Mercado (ao vivo ou ao entrar): aviso no topo.
func show_market_sold(item_name: String, price: int, buyer_name: String) -> void:
	show_toast("Mercado: %s vendeu por %s moedas para %s!" % [item_name, InventoryView.format_gold(price), buyer_name])


## Chat ([SOC-09]): botão do chat (só o sprite do balão de fala, sem moldura; não lidas numa bolinha vermelha) à direita, logo acima da moldura dos controles (o do Ferreiro/Armazém fica no meio),
## o painel na metade de baixo e o resumo das 2 últimas mensagens à esquerda, que some em [constant CHAT_FEED_SECONDS] s.
func _build_chat_ui() -> void:
	var root: Control = $Root
	_chat_panel = ChatPanel.new()
	root.add_child(_chat_panel)
	_chat_panel.close_pressed.connect(_open_panel.bind(null))
	_chat_panel.send_requested.connect(chat_send_requested.emit)
	# Só o sprite do balão de fala (`icon_speech`: branco, com as reticências), sem a moldura de botão (flat); escurece um pouco
	# enquanto é tocado.
	_chat_button = PixelMenuPanel.set_icon(Button.new(), "icon_speech", 72)
	_chat_button.flat = true
	_chat_button.focus_mode = Control.FOCUS_NONE
	_chat_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chat_button.add_theme_color_override("icon_pressed_color", Color(0.7, 0.7, 0.7))
	_chat_button.add_theme_color_override("icon_hover_pressed_color", Color(0.7, 0.7, 0.7))
	_chat_button.custom_minimum_size = Vector2(88.0, 88.0)
	_chat_button.pressed.connect(open_chat)
	_chat_badge = Label.new()
	_chat_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chat_badge.add_theme_font_size_override("font_size", 20)
	_chat_badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.85, 0.15, 0.12)
	badge_style.set_corner_radius_all(14)
	badge_style.content_margin_left = 6.0
	badge_style.content_margin_right = 6.0
	_chat_badge.add_theme_stylebox_override("normal", badge_style)
	_chat_badge.custom_minimum_size = Vector2(28.0, 28.0)
	_chat_badge.position = Vector2(62.0, -2.0)
	_chat_badge.visible = false
	_chat_button.add_child(_chat_badge)
	root.add_child(_chat_button)
	root.move_child(_chat_button, _menu_dimmer.get_index())
	_chat_feed = Label.new()
	_chat_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_feed.add_theme_font_size_override("font_size", 22)
	_chat_feed.add_theme_constant_override("outline_size", 8)
	_chat_feed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_chat_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_chat_feed.visible = false
	root.add_child(_chat_feed)
	root.move_child(_chat_feed, _menu_dimmer.get_index())
	_controls_frame.resized.connect(_place_chat_ui)
	_place_chat_ui()


func _place_chat_ui() -> void:
	var view: Vector2 = ($Root as Control).size
	var top: float = _controls_frame.position.y
	_chat_button.size = _chat_button.custom_minimum_size
	_chat_button.position = Vector2(view.x - _chat_button.size.x - 24.0, top - _chat_button.size.y - 16.0)
	_chat_feed.size = Vector2(view.x * 0.62, 120.0)
	_chat_feed.position = Vector2(24.0, top - 120.0 - 16.0)


## Abre o chat (zera as não lidas).
func open_chat() -> void:
	_chat_unread = 0
	_chat_badge.visible = false
	_chat_feed.visible = false
	_open_panel(_chat_panel)


## Chegou uma mensagem do chat ([signal Network.chat_received]): vai para o painel; com ele fechado, conta como não
## lida e aparece no resumo.
func add_chat_message(message: ChatMessage) -> void:
	_chat_panel.add_message(message)
	if _chat_panel.visible:
		return
	if message.from_id != _own_id:
		_chat_unread += 1
		_chat_badge.text = str(_chat_unread) if _chat_unread < 100 else "99+"
		_chat_badge.reset_size()
		_chat_badge.visible = true
	_chat_feed_lines.append(ChatPanel.short_line(message))
	if _chat_feed_lines.size() > 2:
		_chat_feed_lines.pop_front()
	_chat_feed.text = "\n".join(_chat_feed_lines)
	_chat_feed.add_theme_color_override("font_color", ChatPanel.COLORS.get(message.channel, Color.WHITE))
	_chat_feed.visible = true
	_chat_feed.modulate.a = 1.0
	_chat_feed_left = CHAT_FEED_SECONDS


## Sua mensagem foi recusada ([signal Network.chat_refused]).
func show_chat_refused(channel: String, reason: String, seconds: int) -> void:
	if _chat_panel.visible:
		_chat_panel.show_refused(channel, reason, seconds)
	else:
		show_toast(ChatPanel.refused_text(channel, reason, seconds))


## Resumo do chat: some aos poucos depois de [constant CHAT_FEED_SECONDS] s.
func _fade_chat_feed(delta: float) -> void:
	if _chat_feed == null or not _chat_feed.visible:
		return
	_chat_feed_left -= delta
	if _chat_feed_left <= 0.0:
		_chat_feed.visible = false
		_chat_feed_lines.clear()
	elif _chat_feed_left < 1.0:
		_chat_feed.modulate.a = _chat_feed_left


## Armazém ([JOGO-26]): botão "Armazém" (baú) no lugar do botão do Ferreiro (só aparece perto do baú grande,
## [method set_storage_near]) e a tela do Armazém.
func _build_storage_ui() -> void:
	var root: Control = $Root
	_storage_panel = StoragePanel.new()
	root.add_child(_storage_panel)
	_storage_panel.close_pressed.connect(_open_panel.bind(null))
	_storage_panel.put_requested.connect(storage_put_requested.emit)
	_storage_panel.take_requested.connect(storage_take_requested.emit)
	_storage_panel.buy_tab_requested.connect(storage_buy_tab_requested.emit)
	_storage_button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button("Armazém"), "icon_chest")
	_storage_button.custom_minimum_size = Vector2(260.0, 84.0)
	_storage_button.visible = false
	_storage_button.pressed.connect(_open_panel.bind(_storage_panel))
	root.add_child(_storage_button)
	root.move_child(_storage_button, _menu_dimmer.get_index())
	_controls_frame.resized.connect(_place_storage_button)
	_place_storage_button()


func _place_storage_button() -> void:
	var view: Vector2 = ($Root as Control).size
	_storage_button.size = _storage_button.custom_minimum_size
	_storage_button.position = Vector2((view.x - _storage_button.size.x) / 2.0, _controls_frame.position.y - _storage_button.size.y - 16.0)


## Perto (ou longe) do baú do Armazém ([JOGO-26]): mostra/esconde o botão; longe, fecha a tela.
func set_storage_near(near: bool) -> void:
	if _storage_button.visible != near:
		_storage_button.visible = near
		_place_storage_button()
	if not near and _storage_panel.visible:
		_open_panel(null)
		show_toast("Você se afastou do Armazém")


## Baú ([JOGO-19]): botão "Abrir baú" no mesmo lugar do "Ferreiro" (os dois nunca aparecem juntos: o ferreiro fica
## na praça e os baús nos acampamentos) e a janela do baú.
func _build_chest_ui() -> void:
	var root: Control = $Root
	_chest_panel = ChestPanel.new()
	root.add_child(_chest_panel)
	_chest_panel.close_pressed.connect(_open_panel.bind(null))
	_chest_panel.back_pressed.connect(_open_panel.bind(null))
	_chest_panel.take_requested.connect(chest_take_requested.emit)
	_chest_button = PixelMenuPanel.make_button("Abrir baú")
	_chest_button.custom_minimum_size = Vector2(260.0, 84.0)
	_chest_button.visible = false
	_chest_button.pressed.connect(func() -> void: chest_open_requested.emit(_near_chest))
	root.add_child(_chest_button)
	root.move_child(_chest_button, _menu_dimmer.get_index())
	_controls_frame.resized.connect(_place_chest_button)
	_place_chest_button()


func _place_chest_button() -> void:
	var view: Vector2 = ($Root as Control).size
	_chest_button.size = _chest_button.custom_minimum_size
	_chest_button.position = Vector2((view.x - _chest_button.size.x) / 2.0, _controls_frame.position.y - _chest_button.size.y - 16.0)


## Perto (ou longe) de um baú ABERTO ([param chest_id]; "" = nenhum): mostra/esconde "Abrir baú"; longe, fecha a janela.
func set_chest_near(chest_id: String) -> void:
	if chest_id == _near_chest:
		return
	_near_chest = chest_id
	_chest_button.visible = not chest_id.is_empty()
	_place_chest_button()
	if _chest_panel.visible and _chest_panel.chest_id() != chest_id:
		_open_panel(null)


## Morreu ([JOGO-21]): fecha o que estiver aberto e começa a tela de morte com o relatório do servidor.
func show_death(report: DeathReport) -> void:
	_open_panel(null)
	_death_screen.start(report)


## Está morto (snapshot): garante a tela (sem o relatório ainda, só "Você morreu" e o botão) e o tempo para renascer.
func set_dead(dead: bool, respawn_in: float) -> void:
	if dead:
		if not _death_screen.is_showing():
			_open_panel(null)
			_death_screen.start_without_report()
		_death_screen.set_respawn_in(respawn_in)
	elif _death_screen.is_showing():
		_death_screen.finish()


## Chegou o que sobrou para você no baú [param chest] (resposta a abrir/pegar): abre a janela (ou atualiza).
func show_chest_loot(chest: ChestInfo, entries: Array[LootEntry]) -> void:
	_chest_panel.show_loot(chest, entries)
	if not _chest_panel.visible:
		_open_panel(_chest_panel)


## Resultado de uma tentativa no ferreiro ([signal Network.upgrade_result]).
func show_upgrade_result(uid: String, success: bool, cost: int, attribute: String, level: int, points: int) -> void:
	_blacksmith_panel.show_result(uid, success, cost, attribute, level, points)


## Lista da Loja do Ferreiro chegou ([signal Network.shop_received], [JOGO-23]).
func show_shop(items: Array[InventoryState.Item], prices: Array[int]) -> void:
	_blacksmith_panel.show_shop(items, prices)


## Compra/venda feita na Loja do Ferreiro ([signal Network.shop_result]).
func show_shop_result(action: String, item_id: String, gold: int) -> void:
	_blacksmith_panel.show_shop_result(action, item_id, gold)


## Resultado de uma fusão no ferreiro ([signal Network.fuse_result], [JOGO-20]).
func show_fuse_result(uid: String, levels_gained: int, xp_gained: float, level: int, xp: float, xp_next: float) -> void:
	_blacksmith_panel.show_fuse_result(uid, levels_gained, xp_gained, level, xp, xp_next)


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


## Guilda ([SOC-06]): painel do Menu → Guilda e o botão "Guilda" (sempre visível, logo depois de "Amigos").
func _build_guild_ui() -> void:
	var root: Control = $Root
	_guild_panel = GuildPanel.new()
	root.add_child(_guild_panel)
	_guild_panel.close_pressed.connect(_open_panel.bind(null))
	_guild_panel.back_pressed.connect(func() -> void:
		if not _guild_panel.go_back():
			_open_panel(_menu_panel))
	_guild_panel.member_chosen.connect(_on_guild_member_chosen)
	_guild_panel.create_pressed.connect(func(guild_name: String, tag: String, description: String) -> void:
		guild_create_requested.emit(guild_name, tag, description))
	_guild_panel.list_requested.connect(func(query: String) -> void: guild_list_requested.emit(query))
	_guild_panel.info_requested.connect(func(guild_id: String) -> void: guild_info_requested.emit(guild_id))
	_guild_panel.join_requested.connect(func(guild_id: String) -> void: guild_join_requested.emit(guild_id))
	_guild_panel.request_answered.connect(func(player_id: String, accept: bool) -> void: guild_request_answered.emit(player_id, accept))
	_guild_panel.description_saved.connect(func(description: String) -> void: guild_description_saved.emit(description))
	_guild_panel.leave_pressed.connect(guild_leave_requested.emit)
	var players_button: Button = %PlayersButton
	_guild_button = players_button.duplicate() as Button
	_guild_button.name = "GuildButton"
	_guild_button.unique_name_in_owner = false
	_guild_button.text = "Guilda"
	_guild_button.visible = true
	_friends_button.add_sibling(_guild_button)
	_guild_button.pressed.connect(_open_panel.bind(_guild_panel))
	_refresh_menu_height()


## Ranking ([SOC-07]): painel do Menu → Ranking e o botão "Ranking" (sempre visível, logo depois de "Guilda").
func _build_ranking_ui() -> void:
	var root: Control = $Root
	_ranking_panel = RankingPanel.new()
	root.add_child(_ranking_panel)
	_ranking_panel.close_pressed.connect(_open_panel.bind(null))
	_ranking_panel.back_pressed.connect(_open_panel.bind(_menu_panel))
	_ranking_panel.ranking_requested.connect(func(category: String, period: String) -> void: ranking_requested.emit(category, period))
	var players_button: Button = %PlayersButton
	_ranking_button = players_button.duplicate() as Button
	_ranking_button.name = "RankingButton"
	_ranking_button.unique_name_in_owner = false
	_ranking_button.text = "Ranking"
	_ranking_button.visible = true
	_guild_button.add_sibling(_ranking_button)
	_ranking_button.pressed.connect(_open_panel.bind(_ranking_panel))
	_refresh_menu_height()


## Loja premium ([JOGO-27]): painel do Menu → Loja e o botão "Loja" (ícone de diamante, logo depois de "Ranking").
func _build_premium_ui() -> void:
	_premium_panel = PremiumShopPanel.new()
	$Root.add_child(_premium_panel)
	_premium_panel.close_pressed.connect(_open_panel.bind(null))
	_premium_panel.back_pressed.connect(_open_panel.bind(_menu_panel))
	_premium_panel.open_requested.connect(premium_open_requested.emit)
	_premium_panel.buy_requested.connect(func(product_id: String) -> void: premium_buy_requested.emit(product_id))
	_premium_panel.pack_requested.connect(func(pack_id: String) -> void: premium_pack_requested.emit(pack_id))
	_premium_panel.history_requested.connect(premium_history_requested.emit)
	_premium_button = _ranking_button.duplicate() as Button
	_premium_button.name = "PremiumButton"
	_premium_button.text = "Loja"
	PixelMenuPanel.set_icon(_premium_button, "icon_diamond")
	_ranking_button.add_sibling(_premium_button)
	_premium_button.pressed.connect(_open_panel.bind(_premium_panel))
	_refresh_menu_height()


## Loja premium: estado novo (saldo, efeitos, catálogo); o ferreiro mostra as pedras garantidas.
func show_premium(state: PremiumState) -> void:
	_premium_panel.show_state(state)
	_blacksmith_panel.set_upgrade_stones(state.upgrade_stones)


## Loja premium: compra feita (mensagem na Loja e aviso na tela).
func show_premium_result(kind: String, _id: String, item_name: String, diamonds: int) -> void:
	_premium_panel.show_result(kind, item_name, diamonds)
	show_toast("+%s Diamantes" % InventoryView.format_gold(diamonds) if kind == "pack" else "Comprado: %s" % item_name)


## Loja premium: histórico de compras chegou.
func show_premium_history(entries: Array[PremiumState.HistoryEntry]) -> void:
	_premium_panel.show_history(entries)


## Loja premium: recusou por falta de Diamantes (a Loja abre os pacotes).
func show_premium_not_enough() -> void:
	_premium_panel.show_not_enough()


## Troca ([SOC-05]): a janela da troca (no ciclo dos painéis: pausa os controles enquanto aberta).
func _build_trade_ui() -> void:
	_trade_panel = TradePanel.new()
	$Root.add_child(_trade_panel)
	_trade_panel.offer_changed.connect(func(uids: Array[String], gold: int) -> void: trade_offer_changed.emit(uids, gold))
	_trade_panel.confirm_pressed.connect(trade_confirm_requested.emit)
	_trade_panel.cancel_pressed.connect(_open_panel.bind(null))


## Chegou um pedido de troca: janela Aceitar/Recusar no alto da tela ([RequestPanel]).
func show_trade_request(from_id: String, from_name: String, expires_in: float) -> void:
	_invite_panel.add_request(RequestPanel.KIND_TRADE, from_id, from_name, expires_in)


## Chegou o estado da minha troca: abre a janela (fechando o que estiver aberto) ou atualiza. Abrir descarta os outros
## pedidos de troca (só uma troca por vez).
func show_trade(state: TradeState) -> void:
	var opening: bool = not _trade_panel.is_active()
	_trade_panel.show_state(state)
	if opening:
		_invite_panel.clear_kind(RequestPanel.KIND_TRADE)
	if not _trade_panel.visible:
		_open_panel(_trade_panel)


## A troca acabou ([param message] = aviso: aconteceu, cancelada, longe...): fecha a janela sem mandar "cancelar".
func end_trade(message: String) -> void:
	var was_open: bool = _trade_panel.visible
	_trade_panel.clear()
	if was_open:
		_open_panel(null)
	if not message.is_empty():
		show_toast(message)


## Chegou uma tabela de ranking: mostra se o painel ainda está naquela aba.
func show_ranking(ranking: RankingData) -> void:
	_ranking_panel.show_ranking(ranking, _guild != null)


## Minha guilda mudou ([param guild] null = sem guilda; [param own_id] = meu id): atualiza o painel; se as opções
## abertas eram de alguém que saiu da guilda, volta para a lista. Entrar numa guilda descarta os outros convites.
func set_guild(guild: GuildState, own_id: String) -> void:
	var joined: bool = _guild == null and guild != null
	_guild = guild
	_own_id = own_id
	_guild_panel.show_guild(guild, own_id)
	if joined:
		_invite_panel.clear_kind(RequestPanel.KIND_GUILD)
	var from_guild: bool = _actions_panel.visible and _actions_origin == _guild_panel
	if from_guild and (guild == null or guild.find_member(_actions_panel.player_id) == null):
		_open_panel(_guild_panel)


## Chegou a lista do Procurar guilda (da busca [param query]).
func show_guild_list(query: String, guilds: Array[GuildState.Summary]) -> void:
	_guild_panel.show_list(query, guilds)


## Chegou a ficha de uma guilda.
func show_guild_info(info: GuildState.Info) -> void:
	_guild_panel.show_info(info)


## Chegou um convite de guilda: janela Aceitar/Recusar no alto da tela ([RequestPanel]).
func show_guild_invite(from_id: String, from_name: String, guild_title: String, expires_in: float) -> void:
	_invite_panel.add_request(RequestPanel.KIND_GUILD, from_id, from_name, expires_in, guild_title)


## true se posso convidar [param player_id] para a minha guilda: sou líder/oficial, há vaga e ele não tem guilda.
func _can_guild_invite(player_id: String) -> bool:
	if _guild == null or player_id == _own_id or not _guild.can_invite(_own_id) or _guild.members.size() >= GuildState.MAX_MEMBERS:
		return false
	var state: PlayerState = Network.instance.get_player(player_id) if Network.instance != null else null
	return state != null and state.guild_id.is_empty()


## Tocou num membro no painel da Guilda: Atributos (se está na zona), Solicitar amizade, e conforme o meu cargo
## Promover/Rebaixar (líder) e Expulsar (líder: qualquer um; oficial: membro comum).
func _on_guild_member_chosen(player_id: String, title: String) -> void:
	var options: Array[PlayerActionsPanel.Option] = []
	if Network.instance != null and Network.instance.get_player(player_id) != null:
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_ATTRIBUTES, "Atributos"))
	options.append_array(_friend_request_options(player_id))
	if _guild != null:
		if _guild.role_of(_own_id) == GuildState.ROLE_LEADER:
			var role: String = _guild.role_of(player_id)
			if role == GuildState.ROLE_MEMBER:
				options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GUILD_PROMOTE, "Promover a oficial"))
			elif role == GuildState.ROLE_OFFICER:
				options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GUILD_DEMOTE, "Rebaixar a membro"))
		if _guild.can_kick(_own_id, player_id):
			options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GUILD_KICK, "Expulsar da guilda"))
	_actions_origin = _guild_panel
	_actions_panel.show_options(player_id, title, options)
	_open_panel(_actions_panel)


## Configuração ([SOC-04]): "Solicitações de amizade" e "Convites de grupo", cada uma com os botões Sempre/Ocultar, e
## "Perfil" com Público/Amigos/Ninguém ([SOC-08]); o escolhido aceso com ✓, os outros apagados. Acima do "Voltar".
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
		var options: Dictionary = _SOCIAL_OPTIONS[key]
		for value: String in options.keys():
			var button: Button = PixelMenuPanel.make_button("")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_social_option.bind(key, value))
			buttons.add_child(button)
			_social_buttons["%s|%s" % [key, value]] = button
	_refresh_social_buttons()


## Medidor de desempenho ([INFRA-12]): linha pequena logo acima da moldura de baixo (ping, rede, FPS) e, na Configuração, "Medidor de
## desempenho" Mostrar/Ocultar (salvo só neste aparelho, [LocalSettings]).
func _build_perf_setting() -> void:
	_perf_overlay = PerfOverlay.new()
	# Logo acima da moldura de baixo (canto livre da tela); acompanha a margem dela em _apply_safe_margins.
	_perf_overlay.anchor_top = 1.0
	_perf_overlay.anchor_bottom = 1.0
	_perf_overlay.anchor_right = 1.0
	_perf_overlay.offset_left = _controls_frame.offset_left + 8.0
	_perf_overlay.offset_right = _controls_frame.offset_right
	_perf_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$Root.add_child(_perf_overlay)
	_perf_overlay.visible = LocalSettings.show_perf()
	var back: Button = %SettingsBackButton
	var column: VBoxContainer = back.get_parent() as VBoxContainer
	var label: Label = PixelMenuPanel.make_label("Medidor de desempenho")
	column.add_child(label)
	column.move_child(label, back.get_index())
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	column.move_child(buttons, back.get_index())
	for value: bool in [true, false]:
		var button: Button = PixelMenuPanel.make_button("")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_perf_option.bind(value))
		buttons.add_child(button)
		_perf_buttons[value] = button
	_refresh_perf_buttons()


func _on_perf_option(enabled: bool) -> void:
	LocalSettings.set_show_perf(enabled)
	_perf_overlay.visible = enabled
	_refresh_perf_buttons()


func _refresh_perf_buttons() -> void:
	for value: bool in _perf_buttons.keys():
		var selected: bool = _perf_overlay.visible == value
		var text: String = "Mostrar" if value else "Ocultar"
		var button: Button = _perf_buttons[value]
		button.text = ("✓ " + text) if selected else text
		button.modulate = Color(1, 1, 1) if selected else Color(1, 1, 1, 0.5)


## Tocou em Sempre/Ocultar: manda a Configuração nova ao servidor (a tela muda quando ele confirmar).
func _on_social_option(key: String, value: String) -> void:
	if _social[key] == value:
		return
	var changed: Dictionary[String, String] = _social.duplicate()
	changed[key] = value
	social_settings_requested.emit(changed["friendRequests"], changed["groupInvites"], changed["guildInvites"], changed["profile"], changed["tradeRequests"])


## A Configuração social salva na conta mudou (auth_ok ou confirmação do servidor): acende a opção de cada linha.
func set_social_settings(friend_requests: String, group_invites: String, guild_invites: String, profile: String, trade_requests: String) -> void:
	_social["tradeRequests"] = trade_requests
	_social["friendRequests"] = friend_requests
	_social["groupInvites"] = group_invites
	_social["guildInvites"] = guild_invites
	_social["profile"] = profile
	_refresh_social_buttons()


func _refresh_social_buttons() -> void:
	for key: String in _social_buttons.keys():
		var parts: PackedStringArray = key.split("|")
		var selected: bool = _social.get(parts[0], "") == parts[1]
		var options: Dictionary = _SOCIAL_OPTIONS[parts[0]]
		var text: String = str(options[parts[1]])
		var button: Button = _social_buttons[key]
		button.text = ("✓ " + text) if selected else text
		button.modulate = Color(1, 1, 1) if selected else Color(1, 1, 1, 0.5)


## Altura do Menu: os botões da cena + "Amigos" + "Guilda" + "Ranking" + "Loja" + "Grupo" (só com grupo), centralizado.
func _refresh_menu_height() -> void:
	var extra_rows: int = (1 if _friends_button != null else 0) + (1 if _guild_button != null else 0) + (1 if _ranking_button != null else 0) + (1 if _premium_button != null else 0) + (1 if _group != null else 0)
	var height: float = _menu_base_height + extra_rows * (PixelMenuPanel.BUTTON_HEIGHT_PX + 20.0)
	_menu_panel.offset_top = -height / 2.0
	_menu_panel.offset_bottom = height / 2.0


## Resposta na janela de pedidos: vai para o grupo ou para a amizade, conforme o tipo.
func _on_request_answered(kind: String, from_id: String, accept: bool) -> void:
	if kind == RequestPanel.KIND_FRIEND:
		friend_answered.emit(from_id, accept)
	elif kind == RequestPanel.KIND_GUILD:
		guild_answered.emit(from_id, accept)
	elif kind == RequestPanel.KIND_TRADE:
		trade_answered.emit(from_id, accept)
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
	if _can_guild_invite(player_id):
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_GUILD_INVITE, "Convidar para a guilda"))
	# Troca ([SOC-05]): só a até 10 m (o servidor confere de novo); longe aparece apagada com o motivo.
	if player_id != _own_id:
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_MESSAGE, "Mandar mensagem"))
		var near: bool = _distance_to(player_id) <= Protocol.TRADE_RANGE
		options.append(PlayerActionsPanel.Option.new(PlayerActionsPanel.OPTION_TRADE, "Trocar", near, "" if near else "chegue perto"))
	_actions_origin = _nearby_panel
	_actions_panel.show_options(player_id, title, options)
	_open_panel(_actions_panel)


## Distância (m, no chão) entre mim e o jogador [param player_id] pelo último snapshot; INF se algum não está na vista.
func _distance_to(player_id: String) -> float:
	if Network.instance == null:
		return INF
	var me: PlayerState = Network.instance.get_player(Network.instance.player_id)
	var other: PlayerState = Network.instance.get_player(player_id)
	if me == null or other == null:
		return INF
	return Vector2(me.x - other.x, me.z - other.z).length()


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
		PlayerActionsPanel.OPTION_MESSAGE:
			# Privado do chat ([SOC-09]) com o nome dele já preenchido.
			var state: PlayerState = Network.instance.get_player(target)
			if state != null:
				open_chat()
				_chat_panel.start_private(state.name)
		PlayerActionsPanel.OPTION_TRADE:
			# Aceitou: a janela da troca abre sozinha (trade_state); recusou/expirou: aviso.
			trade_request_requested.emit(target)
			show_toast("Pedido de troca enviado.")
		PlayerActionsPanel.OPTION_GUILD_INVITE:
			guild_invite_requested.emit(target)
			show_toast("Convite para a guilda enviado.")
		PlayerActionsPanel.OPTION_GUILD_KICK:
			guild_kick_requested.emit(target)
			_open_panel(_guild_panel)
		PlayerActionsPanel.OPTION_GUILD_PROMOTE:
			guild_role_requested.emit(target, GuildState.ROLE_OFFICER)
			_open_panel(_guild_panel)
		PlayerActionsPanel.OPTION_GUILD_DEMOTE:
			guild_role_requested.emit(target, GuildState.ROLE_MEMBER)
			_open_panel(_guild_panel)
		PlayerActionsPanel.OPTION_FRIEND_REMOVE:
			# Volta à lista; ela se atualiza quando o servidor confirmar (e o aviso "X foi removido" aparece).
			friend_remove_requested.emit(target)
			_open_panel(_friends_panel)


## Todos os painéis do menu (um aberto por vez).
func _all_panels() -> Array[PanelContainer]:
	return [_menu_panel, _inventory_panel, _settings_panel, _item_detail, _map_panel, _nearby_panel, _actions_panel, _attributes_panel, _group_panel, _friends_panel, _guild_panel, _ranking_panel, _premium_panel, _blacksmith_panel, _storage_panel, _market_panel, _chat_panel, _chest_panel, _trade_panel]


## Abre [param panel] e fecha os outros; null fecha tudo. Com menu aberto, os controles do jogo param.
func _open_panel(panel: PanelContainer) -> void:
	# Fechar a janela de uma troca em andamento (X, Cancelar, tocar fora, morrer) cancela a troca ([SOC-05]).
	if _trade_panel != null and _trade_panel.visible and panel != _trade_panel and _trade_panel.is_active():
		_trade_panel.clear()
		trade_cancel_requested.emit()
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
