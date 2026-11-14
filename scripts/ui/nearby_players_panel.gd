class_name NearbyPlayersPanel
extends PixelMenuPanel
## Menu → "Jogadores Próximos" ([SOC-02]): lista quem está a até 45 m de você (a área de interesse,
## [constant Network.NEARBY_RADIUS]), um botão por jogador com "[nível] nome", do mais perto ao mais longe.
## A [Zone] chama [method show_players] a cada snapshot enquanto o painel está aberto (a lista acompanha quem chega,
## sai ou sobe de nível). Tocar num nome = [signal player_chosen] (a [Hud] abre as opções daquele jogador).

## Tocou no jogador [param player_id] ([param title] = "[nível] nome", para o título das opções).
signal player_chosen(player_id: String, title: String)

## Altura do painel (px): cabe ~6 nomes; mais que isso a lista rola.
const HEIGHT_PX: float = 980.0

var _empty_label: Label = null
var _list: VBoxContainer = null
## O que a lista mostra agora ("id|título" por linha): só remonta os botões quando muda (20 vezes por segundo
## remontando, o toque no meio de uma troca se perderia).
var _shown: PackedStringArray = PackedStringArray()


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Jogadores Próximos")
	_empty_label = PixelMenuPanel.make_label("Ninguém por perto (até %d m)." % roundi(Network.NEARBY_RADIUS), Color(1, 1, 1, 0.7))
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


## Mostra [param players] (já em ordem; ver [method Network.get_nearby_players]).
func show_players(players: Array[PlayerState]) -> void:
	var rows: PackedStringArray = PackedStringArray()
	for state: PlayerState in players:
		rows.append("%s|%s" % [state.id, state.title()])
	if rows == _shown:
		return
	_shown = rows
	for child: Node in _list.get_children():
		child.queue_free()
	for state: PlayerState in players:
		var button: Button = PixelMenuPanel.make_button(state.title(), true)
		# Deixa o arrasto chegar ao ScrollContainer (lista grande rola).
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(player_chosen.emit.bind(state.id, state.title()))
		_list.add_child(button)
	_empty_label.visible = players.is_empty()
