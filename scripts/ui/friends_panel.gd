class_name FriendsPanel
extends PixelMenuPanel
## Menu → "Amigos" ([SOC-04]): lista dos meus amigos, um botão por amigo com o nome e "online"/"offline" (online
## primeiro, como o servidor manda). Tocar num amigo = [signal friend_chosen] (a [Hud] abre as opções: Atributos e
## Convidar para o grupo quando ele está na minha zona, e Remover amigo). A [Hud] chama [method show_friends] a cada
## mudança da lista (amigo novo, removido, entrou ou saiu do servidor). Mais de ~6 amigos: a lista rola.

## Tocou no amigo [param player_id] ([param title] = nome dele, para o título das opções).
signal friend_chosen(player_id: String, title: String)

## Altura do painel (px), igual à de Jogadores Próximos.
const HEIGHT_PX: float = 980.0
## Cor do texto de amigo offline (apagado).
const OFFLINE_COLOR: Color = Color(1, 1, 1, 0.55)

var _empty_label: Label = null
var _list: VBoxContainer = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Amigos")
	_empty_label = PixelMenuPanel.make_label(
		"Você ainda não tem amigos.\nPeça amizade em Jogadores Próximos.", Color(1, 1, 1, 0.7))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_empty_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)


## Mostra [param list] (na ordem do servidor).
func show_friends(list: FriendList) -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for friend: FriendList.Friend in list.friends:
		var button: Button = PixelMenuPanel.make_button(
			"%s · %s" % [friend.name, "online" if friend.online else "offline"], true)
		if not friend.online:
			button.add_theme_color_override("font_color", OFFLINE_COLOR)
		# Deixa o arrasto chegar ao ScrollContainer (lista grande rola).
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(friend_chosen.emit.bind(friend.id, friend.name))
		_list.add_child(button)
	_empty_label.visible = list.friends.is_empty()
