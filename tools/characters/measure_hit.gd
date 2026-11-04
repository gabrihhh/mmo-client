extends SceneTree
## Mede o "momento do golpe" de uma ação ([ART-06]): toca a animação já gerada (biblioteca do corpo, depois de
## rodar make_animations.gd) quadro a quadro e imprime a velocidade e a posição da mão direita.
## O golpe é o quadro em que a mão está **mais à frente descendo**, logo depois do pico de velocidade; esse tempo
## vai em [constant CharacterAnimator.HIT_TIMES].
##
## Rodar da pasta mmo-client (o corpo é "male" ou "female"; o nome é o da biblioteca, de preferência "<ação>_full"):
##   godot --headless --path . --script res://tools/characters/measure_hit.gd -- male attack_greatsword_full
##
## Precisa da árvore rodando (a pose do esqueleto só atualiza entre quadros): por isso mede em process_frame.

## Quadros por segundo da medição (mesma taxa das animações, make_animations.gd BAKE_FPS).
const FPS: float = 30.0

var _player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _animation: Animation = null
var _animation_name: String = ""
var _hand: int = -1
var _time: float = -1.0
var _previous: Vector3 = Vector3.ZERO
var _peak_speed: float = 0.0
var _peak_time: float = 0.0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <male|female> <animação>")
		quit(1)
		return
	var body: String = args[0]
	_animation_name = args[1]
	var scene: Node3D = (load("res://assets/characters/%s/%s_character.tscn" % [body, body]) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var library: AnimationLibrary = load("res://assets/characters/%s/%s_animations.tres" % [body, body]) as AnimationLibrary
	if not library.has_animation(_animation_name):
		push_error("animação %s não existe em %s_animations.tres" % [_animation_name, body])
		quit(1)
		return
	_animation = library.get_animation(_animation_name)
	_player = AnimationPlayer.new()
	scene.add_child(_player)
	_player.root_node = _player.get_path_to(scene)
	_player.add_animation_library("m", library)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skeleton = scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hand = _skeleton.find_bone("RightHand")
	process_frame.connect(_tick)
	print("tempo  velocidade  altura  frente   (mão direita, espaço do personagem; frente = +Z)")


func _tick() -> void:
	if _time < 0.0:
		_player.play("m/" + _animation_name)
		_player.seek(0.0, true)
		_time = 0.0
		_previous = _skeleton.get_bone_global_pose(_hand).origin
		return
	_time += 1.0 / FPS
	if _time > _animation.length + 0.001:
		print("pico de velocidade: %.2f m/s em %.3f s (o golpe costuma ser 1 ou 2 quadros depois)" % [_peak_speed, _peak_time])
		quit()
		return
	_player.seek(_time, true)
	var hand: Vector3 = _skeleton.get_bone_global_pose(_hand).origin
	var speed: float = (hand - _previous).length() * FPS
	if speed > _peak_speed:
		_peak_speed = speed
		_peak_time = _time
	print("%.3f  %5.2f m/s  %5.2f  %5.2f  %s" % [_time, speed, hand.y, hand.z, "#".repeat(int(speed * 4.0))])
	_previous = hand
