extends SceneTree
## Foto de conferência do ENCAIXE dos itens no corpo ([ART-02], [MESHY-07]): o mesmo boneco vestido com um conjunto,
## visto de frente, 3/4, lado e costas (parado) e em duas poses de corrida. Serve para ver item menor que o corpo,
## peça flutuando, pele aparecendo dos lados etc.
##
## Rodar da pasta mmo-client (precisa de tela, não roda com --headless):
##   godot --path . --resolution 1800x720 --script res://tools/placeholders/preview_fit.gd -- saida.png <conjunto> <cena do corpo>
## Conjuntos: mago, cavaleiro, atirador, assassino, curandeiro, treino, zumbi, zumbi-besta.
## Ex. de corpo: res://assets/characters/male/male_character.tscn.
## 4º argumento opcional `lancando`: todos no meio de um lançamento (o item de mão flutuante aparece aberto).

## Cada coluna: [animação, instante (s), giro do boneco (graus; 0 = de frente para a câmera)].
const VIEWS: Array[Array] = [
	["idle", 0.0, 0.0], ["idle", 0.0, -45.0], ["idle", 0.0, -90.0], ["idle", 0.0, 180.0],
	["run", 0.0, -30.0], ["run", 0.165, -30.0],
]
const SPACING: float = 0.85
## O que o boneco veste em cada conjunto ([JOGO-03], [JOGO-09]).
const KITS: Dictionary[String, Dictionary] = {
	"treino": {"hand": "training_sword", "head": "training_hood"},
	"mago": {"hand": "arcane_staff", "head": "mage_hat", "chest": "mage_tunic", "feet": "mage_shoes"},
	"cavaleiro": {"hand": "knight_sword", "head": "knight_helm", "chest": "knight_plate", "feet": "knight_greaves"},
	"atirador": {"hand": "ranger_crossbow", "head": "ranger_hood", "chest": "ranger_jerkin", "feet": "ranger_boots"},
	"assassino": {"hand": "assassin_daggers", "head": "assassin_hood", "chest": "assassin_vest", "feet": "assassin_boots"},
	"curandeiro": {"hand": "healer_tome", "head": "healer_circlet", "chest": "healer_robe", "feet": "healer_sandals"},
	# Zumbis ([JOGO-13]): só a arma na mão (corpo res://assets/characters/zombie/zombie_character.tscn).
	"zumbi": {"hand": "knight_sword"},
	"zumbi-besta": {"hand": "ranger_crossbow"},
}

var _frames: int = 0
var _output: String = ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
	if _frames < 8:
		return false
	var image: Image = get_root().get_texture().get_image()
	image.save_png(_output)
	print("prévia: %s" % _output)
	return true


func _build() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output = args[0] if args.size() > 0 else "user://preview_fit.png"
	var kit: String = args[1] if args.size() > 1 else "mago"
	var scene_path: String = args[2] if args.size() > 2 else "res://assets/characters/male/male_character.tscn"
	var world: Node3D = Node3D.new()
	get_root().add_child(world)
	_add_environment(world)

	var look: PlayerState = PlayerState.new()
	look.set_look(KITS.get(kit, KITS["mago"]))
	for i: int in range(VIEWS.size()):
		var model: CharacterModel = (load(scene_path) as PackedScene).instantiate() as CharacterModel
		model.position = Vector3((float(i) - float(VIEWS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		# A cena do personagem olha para +Z (para a câmera); no jogo o Body dos jogadores gira 180°.
		model.rotation.y = deg_to_rad(float(VIEWS[i][2]))
		world.add_child(model)
		model.bind_look(look)
		model.set_shirt_color(Color(0.25, 0.5, 1.0))
		(model.get_node("Animator") as AnimationTree).active = false
		var player: AnimationPlayer = AnimationPlayer.new()
		model.add_child(player)
		player.root_node = NodePath("..")
		player.add_animation_library("", model.animations if model.animations != null else load(CharacterModel.ANIMATIONS_PATH) as AnimationLibrary)
		player.play(String(VIEWS[i][0]))
		player.seek(float(VIEWS[i][1]), true)
		player.pause()
		if args.size() > 3 and args[3] == "lancando":
			model.play_ability("", 60.0)

	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(0.0, 1.2, 5.6), Vector3(0.0, 0.95, 0.0))


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.75, 0.55)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	world.add_child(sun)
