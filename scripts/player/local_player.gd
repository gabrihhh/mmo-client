class_name LocalPlayer
extends Node3D
## Jogador controlado por este aparelho, com PREDIÇÃO e RECONCILIAÇÃO. Ver mmo-docs [INFRA-09], [CLI-04].
##
## O servidor é a autoridade: este nó não decide onde o jogador está, só o que ele QUER fazer.
## A cada tick de simulação (20 Hz) ele:
## 1. lê o joystick/teclado e converte para uma direção no mundo (relativa à câmera);
## 2. manda o input numerado ao servidor ([method Network.send_input]);
## 3. aplica o MESMO input localmente com [Movement] (predição), para responder na hora.
## Quando chega um snapshot, pega a posição oficial, descarta os inputs que o servidor já aplicou
## (ack) e reaplica os que faltam (reconciliação). Diferenças pequenas são suavizadas visualmente.

## Velocidade de giro VISUAL do modelo (a direção "oficial" vem da simulação).
@export var turn_speed: float = 14.0
## Quão rápido some a correção visual quando a predição e o servidor discordam (1/s).
@export var correction_smoothing: float = 12.0

## Joystick de toque; atribuído pela zona ao criar o jogador. Pode ser null.
var joystick: TouchJoystick = null

## Divergência (m) acima da qual a correção é aplicada na hora, sem suavizar (ex.: teleporte).
## Cor da camisa do seu personagem (os outros são vermelhos).
const SHIRT_COLOR: Color = Color(0.25, 0.5, 1.0)
const _SNAP_DISTANCE: float = 2.0
## Abaixo deste comprimento o input conta como parado e não é enviado.
const _MIN_INPUT: float = 0.01
## Dev/testes: `-- --bot-walk` faz o jogador andar em círculo sozinho, usar Disparada e Investida
## (se vestidas) de vez em quando e imprimir o tamanho das correções do servidor a cada 5 s (valida
## predição/reconciliação sem ninguém no controle).
const BOT_WALK_ARG: String = "--bot-walk"


## Um comando enviado e ainda não confirmado pelo servidor: passo de movimento ou Investida/Disparada.
## Guarda o que foi PREVISTO (multiplicador da Disparada, distância da Investida) para a reconciliação
## reaplicar exatamente igual ([JOGO-07]).
class PendingInput:
	extends RefCounted
	var seq: int
	var x: float
	var z: float
	## Multiplicador de velocidade usado neste passo (Disparada = 2; normal = 1).
	var speed_multiplier: float = 1.0
	## > 0: é uma Investida desta distância (x, z = direção), não um passo.
	var dash_distance: float = 0.0

	func _init(input_seq: int, input_x: float, input_z: float) -> void:
		seq = input_seq
		x = input_x
		z = input_z


@onready var _camera: IsometricCamera = $Camera
@onready var _name_label: Label3D = $NameLabel
@onready var _health_bar: HealthBar3D = $HealthBar
@onready var _body: Node3D = $Body
## Boneco (animação e itens vestidos, [ART-03]).
@onready var model: CharacterModel = $Body/Character
var _shield_bubble: ShieldBubble = null
## Velocidade (m/s) suavizada, para a animação de correr.
var _anim_speed: float = 0.0
## Queda ao morrer.
var _death: DeathFall = DeathFall.new()
## Ação animada no toque, antes do "cast_start" do servidor ([JOGO-08]): habilidade e quando (ms).
var _predicted_ability: String = ""
var _predicted_at_ms: int = 0
## Até quanto tempo (ms) depois do toque o "cast_start" conta como confirmação da animação prevista.
const _PREDICTION_WINDOW_MS: int = 800

## Estado previsto agora e o do tick anterior (o desenho interpola entre os dois).
var _sim: Movement.State = Movement.State.new()
var _previous_sim: Movement.State = Movement.State.new()
## Tempo acumulado ainda não simulado, em segundos.
var _accumulator: float = 0.0
var _next_seq: int = 1
var _pending: Array[PendingInput] = []
## Deslocamento visual que esconde correções pequenas; decai até zero.
var _visual_offset: Vector3 = Vector3.ZERO
## Virar para um ponto (lançamento de golpe/habilidade): enquanto [member _face_until_ms] não passar, o modelo
## olha para [member _face_point] em vez da direção do movimento ([JOGO-05]).
var _face_point: Vector3 = Vector3.ZERO
var _face_until_ms: int = 0
## Disparada prevista ([JOGO-07]): multiplicador para os próximos passos, até acabar os passos ou o tempo.
## Mesma regra do servidor (Zone.step): conta em PASSOS para a predição bater mesmo com a rede variando.
var _boost_multiplier: float = 1.0
var _boost_steps_left: int = 0
var _boost_until_ms: int = 0
var _bot_walk: bool = false
## Dev ([BotFight]): direção de movimento forçada no mundo (x, z); zero = joystick/teclado normais.
var bot_direction: Vector2 = Vector2.ZERO
var _bot_time: float = 0.0
## Estatística de correções (só com --bot-walk): quantas, a maior e a soma, em metros.
var _corrections: int = 0
var _max_correction: float = 0.0
var _correction_sum: float = 0.0


func _ready() -> void:
	InputActions.register_defaults()
	Network.instance.snapshot_received.connect(_on_snapshot_received)
	# Username exatamente como foi cadastrado.
	_name_label.text = Network.instance.username
	_bot_walk = BOT_WALK_ARG in OS.get_cmdline_user_args()
	_shield_bubble = ShieldBubble.new()
	add_child(_shield_bubble)
	model.set_shirt_color(SHIRT_COLOR)


## Giro da câmera (rad): converte direções da tela (joystick, mira) em direções no mundo.
func get_camera_yaw() -> float:
	return _camera.get_yaw_radians()


## Para onde o personagem está virado, no plano XZ (normalizado).
func get_facing() -> Vector3:
	return Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, rotation.y)


## Coloca o jogador no estado oficial (spawn) e cola a câmera nele.
func spawn_at(state: PlayerState) -> void:
	_sim = Movement.State.new(state.x, state.y, state.z, state.rot_y)
	_previous_sim = _sim.duplicate_state()
	_pending.clear()
	_visual_offset = Vector3.ZERO
	global_position = _sim.position()
	rotation.y = _sim.rot_y
	_camera.snap_to_target()
	model.bind_look(state)


func _process(delta: float) -> void:
	var network: Network = Network.instance
	var step_seconds: float = network.tick_seconds()
	_accumulator += delta
	# Passo fixo: simula quantos ticks inteiros couberem (igual ao servidor).
	while _accumulator >= step_seconds:
		_accumulator -= step_seconds
		_simulate_tick(network, step_seconds)

	# Vida e morte vêm do servidor ([JOGO-05]): morto, o corpo cai, some e não anda.
	var own: PlayerState = network.get_player(network.player_id)
	if own != null:
		_health_bar.set_ratio(own.hp_ratio())
		_death.update(_body, own.dead, delta)
		_health_bar.visible = not own.dead
		_shield_bubble.set_active(own.shield > 0.0 and not own.dead)

	# Desenho: entre o tick anterior e o atual, mais a correção visual que está sumindo.
	var alpha: float = _accumulator / step_seconds
	_visual_offset *= exp(-correction_smoothing * delta)
	global_position = _previous_sim.position().lerp(_sim.position(), alpha) + _visual_offset
	rotation.y = lerp_angle(rotation.y, _target_yaw(), 1.0 - exp(-turn_speed * delta))

	# Animação de pernas pela velocidade da simulação (sem o ruído das correções).
	var tick_move: Vector3 = _sim.position() - _previous_sim.position()
	tick_move.y = 0.0
	_anim_speed = lerpf(_anim_speed, tick_move.length() / step_seconds, 1.0 - exp(-12.0 * delta))
	model.set_move_speed(_anim_speed / maxf(network.move_speed, 0.1))


## Anima a ação de [param ability_id] já no toque (sem esperar a ida e volta pela rede). O "cast_start" do
## servidor confirma ([method consume_prediction]); uma recusa interrompe ([method cancel_prediction]).
func predict_action(ability_id: String, cast_time: float) -> void:
	model.play_action(AbilityVisuals.animation(ability_id), cast_time)
	_predicted_ability = ability_id
	_predicted_at_ms = Time.get_ticks_msec()


## true se [param ability_id] já foi animada no toque há pouco (aí o "cast_start" não reinicia a animação).
func consume_prediction(ability_id: String) -> bool:
	var predicted: bool = _predicted_ability == ability_id and Time.get_ticks_msec() - _predicted_at_ms < _PREDICTION_WINDOW_MS
	if predicted:
		_predicted_ability = ""
	return predicted


## O servidor recusou: para a animação prevista (se ainda não foi confirmada).
func cancel_prediction() -> void:
	if not _predicted_ability.is_empty() and Time.get_ticks_msec() - _predicted_at_ms < _PREDICTION_WINDOW_MS:
		model.stop_action()
	_predicted_ability = ""


## Mantém o modelo virado para [param world_point] por [param seconds] (lançamento). Só visual: a
## direção "oficial" de quem está lançando quem decide é o servidor.
func face_toward(world_point: Vector3, seconds: float) -> void:
	_face_point = world_point
	_face_until_ms = Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)


## Para onde o modelo deve olhar agora: o ponto do lançamento, ou a direção da simulação.
func _target_yaw() -> float:
	if Time.get_ticks_msec() < _face_until_ms:
		var flat: Vector3 = Vector3(_face_point.x - global_position.x, 0.0, _face_point.z - global_position.z)
		if flat.length_squared() > 0.0001:
			return atan2(-flat.x, -flat.z)
	return _sim.rot_y


func _simulate_tick(network: Network, step_seconds: float) -> void:
	_previous_sim = _sim
	var own: PlayerState = network.get_player(network.player_id)
	if own != null and own.dead:
		return
	var direction: Vector2 = _read_world_direction()
	if direction.length() < _MIN_INPUT:
		return
	var input: PendingInput = PendingInput.new(_next_seq, direction.x, direction.y)
	_next_seq += 1
	input.speed_multiplier = _consume_boost_step()
	_pending.append(input)
	network.send_input(input.seq, input.x, input.z)
	_sim = _apply_pending(_sim, input, step_seconds, network)


## Multiplicador do próximo passo (gasta um passo da Disparada, se ativa).
func _consume_boost_step() -> float:
	if _boost_steps_left <= 0 or Time.get_ticks_msec() >= _boost_until_ms:
		_boost_steps_left = 0
		return 1.0
	_boost_steps_left -= 1
	return _boost_multiplier


## Aplica um comando previsto: Investida (deslocamento) ou passo (com o multiplicador que foi previsto).
func _apply_pending(state: Movement.State, input: PendingInput, step_seconds: float, network: Network) -> Movement.State:
	if input.dash_distance > 0.0:
		return Movement.dash(state, input.x, input.z, input.dash_distance, network.zone_half_size)
	return Movement.step(state, input.x, input.z, step_seconds, network.move_speed * input.speed_multiplier, network.zone_half_size)


## Investida/Disparada com predição ([JOGO-07]): entra na MESMA sequência dos passos, aplica na hora aqui e
## manda ao servidor com o seq, que processa na mesma ordem. Se o servidor recusar (recarga, mana), a
## reconciliação desfaz. [param dir_x]/[param dir_z] = direção da Investida. Devolve false se morto.
func cast_movement(ability: AbilityView, dir_x: float, dir_z: float) -> bool:
	var network: Network = Network.instance
	var own: PlayerState = network.get_player(network.player_id)
	if own != null and own.dead:
		return false
	var command: PendingInput = PendingInput.new(_next_seq, 0.0, 0.0)
	_next_seq += 1
	if ability.dash_distance > 0.0:
		command.x = dir_x
		command.z = dir_z
		command.dash_distance = ability.dash_distance
	if ability.speed_multiplier > 0.0:
		_boost_multiplier = ability.speed_multiplier
		_boost_steps_left = roundi(ability.speed_seconds * network.tick_rate)
		_boost_until_ms = Time.get_ticks_msec() + int(ability.speed_seconds * 1000.0)
	_pending.append(command)
	_sim = _apply_pending(_sim, command, network.tick_seconds(), network)
	if command.dash_distance > 0.0:
		network.send_cast(ability.id, "", command.x, command.z, command.seq)
	else:
		network.send_cast(ability.id, "", NAN, NAN, command.seq)
	return true


## Reconciliação: estado oficial + inputs ainda não confirmados = nova previsão.
func _on_snapshot_received(_tick: int, ack: int) -> void:
	var network: Network = Network.instance
	var authoritative: PlayerState = network.get_player(network.player_id)
	if authoritative == null:
		return
	while not _pending.is_empty() and _pending[0].seq <= ack:
		_pending.pop_front()

	var corrected: Movement.State = Movement.State.new(authoritative.x, authoritative.y, authoritative.z, authoritative.rot_y)
	for input: PendingInput in _pending:
		corrected = _apply_pending(corrected, input, network.tick_seconds(), network)

	var error: Vector3 = _sim.position() - corrected.position()
	if _bot_walk:
		_record_correction(error.length())
	if error.length_squared() < 0.000001:
		return
	if error.length() > _SNAP_DISTANCE:
		_visual_offset = Vector3.ZERO
		_previous_sim = corrected.duplicate_state()
	else:
		_visual_offset += error
		_previous_sim = Movement.State.new(_previous_sim.x - error.x, _previous_sim.y - error.y, _previous_sim.z - error.z, _previous_sim.rot_y)
	_sim = corrected


## --bot-walk: usa Disparada e Investida (se vestidas) assim que a recarga e a mana permitem.
var _bot_ready_at: Dictionary[String, float] = {}


func _bot_use_movement_abilities() -> void:
	var network: Network = Network.instance
	if network.inventory == null:
		return
	for ability: AbilityView in network.inventory.cards():
		if ability == null or not ability.is_movement() or network.mana < ability.mana_cost + 1.0:
			continue
		var ready_at: float = _bot_ready_at[ability.id] if _bot_ready_at.has(ability.id) else 1.0
		if _bot_time >= ready_at:
			# Folga de 0,5 s sobre a recarga (o relógio do servidor começa um pouco depois).
			_bot_ready_at[ability.id] = _bot_time + ability.cooldown_s + 0.5
			cast_movement(ability, cos(_bot_time * 0.8), sin(_bot_time * 0.8))


func _record_correction(distance: float) -> void:
	if distance > 0.0001:
		_corrections += 1
		_max_correction = maxf(_max_correction, distance)
		_correction_sum += distance


## Direção desejada no mundo (x, z), comprimento até 1: joystick + teclado, relativa ao giro da câmera.
func _read_world_direction() -> Vector2:
	if _bot_walk:
		_bot_time += Network.instance.tick_seconds()
		if fmod(_bot_time, 5.0) < Network.instance.tick_seconds():
			print("BotWalk: pos=%s pendentes=%d correções=%d maior=%.4f m média=%.4f m" % [
				_sim.position(), _pending.size(), _corrections, _max_correction,
				_correction_sum / maxf(1.0, float(_corrections))])
		_bot_use_movement_abilities()
		return Vector2(cos(_bot_time * 0.8), sin(_bot_time * 0.8))
	if bot_direction != Vector2.ZERO:
		return bot_direction.limit_length(1.0)
	var touch: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	var screen: Vector2 = (touch + InputActions.get_keyboard_vector()).limit_length(1.0)
	var world: Vector3 = Vector3(screen.x, 0.0, screen.y).rotated(Vector3.UP, _camera.get_yaw_radians())
	return Vector2(world.x, world.z)
