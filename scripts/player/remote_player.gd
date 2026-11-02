class_name RemotePlayer
extends Node3D
## Representação de outro jogador, controlada pelo estado vindo do servidor.
##
## Não tem física: a cada frame interpola suavemente até a última posição
## recebida (o servidor manda ~20 patches/s). Ver mmo-docs [CLI-04].

## Suavidade da interpolação; maior = acompanha mais rápido.
@export var smoothing: float = 12.0

## Session id do jogador no servidor.
var session_id: String = ""

## Estado vivo do jogador (o SDK atualiza este objeto a cada patch).
var _state: ZoneSchema.PlayerState = null

@onready var _name_label: Label3D = $NameLabel


## Liga este nó ao estado do servidor. Chamar antes de adicionar à árvore.
func setup(id: String, state: ZoneSchema.PlayerState) -> void:
	session_id = id
	_state = state


func _ready() -> void:
	_name_label.text = session_id
	if _state != null:
		position = _state.get_world_position()
		rotation.y = _state.get_rot_y()


func _process(delta: float) -> void:
	if _state == null:
		return
	var weight: float = 1.0 - exp(-smoothing * delta)
	position = position.lerp(_state.get_world_position(), weight)
	rotation.y = lerp_angle(rotation.y, _state.get_rot_y(), weight)
