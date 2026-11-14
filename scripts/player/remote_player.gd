class_name RemotePlayer
extends Node3D
## Outro jogador (ou boneco/monstro), desenhado a partir dos snapshots do servidor. Ver mmo-docs [INFRA-09].
## Mostra "[nível] nome", barra de vida e os itens vestidos ([ART-02]); morto, o corpo cai e some até renascer ([JOGO-05]).
## Monstro ([JOGO-13]): só vida, o quadrado do nível ao lado dela e, acima, a barra de lançamento (enche enquanto ele
## carrega um golpe/habilidade: [method show_cast]); sem nome.
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
## Mana embaixo da vida ([CLI-04]); some em quem não tem mana (bonecos).
@onready var _mana_bar: HealthBar3D = $ManaBar
## Barra de lançamento acima da vida (só monstros, [JOGO-13]); null na cena do boneco de treino.
@onready var _cast_bar: HealthBar3D = get_node_or_null("CastBar") as HealthBar3D
@onready var _body: Node3D = $Body
## Boneco animado ([ART-03]); null nos bonecos de treino (que têm só um corpo simples).
@onready var model: CharacterModel = get_node_or_null("Body/Character") as CharacterModel
## Altura visual do chão sob o personagem (m), suavizada.
var _ground_y: float = 0.0
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
## Cor da camisa dos monstros (zumbi: verde apagado), para não confundir com jogadores sem nome.
const MONSTER_SHIRT_COLOR: Color = Color(0.35, 0.45, 0.3)

## Lançamento em andamento (monstros): segundos que já passaram e o total; total 0 = nenhum.
var _cast_elapsed: float = 0.0
var _cast_duration: float = 0.0
## Último texto/nível mostrado (só refaz o rótulo quando muda).
var _shown_level: int = -1


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
		model.set_shirt_color(MONSTER_SHIRT_COLOR if _state != null and _state.monster else SHIRT_COLOR)
		model.bind_look(_state)
	# Username exatamente como foi cadastrado (o id é interno). Monstro: sem nome ([JOGO-13]).
	_name_label.text = display_name
	_name_label.visible = not is_monster()
	if _state != null:
		_ground_y = ZoneTerrain.height_at(_state.position.x, _state.position.z)
		position = _state.position + Vector3.UP * _ground_y
		rotation.y = _state.rot_y
	_last_position = position


func _process(delta: float) -> void:
	if _state == null or Network.instance == null:
		return
	if not _sync_view():
		return
	var render_tick: float = Network.instance.render_tick()
	position = _state.sample_position(render_tick)
	# Altura do chão (só visual, [MUN-03]), suavizada nos degraus.
	_ground_y = lerpf(_ground_y, ZoneTerrain.height_at(position.x, position.z), 1.0 - exp(-18.0 * delta))
	position.y += _ground_y
	rotation.y = _state.sample_rot_y(render_tick)
	_health_bar.set_values(_state.hp_ratio(), _state.shield_ratio())
	_refresh_level()
	_update_cast_bar(delta)
	_death.update(_body, _state.dead, delta)
	_health_bar.visible = not _state.dead
	_mana_bar.set_ratio(_state.mana_ratio())
	_mana_bar.visible = _state.has_mana() and not _state.dead
	_shield_bubble.set_active(_state.shield > 0.0 and not _state.dead, _state.guard > 0.0 and not _state.dead)
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


## true se é monstro (zumbi, [JOGO-13]).
func is_monster() -> bool:
	return _state != null and _state.monster


## Monstro começou a carregar algo que dura [param duration] s: a barra acima da vida enche até sair.
## Instantâneo (0 s) não mostra nada. Outros (jogadores, NPCs de teste) ignoram.
func show_cast(duration: float) -> void:
	if not is_monster() or duration <= 0.0:
		return
	_cast_elapsed = 0.0
	_cast_duration = duration


## O lançamento acabou antes (cancelado, morreu): some a barra.
func hide_cast() -> void:
	_cast_duration = 0.0


## Nível no rótulo (jogador: "[nível] nome") ou no quadrado ao lado da vida (monstro). Só quando muda.
func _refresh_level() -> void:
	if _state.level == _shown_level:
		return
	_shown_level = _state.level
	if is_monster():
		_health_bar.set_level_badge(_state.level)
	elif Network.instance.get_player(session_id) != null:
		# Só jogadores: bonecos de treino e NPCs de teste continuam com o nome.
		_name_label.text = _state.title()


func _update_cast_bar(delta: float) -> void:
	if _cast_bar == null:
		return
	if _cast_duration > 0.0:
		_cast_elapsed += delta
		if _cast_elapsed >= _cast_duration or _state.dead:
			_cast_duration = 0.0
	_cast_bar.visible = _cast_duration > 0.0
	if _cast_bar.visible:
		_cast_bar.set_ratio(_cast_elapsed / _cast_duration)


## Apanhou: o personagem recua; boneco de treino (sem personagem) balança.
func react_to_hit() -> void:
	if model != null:
		model.flinch()
	else:
		_wobble = 1.0


## true se está vivo e por perto (pode ser alvo). Fora da área de interesse não conta ([INFRA-04]).
func is_alive() -> bool:
	return _state != null and not _state.dead and _state.in_view


## Área de interesse ([INFRA-04]): fora dela o nó some e o modelo para de animar (não gasta GPU nem CPU); ao voltar,
## reaparece já no lugar certo (sem deslizar de onde estava). Devolve true se está à vista.
func _sync_view() -> bool:
	if _state.in_view == visible:
		return visible
	visible = _state.in_view
	if model != null:
		model.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	if visible:
		_ground_y = ZoneTerrain.height_at(_state.x, _state.z)
		position = _state.position + Vector3.UP * _ground_y
		_last_position = position
	return visible
