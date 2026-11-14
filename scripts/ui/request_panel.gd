class_name RequestPanel
extends PanelContainer
## Janela dos pedidos recebidos que esperam resposta: **convite de grupo** ([SOC-03], "X convidou você para o grupo")
## e **pedido de amizade** ([SOC-04], "X quer ser seu amigo"), com o tempo que falta e os botões **Aceitar** /
## **Recusar**, na moldura pixel art dos painéis (`PixelPanel`, [CLI-07]). Fica no alto da tela, logo abaixo da linha
## de XP, e **não pausa o jogo** (o joystick e as cartas continuam: o pedido pode chegar no meio de uma luta). Vários
## pedidos ao mesmo tempo (dos dois tipos): um por vez, na ordem em que chegaram.
##
## Expirou (o servidor dá ~30 s, `expiresIn`): some sozinho, sem mandar nada — o servidor avisa quem pediu que não
## houve resposta. A [Hud] cria e repassa a resposta ([signal answered]) para o [Network].
## > mudança (2026-11-14): era o `GroupInvitePanel` (só grupo); generalizado para a amizade na etapa 3.

## Respondeu ao pedido do tipo [param kind] ([constant KIND_GROUP] / [constant KIND_FRIEND]) de [param from_id]
## ([param accept] = Aceitar).
signal answered(kind: String, from_id: String, accept: bool)

## Tipos de pedido.
const KIND_GROUP: String = "group"
const KIND_FRIEND: String = "friend"
## Largura (px no espaço de referência 720×1280).
const WIDTH_PX: float = 640.0
## Distância do topo da tela (px): logo abaixo da moldura de vida/mana e da linha de XP ([CLI-08]).
const TOP_PX: float = 230.0
## Texto de cada tipo (%s = nome de quem pediu).
const _TEXTS: Dictionary[String, String] = {
	KIND_GROUP: "%s convidou você para o grupo",
	KIND_FRIEND: "%s quer ser seu amigo",
}


## Um pedido esperando resposta.
class Request:
	extends RefCounted
	## [constant RequestPanel.KIND_GROUP] ou [constant RequestPanel.KIND_FRIEND].
	var kind: String = ""
	var from_id: String = ""
	var from_name: String = ""
	## Segundos até expirar.
	var seconds_left: float = 0.0


var _queue: Array[Request] = []
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


## Chegou um pedido do tipo [param kind] de [param from_name] que expira em [param expires_in] s. Um novo pedido do
## mesmo tipo e da mesma pessoa substitui o anterior (renova o prazo).
func add_request(kind: String, from_id: String, from_name: String, expires_in: float) -> void:
	for existing: Request in _queue:
		if existing.kind == kind and existing.from_id == from_id:
			existing.seconds_left = expires_in
			_refresh()
			return
	var request: Request = Request.new()
	request.kind = kind
	request.from_id = from_id
	request.from_name = from_name
	request.seconds_left = expires_in
	_queue.append(request)
	_refresh()


## Esquece os pedidos do tipo [param kind] (ex.: entrei num grupo; os outros convites de grupo não servem mais).
func clear_kind(kind: String) -> void:
	var kept: Array[Request] = []
	for request: Request in _queue:
		if request.kind != kind:
			kept.append(request)
	_queue = kept
	_refresh()


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	var expired: bool = false
	for request: Request in _queue:
		request.seconds_left -= delta
		expired = expired or request.seconds_left <= 0.0
	if expired:
		var alive: Array[Request] = []
		for request: Request in _queue:
			if request.seconds_left > 0.0:
				alive.append(request)
		_queue = alive
	_refresh()


func _answer(accept: bool) -> void:
	if _queue.is_empty():
		return
	var request: Request = _queue.pop_front()
	answered.emit(request.kind, request.from_id, accept)
	_refresh()


## Mostra o primeiro pedido da fila (ou esconde, sem nenhum).
func _refresh() -> void:
	visible = not _queue.is_empty()
	if not visible:
		return
	var request: Request = _queue[0]
	var more: String = "" if _queue.size() == 1 else "\n(+%d pedido%s)" % [_queue.size() - 1, "" if _queue.size() == 2 else "s"]
	var text: String = _TEXTS.get(request.kind, "%s")
	_label.text = "%s (%d s)%s" % [text % request.from_name, ceili(request.seconds_left), more]
