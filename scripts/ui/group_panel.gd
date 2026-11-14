class_name GroupPanel
extends PixelMenuPanel
## Menu → "Grupo" ([SOC-03]; o botão só aparece no Menu quando estou num grupo): lista os membros com
## "[nível] nome", o líder marcado com "(líder)" e eu com "(você)", na ordem em que entraram. Tocar num membro (não em
## mim) = [signal member_chosen] (a [Hud] abre as opções: Atributos, Solicitar amizade e, se sou o líder, Expulsar).
## Embaixo, o botão **Sair do grupo**. A [Hud] chama [method show_group] a cada mudança do grupo.

## Tocou no membro [param player_id] ([param title] = "[nível] nome", para o título das opções).
signal member_chosen(player_id: String, title: String)
## Tocou em "Sair do grupo".
signal leave_pressed

## Altura do painel (px): cabem os 5 membros + "Sair do grupo".
const HEIGHT_PX: float = 980.0

var _list: VBoxContainer = null
var _count_label: Label = null


func _init() -> void:
	super(HEIGHT_PX)
	set_title("Grupo")
	_count_label = PixelMenuPanel.make_label("", Color(1, 1, 1, 0.7))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_count_label)
	_list = VBoxContainer.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	body.add_child(_list)
	var leave: Button = PixelMenuPanel.make_button("Sair do grupo")
	leave.pressed.connect(leave_pressed.emit)
	body.add_child(leave)


## Mostra [param group] ([param own_id] = meu id, para marcar "(você)" e não abrir opções sobre mim).
func show_group(group: GroupState, own_id: String) -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	if group == null:
		_count_label.text = "Você não está em um grupo."
		return
	_count_label.text = "%d de %d jogadores" % [group.members.size(), GroupState.MAX_MEMBERS]
	for member: GroupState.Member in group.members:
		var marks: PackedStringArray = PackedStringArray()
		if member.id == group.leader_id:
			marks.append("líder")
		if member.id == own_id:
			marks.append("você")
		var label: String = member.title() if marks.is_empty() else "%s (%s)" % [member.title(), ", ".join(marks)]
		var button: Button = PixelMenuPanel.make_button(label, true)
		if member.id == own_id:
			button.disabled = true
		else:
			button.pressed.connect(member_chosen.emit.bind(member.id, member.title()))
		_list.add_child(button)
