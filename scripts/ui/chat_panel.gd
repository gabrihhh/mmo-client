class_name ChatPanel
extends PanelContainer
## Painel do **chat** ([SOC-09]): metade de baixo da tela, feito por código; o campo de digitar fica no topo do painel
## (o teclado do celular sobe por baixo e cobriria um campo no fim). Abre pelo botão do chat (balões) da HUD ([Hud]).
##
## ```
## ┌ [Tudo][Geral][Grupo][Guilda][Privado][Global]  [X]┐
## │ (aviso de recusa)                                  │
## │ (Para: [nome] só no Privado)                       │
## │ [ mensagem…                         ] [Enviar]     │  em cima: o teclado do celular cobre a parte de baixo
## │ [Geral] [ODL][12] Ana: oi                          │  últimas 100; tocar no nome = privado para ele
## │ [Privado] para Beto: segredo                       │
## └────────────────────────────────────────────────────┘
## ```
## Na aba **Tudo** o envio vai para o Geral. O servidor limpa o texto, confere os limites (anti-spam, Global a cada
## 10 min) e devolve a própria mensagem (é ela que aparece aqui) ou a recusa ([method show_refused]).

## Mandar [param text] no [param channel] (para [param to], só no privado).
signal send_requested(channel: String, text: String, to: String)
## Fechar.
signal close_pressed

## Canais na ordem das abas ("all" = Tudo). ATENÇÃO: canais = CHAT_CHANNELS em mmo-server/src/social/chat.ts.
const TABS: Array[String] = ["all", "zone", "group", "guild", "private", "global"]
const TAB_TITLES: Dictionary[String, String] = {"all": "Tudo", "zone": "Geral", "group": "Grupo", "guild": "Guilda", "private": "Privado", "global": "Global"}
## Ícone pixel art de cada aba (`assets/ui/pixel/`, de `tools/ui/make_pixel_ui.gd`).
const TAB_ICONS: Dictionary[String, String] = {"all": "icon_chat", "zone": "icon_zone", "group": "icon_group", "guild": "icon_guild", "private": "icon_private", "global": "icon_global"}
## Cor de cada canal (Geral branco, Grupo verde, Guilda azul, Privado rosa, Global dourado).
const COLORS: Dictionary[String, Color] = {
	"zone": Color(1, 1, 1),
	"group": Color(0.55, 1.0, 0.55),
	"guild": Color(0.55, 0.75, 1.0),
	"private": Color(1.0, 0.6, 0.85),
	"global": Color(1.0, 0.84, 0.3),
}
## Mensagens guardadas (todas as abas juntas).
const MAX_MESSAGES: int = 100
## Tamanho máximo da mensagem. ATENÇÃO: = CHAT_MAX_LENGTH em mmo-server/src/social/chat.ts.
const MAX_LENGTH: int = 200

var _messages: Array[ChatMessage] = []
var _tab: String = "all"
var _tab_buttons: Dictionary[String, Button] = {}
var _log: RichTextLabel = null
var _to_field: LineEdit = null
var _text_field: LineEdit = null
var _notice: Label = null


func _init() -> void:
	theme_type_variation = &"PixelPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.42
	anchor_bottom = 1.0


func _ready() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var tabs: HFlowContainer = HFlowContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	top.add_child(tabs)
	for tab: String in TABS:
		var button: Button = PixelMenuPanel.set_icon(PixelMenuPanel.make_button(TAB_TITLES[tab]), TAB_ICONS[tab], 32)
		button.custom_minimum_size = Vector2(0.0, 60.0)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_set_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button
	var close: Button = PixelMenuPanel.make_close_button()
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(close_pressed.emit)
	top.add_child(close)

	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 20)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_notice)

	_to_field = LineEdit.new()
	_to_field.theme_type_variation = &"PixelLineEdit"
	_to_field.placeholder_text = "Para: nome do jogador"
	_to_field.max_length = 16
	_to_field.custom_minimum_size = Vector2(0.0, 72.0)
	column.add_child(_to_field)

	var input: HBoxContainer = HBoxContainer.new()
	input.add_theme_constant_override("separation", 8)
	column.add_child(input)
	_text_field = LineEdit.new()
	_text_field.theme_type_variation = &"PixelLineEdit"
	_text_field.placeholder_text = "Mensagem…"
	_text_field.max_length = MAX_LENGTH
	_text_field.custom_minimum_size = Vector2(0.0, 80.0)
	_text_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_field.text_submitted.connect(func(_text: String) -> void: _send())
	input.add_child(_text_field)
	var send: Button = PixelMenuPanel.make_button("Enviar")
	send.custom_minimum_size = Vector2(160.0, 80.0)
	send.pressed.connect(_send)
	input.add_child(send)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 24)
	_log.meta_clicked.connect(_on_name_clicked)
	column.add_child(_log)
	_set_tab("all")


## Chegou uma mensagem (inclusive a sua de volta). Guarda as últimas [constant MAX_MESSAGES].
func add_message(message: ChatMessage) -> void:
	_messages.append(message)
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	if is_node_ready() and (_tab == "all" or _tab == message.channel):
		_log.append_text(_line(message) + "\n")


## Sua mensagem foi recusada ([param reason] do servidor; [param seconds] = espera).
func show_refused(channel: String, reason: String, seconds: int) -> void:
	_notice.text = refused_text(channel, reason, seconds)


## Texto da recusa, também usado no aviso da HUD com o painel fechado.
static func refused_text(_channel: String, reason: String, seconds: int) -> String:
	match reason:
		"spam":
			return "Muitas mensagens. Aguarde %d s." % seconds
		"repeat":
			return "Mensagem repetida. Aguarde %d s ou escreva outra." % seconds
		"cooldown":
			return "Global: uma mensagem a cada 10 min. Faltam %d min %02d s." % [seconds / 60, seconds % 60]
		"not_in_group":
			return "Você não está num grupo."
		"not_in_guild":
			return "Você não está numa guilda."
		"player_not_found":
			return "Jogador não encontrado (está online?)."
	return "Mensagem vazia ou longa demais (até %d letras)." % MAX_LENGTH


## Linha de uma mensagem curta, sem o nome do canal (o resumo em cima do joystick com o painel fechado).
static func short_line(message: ChatMessage) -> String:
	var who: String = ("para %s" % message.to) if message.channel == "private" and message.from_id == Network.instance.player_id else message.from
	return "%s: %s" % [who, message.text]


## Abre o privado para [param player_name] (opções do jogador → "Mandar mensagem", ou tocar no nome).
func start_private(player_name: String) -> void:
	_set_tab("private")
	_to_field.text = player_name
	_text_field.grab_focus()


func _set_tab(tab: String) -> void:
	_tab = tab
	_notice.text = ""
	for key: String in _tab_buttons.keys():
		_tab_buttons[key].modulate = Color(1, 1, 1) if key == tab else Color(1, 1, 1, 0.5)
	_to_field.visible = tab == "private"
	_text_field.placeholder_text = "Mensagem no %s…" % TAB_TITLES["zone" if tab == "all" else tab]
	_log.clear()
	for message: ChatMessage in _messages:
		if tab == "all" or tab == message.channel:
			_log.append_text(_line(message) + "\n")


func _send() -> void:
	var text: String = _text_field.text.strip_edges()
	if text.is_empty():
		return
	var channel: String = "zone" if _tab == "all" else _tab
	var to: String = _to_field.text.strip_edges() if channel == "private" else ""
	if channel == "private" and to.is_empty():
		_notice.text = "Escreva para quem é a mensagem."
		return
	_notice.text = ""
	send_requested.emit(channel, text, to)
	_text_field.text = ""


## "[Geral] [TAG][nível] Nome: texto" na cor do canal; o nome é um link (tocar = privado para ele).
func _line(message: ChatMessage) -> String:
	var color: Color = COLORS.get(message.channel, Color.WHITE)
	var mine: bool = message.from_id == Network.instance.player_id
	var who: String = ""
	if message.channel == "private" and mine:
		who = "para [url=%s]%s[/url]" % [_escape(message.to), _escape(message.to)]
	else:
		var tag: String = ("[lb]%s[rb]" % _escape(message.guild_tag)) if not message.guild_tag.is_empty() else ""
		who = "%s[lb]%s[rb] [url=%s]%s[/url]" % [tag, LevelText.short(message.level), _escape(message.from), _escape(message.from)]
	return "[color=#%s][lb]%s[rb] %s: %s[/color]" % [color.to_html(false), TAB_TITLES.get(message.channel, ""), who, _escape(message.text)]


func _on_name_clicked(meta: Variant) -> void:
	var player_name: String = str(meta)
	if player_name != Network.instance.username:
		start_private(player_name)


## Tira o poder de BBCode do texto do jogador ("[" vira o caractere literal).
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
