class_name PlayerActionsPanel
extends PixelMenuPanel
## Opções sobre um jogador ([SOC-02]): o título é o "[nível] nome" dele e cada opção é um botão. Genérico de
## propósito: Jogadores Próximos usa Atributos / Solicitar amizade / Convidar para o grupo / Trocar ([SOC-05]), o painel do Grupo
## ([SOC-03]) reaproveita com Expulsar e o de Amigos ([SOC-04]) com Remover amigo. Opção desligada aparece apagada,
## com o motivo entre parênteses.

## Tocou na opção [param option_id] (uma das [PlayerActionsPanel.Option] de [method show_options]).
signal option_chosen(option_id: String)

## Uma opção do painel.
class Option:
	extends RefCounted
	## Id devolvido em [signal PlayerActionsPanel.option_chosen] (ex.: "attributes").
	var id: String = ""
	## Texto do botão.
	var text: String = ""
	## false = apagado, sem responder ao toque.
	var enabled: bool = true
	## Motivo de estar apagado, entre parênteses depois do texto (ex.: "em breve"); vazio = nada.
	var note: String = ""

	func _init(option_id: String, label: String, is_enabled: bool = true, why_disabled: String = "") -> void:
		id = option_id
		text = label
		enabled = is_enabled
		note = why_disabled


## Ids das opções que os painéis sociais usam ([SOC-02], [SOC-03], [SOC-04]).
const OPTION_ATTRIBUTES: String = "attributes"
const OPTION_FRIEND: String = "friend_request"
const OPTION_GROUP_INVITE: String = "group_invite"
const OPTION_GROUP_KICK: String = "group_kick"
const OPTION_FRIEND_REMOVE: String = "friend_remove"
## Guilda ([SOC-06]).
const OPTION_GUILD_INVITE: String = "guild_invite"
const OPTION_GUILD_KICK: String = "guild_kick"
const OPTION_GUILD_PROMOTE: String = "guild_promote"
const OPTION_GUILD_DEMOTE: String = "guild_demote"
## Troca ([SOC-05]).
const OPTION_TRADE: String = "trade"
## Mandar mensagem no privado do chat ([SOC-09]).
const OPTION_MESSAGE: String = "message"

## Jogador das opções abertas agora.
var player_id: String = ""
## "[nível] nome" do jogador (título).
var player_title: String = ""

var _buttons: VBoxContainer = null


func _init() -> void:
	super(0.0)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	body.add_child(_buttons)


## Mostra as opções [param options] sobre o jogador [param id] ([param title] = "[nível] nome").
func show_options(id: String, title: String, options: Array[Option]) -> void:
	player_id = id
	player_title = title
	set_title(title)
	for child: Node in _buttons.get_children():
		child.queue_free()
	for option: Option in options:
		var label: String = option.text if option.note.is_empty() else "%s (%s)" % [option.text, option.note]
		var button: Button = PixelMenuPanel.make_button(label)
		button.disabled = not option.enabled
		button.pressed.connect(option_chosen.emit.bind(option.id))
		_buttons.add_child(button)
