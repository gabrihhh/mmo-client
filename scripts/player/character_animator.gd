class_name CharacterAnimator
extends AnimationTree
## Animação do personagem em duas camadas ([JOGO-08], [ART-03]):
## - pernas (corpo todo, por baixo): mistura "idle" ↔ "run" pela velocidade de movimento;
## - tronco e braços (por cima, só os ossos de [constant UPPER_BONES]): uma ação de cada vez (ataque, magia).
## Assim dá para andar lançando. Parado, a ação toca no corpo todo (versão "<nome>_full", com quadril e pernas: o
## giro gira o corpo inteiro); se começar a andar no meio, troca para a versão só de cima no mesmo ponto. As ações de
## [constant ALWAYS_FULL] tocam no corpo todo mesmo andando. A ação toca na velocidade que faz o momento do golpe ([constant HIT_TIMES])
## cair no fim do lançamento do servidor ([method play_action]).
##
## A árvore é montada em código ([method setup]) com a biblioteca de animações do personagem.

## Ossos da camada de ação (tronco, cabeça e braços). Nomes do perfil humanoide ([ART-03]). UpperChest e ombros
## só existem em alguns modelos (ex.: Mixamo); osso que o esqueleto não tem é ignorado.
const UPPER_BONES: Array[String] = [
	"Spine", "Chest", "UpperChest", "Neck", "Head",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
]
## Ossos que só a camada de movimento mexe.
const LOWER_BONES: Array[String] = [
	"Hips", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
]
## Momento do golpe (s, na velocidade normal) de cada ação: é ele que encaixa no fim do lançamento.
## 0 = sem momento certo (toca na velocidade normal). ATENÇÃO: medido nas animações já cortadas (Meshy e Mixamo,
## tools/characters/make_animations.gd: MESHY_ACTIONS, MIXAMO_GREAT_SWORD...) pela mão direita (mais à frente
## descendo, logo depois do pico de velocidade); mudou o clipe ou o corte → medir de novo. O placeholder
## (tools/placeholders/make_character.gd) tem outros tempos e fica fora de sincronia (não é usado no jogo).
## Animação própria de item ("skill_<abilityId>", [ART-08]): medir e pôr aqui com esse nome; sem linha toca na
## velocidade normal.
const HIT_TIMES: Dictionary[String, float] = {
	"attack_sword": 0.87,
	"attack_greatsword": 0.6,
	"attack_staff": 0.47,
	"attack_punch": 0.3,
	"heavy_strike": 1.23,
	"cast_forward": 0.9,
	"cast_up": 1.6,
	"spin": 0.9,
	"buff": 0.57,
	"dash": 0.0,
	"flinch": 0.0,
}
## Limites da velocidade da ação (lançamento muito curto/longo não deixa a animação absurda).
const MIN_ACTION_SPEED: float = 0.25
const MAX_ACTION_SPEED: float = 4.0
## Sufixo da versão de corpo todo de uma ação na biblioteca (gerada por tools/characters/make_animations.gd).
const FULL_SUFFIX: String = "_full"
## Ações que tocam no corpo todo mesmo andando (o giro gira o corpo inteiro enquanto o personagem se move).
const ALWAYS_FULL: Array[String] = ["spin"]
## Mistura idle↔corrida acima da qual o personagem conta como andando (ação só no tronco).
const MOVING_BLEND: float = 0.1

var _action_node: AnimationNodeAnimation = null
var _full_node: AnimationNodeAnimation = null
var _idle_node: AnimationNodeAnimation = null
## Ação atual, velocidade dela e há quanto tempo começou (s de relógio): para trocar de corpo todo para só tronco.
var _action_name: String = ""
var _action_speed: float = 1.0
var _action_started_ms: int = 0
## Caminho do esqueleto a partir do personagem (raiz da árvore), ex. "Skeleton3D".
var _skeleton_path: String = "Skeleton3D"


## Monta a árvore com [param library] (animações "idle", "run", ações e "flinch"). [param skeleton_path] = caminho
## do esqueleto a partir do personagem (o mesmo das trilhas da biblioteca). Chamar depois de entrar na cena.
func setup(library: AnimationLibrary, skeleton_path: String = "Skeleton3D") -> void:
	_skeleton_path = skeleton_path
	add_animation_library("", library)
	var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	_idle_node = _animation_node("idle")
	tree.add_node("idle", _idle_node)
	tree.add_node("run", _animation_node("run"))
	tree.add_node("run_speed", AnimationNodeTimeScale.new())
	tree.add_node("move", AnimationNodeBlend2.new())
	_action_node = _animation_node("buff")
	tree.add_node("action_anim", _action_node)
	tree.add_node("action_speed", AnimationNodeTimeScale.new())
	tree.add_node("action_seek", AnimationNodeTimeSeek.new())
	tree.add_node("action", _upper_one_shot(0.06, 0.15))
	_full_node = _animation_node("buff")
	tree.add_node("full_anim", _full_node)
	tree.add_node("full_speed", AnimationNodeTimeScale.new())
	var full_shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	full_shot.fadein_time = 0.08
	full_shot.fadeout_time = 0.2
	tree.add_node("action_full", full_shot)
	tree.add_node("flinch_anim", _animation_node("flinch"))
	tree.add_node("flinch", _upper_one_shot(0.03, 0.1))
	tree.connect_node("run_speed", 0, "run")
	tree.connect_node("move", 0, "idle")
	tree.connect_node("move", 1, "run_speed")
	tree.connect_node("action_speed", 0, "action_anim")
	tree.connect_node("action_seek", 0, "action_speed")
	tree.connect_node("action", 0, "move")
	tree.connect_node("action", 1, "action_seek")
	tree.connect_node("full_speed", 0, "full_anim")
	tree.connect_node("action_full", 0, "action")
	tree.connect_node("action_full", 1, "full_speed")
	tree.connect_node("flinch", 0, "action_full")
	tree.connect_node("flinch", 1, "flinch_anim")
	tree.connect_node("output", 0, "flinch")
	tree_root = tree
	root_node = NodePath("..")
	active = true
	set_move_speed(0.0)


## Troca a postura parada (ex.: "idle_sword" com espada). Animação que a biblioteca não tem → "idle".
func set_idle_animation(animation_name: String) -> void:
	if _idle_node == null:
		return
	_idle_node.animation = animation_name if has_animation(animation_name) else "idle"


## Velocidade de movimento como fração da normal (0 = parado, 1 = correndo, 2 = Disparada).
func set_move_speed(ratio: float) -> void:
	var blend: float = clampf(ratio * 2.5, 0.0, 1.0)
	set("parameters/move/blend_amount", blend)
	set("parameters/run_speed/scale", clampf(ratio, 0.6, 2.2))
	# Começou a andar no meio de uma ação de corpo todo: continua só no tronco, do mesmo ponto.
	if blend > MOVING_BLEND and _action_name not in ALWAYS_FULL and bool(get("parameters/action_full/active")):
		var elapsed: float = float(Time.get_ticks_msec() - _action_started_ms) / 1000.0 * _action_speed
		set("parameters/action_full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_fire_upper(_action_name, _action_speed, elapsed)


## Toca a ação [param animation_name] por cima do movimento. Com [param duration] > 0 (s), ajusta a velocidade
## para o momento do golpe cair no fim do lançamento.
func play_action(animation_name: String, duration: float) -> void:
	if _action_node == null or not has_animation(animation_name):
		return
	var hit: float = HIT_TIMES.get(animation_name, 0.0)
	var speed: float = 1.0
	if duration > 0.0 and hit > 0.0:
		speed = clampf(hit / duration, MIN_ACTION_SPEED, MAX_ACTION_SPEED)
	_action_name = animation_name
	_action_speed = speed
	_action_started_ms = Time.get_ticks_msec()
	var full_name: String = animation_name + FULL_SUFFIX
	var moving: bool = float(get("parameters/move/blend_amount")) > MOVING_BLEND
	if (not moving or animation_name in ALWAYS_FULL) and has_animation(full_name):
		set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_full_node.animation = full_name
		set("parameters/full_speed/scale", speed)
		set("parameters/action_full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		set("parameters/action_full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_fire_upper(animation_name, speed, 0.0)


## Dispara a versão só de cima de [param animation_name] a partir de [param from] s (tempo da animação).
func _fire_upper(animation_name: String, speed: float, from: float) -> void:
	_action_node.animation = animation_name
	set("parameters/action_speed/scale", speed)
	set("parameters/action_seek/seek_request", from)
	set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## true enquanto uma ação (ou o recuo ao apanhar) está tocando.
func is_acting() -> bool:
	return bool(get("parameters/action/active")) or bool(get("parameters/action_full/active")) \
		or bool(get("parameters/flinch/active"))


## Interrompe a ação (ex.: o servidor recusou o que foi animado no toque).
func stop_action() -> void:
	set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	set("parameters/action_full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Recuo rápido ao apanhar (só se não estiver no meio de uma ação).
func flinch() -> void:
	if _action_node == null or bool(get("parameters/action/active")) or bool(get("parameters/action_full/active")):
		return
	set("parameters/flinch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _animation_node(animation_name: String) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


## OneShot que só mexe nos ossos de cima (o filtro deixa as pernas com a camada de movimento).
func _upper_one_shot(fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var node: AnimationNodeOneShot = AnimationNodeOneShot.new()
	node.fadein_time = fade_in
	node.fadeout_time = fade_out
	node.filter_enabled = true
	for bone_name: String in UPPER_BONES:
		node.set_filter_path(NodePath("%s:%s" % [_skeleton_path, bone_name]), true)
	return node
