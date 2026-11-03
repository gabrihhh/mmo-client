class_name RemotePlayer
extends Node3D
## Outro jogador (ou boneco/monstro), desenhado a partir dos snapshots do servidor. Ver mmo-docs [INFRA-09].
## Mostra nome, barra de vida e os itens vestidos ([ART-02]); morto, o corpo cai e some até renascer ([JOGO-05]).
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
## Boneco animado ([ART-03]); null nos bonecos de treino (que têm só um corpo simples).
@onready var model: CharacterModel = get_node_or_null("Body/Character") as CharacterModel
var _shield_bubble: ShieldBubble = null
## Velocidade (m/s) suavizada, para a animação de correr.
var _anim_speed: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
## Queda ao morrer.
var _death: DeathFall = DeathFall.new()
## Balanço do boneco de treino ao apanhar (1 = acabou de apanhar, some em ~0,6 s).
var _wobble: float = 0.0
var _wobble_time: float = 0.0

## Cor da camisa dos outros jogadores (a sua é azul).
const SHIRT_COLOR: Color = Color(0.9, 0.3, 0.25)


## Liga este nó ao estado do servidor. Chamar antes de adicionar à árvore.
func setup(id: String, state: PlayerState) -> void:
	session_id = id
	_state = state


func _ready() -> void:
	_shield_bubble = ShieldBubble.new()
	add_child(_shield_bubble)
	if model != null:
		# Modelo do corpo que este jogador escolheu ([CharacterBodies]).
		if _state != null:
			model = CharacterBodies.swap(model, _state.body)
		model.set_shirt_color(SHIRT_COLOR)
		model.bind_look(_state)
	# Username exatamente como foi cadastrado (o id é interno).
	_name_label.text = display_name
	if _state != null:
		position = _state.position
		rotation.y = _state.rot_y
	_last_position = position


func _process(delta: float) -> void:
	if _state == null or Network.instance == null:
		return
	var render_tick: float = Network.instance.render_tick()
	position = _state.sample_position(render_tick)
	rotation.y = _state.sample_rot_y(render_tick)
	_health_bar.set_ratio(_state.hp_ratio())
	_death.update(_body, _state.dead, delta)
	_health_bar.visible = not _state.dead
	_shield_bubble.set_active(_state.shield > 0.0 and not _state.dead)
	if model != null and delta > 0.0:
		var moved: Vector3 = position - _last_position
		moved.y = 0.0
		_anim_speed = lerpf(_anim_speed, moved.length() / delta, 1.0 - exp(-10.0 * delta))
		model.set_move_speed(_anim_speed / maxf(Network.instance.move_speed, 0.1))
	_last_position = position
	# Boneco de treino apanhando: balança para trás e para a frente e para.
	if _wobble > 0.0 and not _death.is_dead():
		_wobble = maxf(_wobble - delta / 0.6, 0.0)
		_wobble_time += delta
		_body.rotation.x = sin(_wobble_time * 28.0) * 0.14 * _wobble
	elif _wobble_time > 0.0:
		_wobble = 0.0
		_wobble_time = 0.0
		if not _death.is_dead():
			_body.rotation.x = 0.0


## Apanhou: o personagem recua; boneco de treino (sem personagem) balança.
func react_to_hit() -> void:
	if model != null:
		model.flinch()
	else:
		_wobble = 1.0


## true se está vivo (pode ser alvo).
func is_alive() -> bool:
	return _state != null and not _state.dead
