class_name GuildPanel
extends PixelMenuPanel
## Menu → "Guilda" ([SOC-06]; o botão está sempre no Menu).
## - **Sem guilda:** campos Nome (3 a 20) e Tag (3 letras/números) e o botão "Criar guilda · 1.000 moedas"
##   ([signal create_pressed]; o servidor confere tudo e cobra).
## - **Com guilda:** "[TAG] Nome", quantos membros, a lista "Cargo · [nível] nome · online/offline" (eu marcado com
##   "você"; tocar em outro = [signal member_chosen], a [Hud] abre as opções) e **Sair da guilda**, que pede um
##   segundo toque (sair dá 1 h sem poder entrar em outra).
## A [Hud] chama [method show_guild] a cada mudança.

## Tocou em "Criar guilda" com [param guild_name] / [param tag] (como digitados).
signal create_pressed(guild_name: String, tag: String)
## Tocou no membro [param player_id] ([param title] = "[nível] nome", para o título das opções).
signal member_chosen(player_id: String, title: String)
## Confirmou "Sair da guilda" (segundo toque).
signal leave_pressed

## Altura do painel (px), igual à de Amigos.
const HEIGHT_PX: float = 980.0
## Cor do texto de membro offline (apagado).
const OFFLINE_COLOR: Color = Color(1, 1, 1, 0.55)
## Texto do botão de sair (normal e esperando o segundo toque).
const LEAVE_TEXT: String = "Sair da guilda"
const LEAVE_CONFIRM_TEXT: String = "Toque de novo para sair (1 h sem outra)"

var _create_box: VBoxContainer = null
var _name_field: LineEdit = null
var _tag_field: LineEdit = null
var _guild_box: VBoxContainer = null
var _header: Label = null
var _list: VBoxContainer = null
var _leave_button: Button = null
## Já tocou uma vez em "Sair da guilda".
var _leave_armed: bool = false


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Guilda")
	_build_create_box()
	_build_guild_box()
	show_guild(null, "")
	visibility_changed.connect(_disarm_leave)


## Mostra [param guild] (null = formulário de criar); [param own_id] = meu id.
func show_guild(guild: GuildState, own_id: String) -> void:
	_disarm_leave()
	_create_box.visible = guild == null
	_guild_box.visible = guild != null
	for child: Node in _list.get_children():
		child.queue_free()
	if guild == null:
		set_title("Guilda")
		return
	set_title(guild.title())
	_header.text = "%d de %d membros" % [guild.members.size(), GuildState.MAX_MEMBERS]
	for member: GuildState.Member in guild.members:
		var level: String = "" if member.level < 0 else "[%s] " % LevelText.short(member.level)
		var role: String = GuildState.ROLE_LABELS.get(member.role, member.role)
		var me: bool = member.id == own_id
		var text: String = "%s · %s%s · %s" % [role, level, member.name, "você" if me else ("online" if member.online else "offline")]
		var button: Button = PixelMenuPanel.make_button(text, true)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		if not member.online and not me:
			button.add_theme_color_override("font_color", OFFLINE_COLOR)
		if me:
			button.disabled = true
		else:
			button.pressed.connect(member_chosen.emit.bind(member.id, "%s%s" % [level, member.name]))
		_list.add_child(button)


func _build_create_box() -> void:
	_create_box = VBoxContainer.new()
	_create_box.add_theme_constant_override("separation", 14)
	body.add_child(_create_box)
	var intro: Label = PixelMenuPanel.make_label(
		"Você não está numa guilda.\nCrie a sua ou aceite um convite.", Color(1, 1, 1, 0.7))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_create_box.add_child(intro)
	_create_box.add_child(PixelMenuPanel.make_label("Nome da guilda (3 a 20)"))
	_name_field = _make_field("Ex.: Ordem da Luz", 20)
	_create_box.add_child(_name_field)
	_create_box.add_child(PixelMenuPanel.make_label("Tag (3 letras ou números)"))
	_tag_field = _make_field("Ex.: ODL", 3)
	_create_box.add_child(_tag_field)
	var create: Button = PixelMenuPanel.make_button("Criar guilda · %s moedas" % InventoryView.format_gold(Protocol.GUILD_CREATE_COST))
	create.pressed.connect(func() -> void: create_pressed.emit(_name_field.text, _tag_field.text))
	_create_box.add_child(create)


func _build_guild_box() -> void:
	_guild_box = VBoxContainer.new()
	_guild_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_guild_box.add_theme_constant_override("separation", 12)
	body.add_child(_guild_box)
	_header = PixelMenuPanel.make_label("", Color(1, 1, 1, 0.7))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guild_box.add_child(_header)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_guild_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_leave_button = PixelMenuPanel.make_button(LEAVE_TEXT)
	_leave_button.pressed.connect(_on_leave)
	_guild_box.add_child(_leave_button)


## Campo de texto no estilo pixel art ([CLI-07]).
func _make_field(placeholder: String, max_chars: int) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.theme_type_variation = &"PixelLineEdit"
	field.placeholder_text = placeholder
	field.max_length = max_chars
	field.custom_minimum_size = Vector2(0.0, PixelMenuPanel.BUTTON_HEIGHT_PX)
	return field


## Primeiro toque arma; o segundo confirma.
func _on_leave() -> void:
	if not _leave_armed:
		_leave_armed = true
		_leave_button.text = LEAVE_CONFIRM_TEXT
		return
	_disarm_leave()
	leave_pressed.emit()


func _disarm_leave() -> void:
	_leave_armed = false
	if _leave_button != null:
		_leave_button.text = LEAVE_TEXT
