class_name GuildPanel
extends PixelMenuPanel
## Menu → "Guilda" ([SOC-06]; o botão está sempre no Menu). Telas dentro do mesmo painel ("Voltar" volta uma tela;
## da primeira, volta ao Menu — a [Hud] chama [method go_back]):
## - **Sem guilda:** "Criar guilda" e "Procurar guilda".
##   - **Criar:** Nome (3 a 20), Tag (3 letras/números), Descrição breve (até 120) e "Criar guilda · 1.000 moedas".
##   - **Procurar:** as guildas que não estão cheias, da mais cheia para a mais vazia ("[TAG] Nome · 12/50"). Tocar
##     numa abre a **ficha** (descrição, líder, membros, criada em, XP de monstros e jogadores mortos somados) com
##     **Enviar solicitação** — não entra direto: líder/oficial aceita.
## - **Com guilda:** "[TAG] Nome", a descrição, "N de 50 membros", **Solicitações (N)** (só líder/oficiais),
##   **Editar descrição** (só o líder), a lista "Cargo · [nível] nome · online/offline" (tocar = [signal member_chosen])
##   e **Sair da guilda** (pede um segundo toque: sair dá 1 h sem entrar em outra).
##   - **Solicitações:** cada pedido com Aceitar / Recusar.
## A [Hud] chama [method show_guild] a cada mudança, [method show_list] e [method show_info] com as respostas.

## Tocou em "Criar guilda" com [param guild_name] / [param tag] / [param description] (como digitados).
signal create_pressed(guild_name: String, tag: String, description: String)
## Abriu o Procurar guilda: pedir a lista.
signal list_requested
## Tocou numa guilda da lista: pedir a ficha.
signal info_requested(guild_id: String)
## Tocou em "Enviar solicitação" na ficha.
signal join_requested(guild_id: String)
## Líder/oficial respondeu ao pedido de [param player_id].
signal request_answered(player_id: String, accept: bool)
## Líder salvou a descrição nova.
signal description_saved(description: String)
## Tocou no membro [param player_id] ([param title] = "[nível] nome", para o título das opções).
signal member_chosen(player_id: String, title: String)
## Confirmou "Sair da guilda" (segundo toque).
signal leave_pressed

## Altura do painel (px).
const HEIGHT_PX: float = 1100.0
const OFFLINE_COLOR: Color = Color(1, 1, 1, 0.55)
const KEY_COLOR: Color = Color(1, 1, 1, 0.7)
const VALUE_COLOR: Color = Color(1, 0.85, 0.6)
const LEAVE_TEXT: String = "Sair da guilda"
const LEAVE_CONFIRM_TEXT: String = "Toque de novo para sair (1 h sem outra)"

## Telas.
enum Screen { CHOICE, CREATE, BROWSE, INFO, GUILD, REQUESTS, EDIT }

var _screen: Screen = Screen.CHOICE
var _guild: GuildState = null
var _own_id: String = ""
## Guilda da ficha aberta.
var _info_id: String = ""
var _leave_armed: bool = false
var _content: VBoxContainer = null
## Campos da tela atual (criar/editar).
var _name_field: LineEdit = null
var _tag_field: LineEdit = null
var _description_field: LineEdit = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Guilda")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_render()
	visibility_changed.connect(func() -> void:
		if visible:
			_screen = Screen.GUILD if _guild != null else Screen.CHOICE
			_render())


## Minha guilda mudou ([param guild] null = sem guilda; [param own_id] = meu id).
func show_guild(guild: GuildState, own_id: String) -> void:
	var had: bool = _guild != null
	_guild = guild
	_own_id = own_id
	if guild != null and not had:
		_screen = Screen.GUILD
	elif guild == null and had:
		_screen = Screen.CHOICE
	elif guild != null and _screen == Screen.REQUESTS and not _can_manage():
		_screen = Screen.GUILD
	if _screen in [Screen.GUILD, Screen.REQUESTS, Screen.CHOICE]:
		_render()


## Chegou a lista do Procurar guilda.
func show_list(guilds: Array[GuildState.Summary]) -> void:
	if _screen != Screen.BROWSE:
		return
	_clear()
	_add_label("Guildas que aceitam gente (toque para ver):", KEY_COLOR)
	if guilds.is_empty():
		_add_label("Nenhuma guilda com vaga agora. Que tal criar a sua?", KEY_COLOR)
	for item: GuildState.Summary in guilds:
		_add_button("[%s] %s · %d/%d" % [item.tag, item.name, item.members, GuildState.MAX_MEMBERS], _open_info.bind(item.id), true)


## Chegou a ficha de uma guilda.
func show_info(info: GuildState.Info) -> void:
	if _screen != Screen.INFO or info.id != _info_id:
		return
	_clear()
	set_title("[%s] %s" % [info.tag, info.name])
	_add_label(info.description if not info.description.is_empty() else "Sem descrição.")
	_add_row("Líder", info.leader_name)
	_add_row("Membros", "%d/%d" % [info.members, GuildState.MAX_MEMBERS])
	_add_row("Criada em", _date_text(info.created_at))
	_add_row("XP de monstros", InventoryView.format_gold(floori(info.monster_xp)))
	_add_row("Jogadores mortos", InventoryView.format_gold(info.kills))
	var send: Button = _add_button("Solicitação enviada" if info.requested else "Enviar solicitação", Callable())
	send.disabled = info.requested
	send.pressed.connect(func() -> void:
		# Recusa (ex.: espera de 1 h) chega como aviso; o botão fica desligado até abrir a ficha de novo.
		send.disabled = true
		send.text = "Solicitação enviada"
		join_requested.emit(info.id))


## "Voltar": uma tela para trás; `false` = já estava na primeira (a [Hud] volta ao Menu).
func go_back() -> bool:
	match _screen:
		Screen.CREATE, Screen.BROWSE:
			_screen = Screen.CHOICE
		Screen.INFO:
			_screen = Screen.BROWSE
			list_requested.emit()
		Screen.REQUESTS, Screen.EDIT:
			_screen = Screen.GUILD
		_:
			return false
	_render()
	return true


func _render() -> void:
	_clear()
	_leave_armed = false
	match _screen:
		Screen.CHOICE:
			_render_choice()
		Screen.CREATE:
			_render_create()
		Screen.BROWSE:
			set_title("Procurar guilda")
			_add_label("Carregando…", KEY_COLOR)
		Screen.INFO:
			_add_label("Carregando…", KEY_COLOR)
		Screen.GUILD:
			_render_guild()
		Screen.REQUESTS:
			_render_requests()
		Screen.EDIT:
			_render_edit()


func _render_choice() -> void:
	if _guild != null:
		_screen = Screen.GUILD
		_render_guild()
		return
	set_title("Guilda")
	_add_label("Você não está numa guilda.", KEY_COLOR)
	_add_button("Criar guilda", func() -> void:
		_screen = Screen.CREATE
		_render())
	_add_button("Procurar guilda", func() -> void:
		_screen = Screen.BROWSE
		_render()
		list_requested.emit())


func _render_create() -> void:
	set_title("Criar guilda")
	_add_label("Nome da guilda (3 a 20)")
	_name_field = _make_field("Ex.: Ordem da Luz", 20)
	_add_label("Tag (3 letras ou números)")
	_tag_field = _make_field("Ex.: ODL", 3)
	_add_label("Descrição breve (até %d)" % GuildState.DESCRIPTION_MAX)
	_description_field = _make_field("Ex.: Caçamos zumbis toda noite", GuildState.DESCRIPTION_MAX)
	_add_button("Criar guilda · %s moedas" % InventoryView.format_gold(Protocol.GUILD_CREATE_COST), func() -> void:
		create_pressed.emit(_name_field.text, _tag_field.text, _description_field.text))


func _render_guild() -> void:
	if _guild == null:
		return
	set_title(_guild.title())
	_add_label(_guild.description if not _guild.description.is_empty() else "Sem descrição.", KEY_COLOR)
	_add_label("%d de %d membros" % [_guild.members.size(), GuildState.MAX_MEMBERS], KEY_COLOR)
	if _can_manage():
		_add_button("Solicitações (%d)" % _guild.requests.size(), func() -> void:
			_screen = Screen.REQUESTS
			_render())
	if _guild.role_of(_own_id) == GuildState.ROLE_LEADER:
		_add_button("Editar descrição", func() -> void:
			_screen = Screen.EDIT
			_render())
	for member: GuildState.Member in _guild.members:
		var level: String = "" if member.level < 0 else "[%s] " % LevelText.short(member.level)
		var role: String = GuildState.ROLE_LABELS.get(member.role, member.role)
		var me: bool = member.id == _own_id
		var text: String = "%s · %s%s · %s" % [role, level, member.name, "você" if me else ("online" if member.online else "offline")]
		var button: Button = _add_button(text, member_chosen.emit.bind(member.id, "%s%s" % [level, member.name]), true)
		if not member.online and not me:
			button.add_theme_color_override("font_color", OFFLINE_COLOR)
		button.disabled = me
	var leave: Button = _add_button(LEAVE_TEXT, Callable())
	leave.pressed.connect(func() -> void:
		if not _leave_armed:
			_leave_armed = true
			leave.text = LEAVE_CONFIRM_TEXT
			return
		_leave_armed = false
		leave.text = LEAVE_TEXT
		leave_pressed.emit())


func _render_requests() -> void:
	set_title("Solicitações")
	if _guild == null or _guild.requests.is_empty():
		_add_label("Nenhum pedido esperando.", KEY_COLOR)
		return
	var now: float = Time.get_unix_time_from_system()
	for request: GuildState.Request in _guild.requests:
		_add_label("%s · %s" % [request.name, _ago(now - request.at / 1000.0)])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_content.add_child(row)
		for accept: bool in [true, false]:
			var button: Button = PixelMenuPanel.make_button("Aceitar" if accept else "Recusar")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.pressed.connect(request_answered.emit.bind(request.id, accept))
			row.add_child(button)


func _render_edit() -> void:
	set_title("Editar descrição")
	_add_label("Descrição breve (até %d)" % GuildState.DESCRIPTION_MAX)
	_description_field = _make_field("Ex.: Caçamos zumbis toda noite", GuildState.DESCRIPTION_MAX)
	_description_field.text = _guild.description if _guild != null else ""
	_add_button("Salvar", func() -> void:
		description_saved.emit(_description_field.text)
		_screen = Screen.GUILD
		_render())


func _open_info(guild_id: String) -> void:
	_info_id = guild_id
	_screen = Screen.INFO
	_render()
	info_requested.emit(guild_id)


## true se sou líder ou oficial.
func _can_manage() -> bool:
	return _guild != null and _guild.can_invite(_own_id)


## "17/11/2026" de um instante em ms desde 1970.
static func _date_text(ms: float) -> String:
	var date: Dictionary = Time.get_date_dict_from_unix_time(int(ms / 1000.0))
	return "%02d/%02d/%d" % [int(date["day"]), int(date["month"]), int(date["year"])]


## "há 5 min" / "há 3 h" / "há 2 d".
static func _ago(seconds: float) -> String:
	var minutes: int = maxi(0, int(seconds / 60.0))
	if minutes < 60:
		return "há %d min" % maxi(1, minutes)
	if minutes < 60 * 24:
		return "há %d h" % (minutes / 60)
	return "há %d d" % (minutes / (60 * 24))


func _clear() -> void:
	for child: Node in _content.get_children():
		child.queue_free()


func _add_label(text: String, color: Color = Color(1, 1, 1)) -> Label:
	var label: Label = PixelMenuPanel.make_label(text, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
	return label


## Botão na tela atual; [param on_pressed] vazio = quem chamou liga depois.
func _add_button(text: String, on_pressed: Callable, align_left: bool = false) -> Button:
	var button: Button = PixelMenuPanel.make_button(text, align_left)
	# Deixa o arrasto chegar ao ScrollContainer (lista grande rola).
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	_content.add_child(button)
	return button


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


## Campo de texto no estilo pixel art ([CLI-07]).
func _make_field(placeholder: String, max_chars: int) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.theme_type_variation = &"PixelLineEdit"
	field.placeholder_text = placeholder
	field.max_length = max_chars
	field.custom_minimum_size = Vector2(0.0, PixelMenuPanel.BUTTON_HEIGHT_PX)
	_content.add_child(field)
	return field
