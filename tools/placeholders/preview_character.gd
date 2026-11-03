extends SceneTree
## Foto de conferência do personagem placeholder ([ART-03]): o boneco em várias poses lado a lado, com itens.
##
## Rodar da pasta mmo-client (precisa de tela, não roda com --headless):
##   godot --path . --script res://tools/placeholders/preview_character.gd -- /caminho/saida.png [espada|cajado]
##
## Cada coluna é uma animação parada num instante (nome: tempo em s). Útil para ver proporção, pegada da arma
## e poses depois de mexer em make_character.gd.

const CHARACTER: String = "res://assets/placeholders/character.tscn"
const ANIMATIONS: String = "res://assets/placeholders/character_animations.tres"
## Animação e instante (s) de cada coluna.
const POSES: Array[Array] = [
	["idle", 0.0], ["run", 0.0], ["run", 0.165], ["attack_sword", 0.3], ["attack_sword", 0.45],
	["attack_staff", 0.55], ["cast_forward", 0.55], ["cast_up", 0.4], ["spin", 0.25], ["buff", 0.5],
]
const SPACING: float = 1.1

var _frames: int = 0
var _output: String = ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()  # no _initialize a árvore ainda não roda o _ready dos nós
	if _frames < 8:
		return false
	var image: Image = get_root().get_texture().get_image()
	image.save_png(_output)
	print("prévia: %s" % _output)
	return true


func _build() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output = args[0] if args.size() > 0 else "user://preview_character.png"
	var weapon: String = "training_staff" if args.size() > 1 and args[1] == "cajado" else "training_sword"
	var world: Node3D = Node3D.new()
	get_root().add_child(world)
	_add_environment(world)

	var library: AnimationLibrary = load(ANIMATIONS) as AnimationLibrary
	var look: PlayerState = PlayerState.new()
	look.set_look({"hand": weapon, "head": "training_hood"})
	for i: int in range(POSES.size()):
		var model: CharacterModel = (load(CHARACTER) as PackedScene).instantiate() as CharacterModel
		model.position = Vector3((float(i) - float(POSES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		model.rotation.y = deg_to_rad(-25.0)  # 3/4 de frente
		world.add_child(model)
		model.bind_look(look)
		model.set_shirt_color(Color(0.25, 0.5, 1.0))
		(model.get_node("Animator") as AnimationTree).active = false
		var player: AnimationPlayer = AnimationPlayer.new()
		model.add_child(player)
		player.root_node = NodePath("..")
		player.add_animation_library("", library)
		var pose_name: String = POSES[i][0]
		var pose_time: float = POSES[i][1]
		player.play(pose_name)
		player.seek(pose_time, true)
		player.pause()
		var label: Label3D = Label3D.new()
		label.text = "%s\n%.2f s" % [pose_name, pose_time]
		label.font_size = 28
		label.pixel_size = 0.004
		label.position = model.position + Vector3(0.0, 2.05, 0.0)
		world.add_child(label)

	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.fov = 32.0
	camera.look_at_from_position(Vector3(0.0, 2.0, 9.5), Vector3(0.0, 1.0, 0.0))


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.75, 0.55)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	world.add_child(sun)
