class_name RemotePlayer
extends Node3D
## Representação de outro jogador, desenhada a partir dos snapshots do servidor. Ver mmo-docs [INFRA-09].
##
## Não simula nada: a cada frame pede ao [PlayerState] a posição no tick
## [method Network.render_tick] (alguns ticks no PASSADO), interpolando entre dois snapshots reais.
## Isso troca ~100 ms de atraso por movimento suave e sem "adivinhação".

## Id do jogador no servidor (playerId).
var session_id: String = ""

## Nome exibido (username como foi cadastrado).
var display_name: String:
	get:
		return _state.name if _state != null and not _state.name.is_empty() else session_id

## Estado vivo do jogador (o [Network] guarda o histórico de snapshots nele).
var _state: PlayerState = null

@onready var _name_label: Label3D = $NameLabel


## Liga este nó ao estado do servidor. Chamar antes de adicionar à árvore.
func setup(id: String, state: PlayerState) -> void:
	session_id = id
	_state = state


func _ready() -> void:
	# Username exatamente como foi cadastrado (o id é interno).
	_name_label.text = display_name
	if _state != null:
		position = _state.position
		rotation.y = _state.rot_y


func _process(_delta: float) -> void:
	if _state == null or Network.instance == null:
		return
	var render_tick: float = Network.instance.render_tick()
	position = _state.sample_position(render_tick)
	rotation.y = _state.sample_rot_y(render_tick)
