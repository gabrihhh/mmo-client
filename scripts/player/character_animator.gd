class_name CharacterAnimator
extends AnimationTree
## Animação do personagem em duas camadas ([JOGO-08], [ART-03]):
## - pernas (corpo todo, por baixo): mistura "idle" ↔ "run" pela velocidade de movimento;
## - tronco e braços (por cima, só os ossos de [constant UPPER_BONES]): uma ação de cada vez (ataque, magia).
## Assim dá para andar lançando. A ação toca na velocidade que faz o momento do golpe ([constant HIT_TIMES])
## cair no fim do lançamento do servidor ([method play_action]).
##
## A árvore é montada em código ([method setup]) com a biblioteca de animações do personagem.

## Ossos da camada de ação (tronco, cabeça e braços). Nomes do perfil humanoide ([ART-03]).
const UPPER_BONES: Array[String] = [
	"Spine", "Chest", "Neck", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
]
## Ossos que só a camada de movimento mexe.
const LOWER_BONES: Array[String] = [
	"Hips", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
]
## Momento do golpe (s, na velocidade normal) de cada ação: é ele que encaixa no fim do lançamento.
## 0 = sem momento certo (toca na velocidade normal). ATENÇÃO: igual às poses de tools/placeholders/make_character.gd.
const HIT_TIMES: Dictionary[String, float] = {
	"attack_sword": 0.45,
	"attack_staff": 0.55,
	"attack_punch": 0.3,
	"heavy_strike": 0.6,
	"cast_forward": 0.55,
	"cast_up": 0.7,
	"spin": 0.35,
	"buff": 0.5,
	"dash": 0.0,
	"flinch": 0.0,
}
## Limites da velocidade da ação (lançamento muito curto/longo não deixa a animação absurda).
const MIN_ACTION_SPEED: float = 0.25
const MAX_ACTION_SPEED: float = 4.0

var _action_node: AnimationNodeAnimation = null


## Monta a árvore com [param library] (animações "idle", "run", ações e "flinch"). Chamar depois de entrar na cena.
func setup(library: AnimationLibrary) -> void:
	add_animation_library("", library)
	var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	tree.add_node("idle", _animation_node("idle"))
	tree.add_node("run", _animation_node("run"))
	tree.add_node("run_speed", AnimationNodeTimeScale.new())
	tree.add_node("move", AnimationNodeBlend2.new())
	_action_node = _animation_node("buff")
	tree.add_node("action_anim", _action_node)
	tree.add_node("action_speed", AnimationNodeTimeScale.new())
	tree.add_node("action", _upper_one_shot(0.06, 0.15))
	tree.add_node("flinch_anim", _animation_node("flinch"))
	tree.add_node("flinch", _upper_one_shot(0.03, 0.1))
	tree.connect_node("run_speed", 0, "run")
	tree.connect_node("move", 0, "idle")
	tree.connect_node("move", 1, "run_speed")
	tree.connect_node("action_speed", 0, "action_anim")
	tree.connect_node("action", 0, "move")
	tree.connect_node("action", 1, "action_speed")
	tree.connect_node("flinch", 0, "action")
	tree.connect_node("flinch", 1, "flinch_anim")
	tree.connect_node("output", 0, "flinch")
	tree_root = tree
	root_node = NodePath("..")
	active = true
	set_move_speed(0.0)


## Velocidade de movimento como fração da normal (0 = parado, 1 = correndo, 2 = Disparada).
func set_move_speed(ratio: float) -> void:
	set("parameters/move/blend_amount", clampf(ratio * 2.5, 0.0, 1.0))
	set("parameters/run_speed/scale", clampf(ratio, 0.6, 2.2))


## Toca a ação [param animation_name] por cima do movimento. Com [param duration] > 0 (s), ajusta a velocidade
## para o momento do golpe cair no fim do lançamento.
func play_action(animation_name: String, duration: float) -> void:
	if _action_node == null or not has_animation(animation_name):
		return
	_action_node.animation = animation_name
	var hit: float = HIT_TIMES.get(animation_name, 0.0)
	var speed: float = 1.0
	if duration > 0.0 and hit > 0.0:
		speed = clampf(hit / duration, MIN_ACTION_SPEED, MAX_ACTION_SPEED)
	set("parameters/action_speed/scale", speed)
	set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Recuo rápido ao apanhar (só se não estiver no meio de uma ação).
func flinch() -> void:
	if _action_node == null or bool(get("parameters/action/active")):
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
		node.set_filter_path(NodePath("Skeleton3D:" + bone_name), true)
	return node
