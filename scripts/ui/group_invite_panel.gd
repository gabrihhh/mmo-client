class_name GroupInvitePanel
extends PanelContainer
## Janela do convite de grupo recebido ([SOC-03]): "X convidou você para o grupo" com o tempo que falta e os botões
## **Aceitar** / **Recusar**, na moldura pixel art dos painéis (`PixelPanel`, [CLI-07]). Fica no alto da tela, logo
## abaixo da linha de XP, e **não pausa o jogo** (o joystick e as cartas continuam: o convite pode chegar no meio de uma
## luta). Vários convites ao mesmo tempo: um por vez, na ordem em que chegaram.
##
## Expirou (o servidor dá ~30 s, `expiresIn`): some sozinho, sem mandar nada — o servidor avisa quem convidou que não
## houve resposta. A [Hud] cria e repassa a resposta ([signal answered]) para o [Network].

## Respondeu ao convite de [param from_id] ([param accept] = Aceitar).
signal answered(from_id: String, accept: bool)

## Largura (px no espaço de referência 720×1280).
const WIDTH_PX: float = 640.0
## Distância do topo da tela (px): logo abaixo da moldura de vida/mana e da linha de XP ([CLI-08]).
const TOP_PX: float = 230.0


## Um convite esperando resposta.
class Invite:
	extends RefCounted
	var from_id: String = ""
	var from_name: String = ""
	## Segundos até expirar.
	var seconds_left: float = 0.0


var _queue: Array[Invite] = []
var _label: Label = null


func _init() -> void:
	theme_type_variation = &"PixelPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP_PX
	custom_minimum_size = Vector2(WIDTH_PX, 0.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	_label = PixelMenuPanel.make_label("")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var accept: Button = PixelMenuPanel.make_button("Aceitar")
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(_answer.bind(true))
	row.add_child(accept)
	var reject: Button = PixelMenuPanel.make_button("Recusar")
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject.pressed.connect(_answer.bind(false))
	row.add_child(reject)


## Chegou um convite de [param from_name] que expira em [param expires_in] s. Um novo convite da mesma pessoa
## substitui o anterior (renova o prazo).
func add_invite(from_id: String, from_name: String, expires_in: float) -> void:
	for existing: Invite in _queue:
		if existing.from_id == from_id:
			existing.seconds_left = expires_in
			_refresh()
			return
	var invite: Invite = Invite.new()
	invite.from_id = from_id
	invite.from_name = from_name
	invite.seconds_left = expires_in
	_queue.append(invite)
	_refresh()


## Esquece todos os convites (ex.: entrei num grupo; os outros convites não servem mais).
func clear() -> void:
	_queue.clear()
	_refresh()


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	var expired: bool = false
	for invite: Invite in _queue:
		invite.seconds_left -= delta
		expired = expired or invite.seconds_left <= 0.0
	if expired:
		var alive: Array[Invite] = []
		for invite: Invite in _queue:
			if invite.seconds_left > 0.0:
				alive.append(invite)
		_queue = alive
	_refresh()


func _answer(accept: bool) -> void:
	if _queue.is_empty():
		return
	var invite: Invite = _queue.pop_front()
	answered.emit(invite.from_id, accept)
	_refresh()


## Mostra o primeiro convite da fila (ou esconde, sem nenhum).
func _refresh() -> void:
	visible = not _queue.is_empty()
	if not visible:
		return
	var invite: Invite = _queue[0]
	var more: String = "" if _queue.size() == 1 else "\n(+%d convite%s)" % [_queue.size() - 1, "" if _queue.size() == 2 else "s"]
	_label.text = "%s convidou você para o grupo (%d s)%s" % [invite.from_name, ceili(invite.seconds_left), more]
