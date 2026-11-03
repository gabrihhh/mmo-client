class_name RemotePlayer
extends Node3D
## Outro jogador (ou boneco/monstro), desenhado a partir dos snapshots do servidor. Ver mmo-docs [INFRA-09].
## Mostra nome, barra de vida e os itens vestidos ([ART-02]); morto, o corpo some até renascer ([JOGO-05]).
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
@onready var _health_bar: HealthBar3D = $HealthBar
@onready var _body: Node3D = $Body
var _shield_bubble: ShieldBubble = null


## Liga este nó ao estado do servidor. Chamar antes de adicionar à árvore.
func setup(id: String, state: PlayerState) -> void:
	session_id = id
	_state = state


func _ready() -> void:
	_shield_bubble = ShieldBubble.new()
	add_child(_shield_bubble)
	# Itens vestidos ([ART-02]); bonecos de treino não têm look e ficam sem nada.
	var equipment: EquipmentView = EquipmentView.new()
	_body.add_child(equipment)
	equipment.bind(_state)
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
	_health_bar.set_ratio(_state.hp_ratio())
	_body.visible = not _state.dead
	_health_bar.visible = not _state.dead
	_shield_bubble.set_active(_state.shield > 0.0 and not _state.dead)


## true se está vivo (pode ser alvo).
func is_alive() -> bool:
	return _state != null and not _state.dead
