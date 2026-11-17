class_name ChatBubble
extends Label3D
## Balão do chat Geral ([SOC-09]) em cima da cabeça de quem falou: a mensagem (cortada) por
## [constant SECONDS] s, acima do nome, sempre de frente para a câmera. Só para quem está na tela (o nó só existe
## para quem está na área de visão, [INFRA-11]).

## Quanto tempo (s) o balão fica.
const SECONDS: float = 5.0
## Máximo de caracteres mostrados (o resto vira "…").
const MAX_CHARS: int = 60
## Altura (m) acima do nome; sem nome, altura fixa acima dos pés.
const ABOVE_NAME_M: float = 0.45
const FALLBACK_HEIGHT_M: float = 2.7

var _left: float = SECONDS


## Mostra [param text] em cima de [param entity] (troca o balão anterior, se houver).
static func show_on(entity: Node3D, text: String) -> void:
	var old: Node = entity.get_node_or_null("ChatBubble")
	if old != null:
		old.queue_free()
		entity.remove_child(old)
	var bubble: ChatBubble = ChatBubble.new()
	bubble.name = "ChatBubble"
	bubble.text = text if text.length() <= MAX_CHARS else text.substr(0, MAX_CHARS - 1) + "…"
	var name_label: Label3D = entity.get_node_or_null("NameLabel") as Label3D
	bubble.position = Vector3(0.0, name_label.position.y + ABOVE_NAME_M if name_label != null else FALLBACK_HEIGHT_M, 0.0)
	entity.add_child(bubble)


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	pixel_size = 0.005
	font_size = 36
	outline_size = 12
	outline_modulate = Color(0.08, 0.06, 0.04)
	modulate = Color(1.0, 1.0, 0.92)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	width = 520.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
	elif _left < 0.5:
		modulate.a = _left / 0.5
