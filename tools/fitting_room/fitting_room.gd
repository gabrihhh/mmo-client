extends Node3D
## **Provador** (ferramenta de desenvolvimento, fora do pacote do jogo: `tools/*` é excluído na exportação): os dois
## corpos lado a lado vestindo um conjunto inteiro, girando, passando por qualquer animação, em câmera lenta se
## quiser. Serve para o dono e o Claude apontarem juntos o que está ruim (pele/cabelo atravessando a roupa, arma mal
## segurada) antes de publicar ([ART-11]).
##
## Rodar da pasta mmo-client (precisa de tela):
##   godot --path . res://tools/fitting_room/fitting_room.tscn
##
## Controles (botões na tela; atalhos no teclado):
## - Conjunto ◀ ▶ (A / D) — mago, cavaleiro, atirador, assassino, curandeiro, sem roupa.
## - Nível ◀ ▶ (Q / E) — nível de melhoria de todas as peças (0, 1, 5, 10… 70): o brilho de [ItemGlow] ([JOGO-17]).
## - Animação ◀ ▶ (W / S) — parado, correndo e cada ação da biblioteca (ataques, magias), repetindo.
## - Velocidade (1 / 2 / 3 = 100% / 50% / 25%), Pausa (espaço), Girar sozinho (R), Pose T (T: esqueleto em repouso).
## - Arrastar com o mouse gira os dois; roda do mouse aproxima/afasta; F/L/C/O = vista de frente/lado/costas/3‑4.
## - P salva uma foto (user://provador_<n>.png, o caminho aparece embaixo).
## Sem tela para clicar (Claude): `-- --shot=<saida.png> [--kit=N] [--anim=nome] [--view=graus]` tira a foto depois
## de [constant SHOT_DELAY_S] s e fecha (também `--level=N`).

## Conjuntos: nome na tela → o que veste. ATENÇÃO: mesmos itens de tools/placeholders/preview_fit.gd (KITS).
const KITS: Array[Array] = [
	["Mago", {"hand": "arcane_staff", "head": "mage_hat", "chest": "mage_tunic", "feet": "mage_shoes"}],
	["Cavaleiro", {"hand": "knight_sword", "head": "knight_helm", "chest": "knight_plate", "feet": "knight_greaves"}],
	["Atirador", {"hand": "ranger_crossbow", "head": "ranger_hood", "chest": "ranger_jerkin", "feet": "ranger_boots"}],
	["Assassino", {"hand": "assassin_daggers", "head": "assassin_hood", "chest": "assassin_vest", "feet": "assassin_boots"}],
	["Curandeiro", {"hand": "healer_tome", "head": "healer_circlet", "chest": "healer_robe", "feet": "healer_sandals"}],
	["Sem roupa", {}],
]
## Corpos mostrados, da esquerda para a direita, e a distância (m) entre eles.
const BODIES: Array[String] = [Protocol.BODY_MALE, Protocol.BODY_FEMALE]
const SPACING_M: float = 1.3
## Giro automático (graus por segundo) e por px arrastado.
const AUTO_TURN_DPS: float = 30.0
const DRAG_TURN_DEGREES_PER_PX: float = 0.5
## Espera (s) antes da foto automática (`--shot=`).
const SHOT_DELAY_S: float = 2.5
## Câmera: altura do alvo (m), distância inicial e limites (m).
const CAMERA_TARGET_Y: float = 1.0
const CAMERA_DISTANCE_M: float = 4.2
const CAMERA_MIN_M: float = 1.2
const CAMERA_MAX_M: float = 8.0

var _models: Array[CharacterModel] = []
var _looks: Array[PlayerState] = []
var _turntable: Node3D = null
var _camera: Camera3D = null
var _distance: float = CAMERA_DISTANCE_M
var _kit: int = 0
## Níveis de melhoria oferecidos e o escolhido.
const LEVELS: Array[int] = [0, 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70]
var _level: int = 0
var _level_label: Label = null
## Animações oferecidas: "idle", "run" e as ações (nomes base, sem o "_full").
var _animations: Array[String] = []
var _animation: int = 0
var _action_left: float = 0.0
var _auto_turn: bool = true
var _rest_pose: bool = false
var _dragging: bool = false
var _shots: int = 0
var _kit_label: Label = null
var _animation_label: Label = null
var _status_label: Label = null


func _ready() -> void:
	ItemModels.preload_all()
	_build_world()
	_build_ui()
	_collect_animations()
	_apply_kit()
	_apply_animation()
	_auto_shot()


## `--shot=<png>` (com `--kit=N`, `--anim=nome`, `--view=graus` opcionais): foto automática e fecha.
func _auto_shot() -> void:
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			out = arg.trim_prefix("--shot=")
		elif arg.begins_with("--kit="):
			_kit = clampi(int(arg.trim_prefix("--kit=")), 0, KITS.size() - 1)
			_apply_kit()
		elif arg.begins_with("--level="):
			var wanted_level: int = LEVELS.find(int(arg.trim_prefix("--level=")))
			if wanted_level >= 0:
				_level = wanted_level
				_apply_kit()
		elif arg.begins_with("--anim="):
			var wanted: int = _animations.find(arg.trim_prefix("--anim="))
			if wanted >= 0:
				_animation = wanted
				_apply_animation()
		elif arg.begins_with("--view="):
			_view(float(arg.trim_prefix("--view=")))
	if out.is_empty():
		return
	await get_tree().create_timer(SHOT_DELAY_S).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("provador: foto em ", out)
	get_tree().quit()


func _build_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.72, 0.55)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	environment.ambient_light_energy = 0.6
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var back: DirectionalLight3D = DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-20.0, 210.0, 0.0)
	back.light_energy = 0.5
	add_child(back)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor_mesh.mesh = plane
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.42, 0.55, 0.4)
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	_turntable = Node3D.new()
	add_child(_turntable)
	for i: int in range(BODIES.size()):
		var holder: Node3D = Node3D.new()
		holder.position = Vector3((float(i) - (BODIES.size() - 1) / 2.0) * SPACING_M, 0.0, 0.0)
		_turntable.add_child(holder)
		var model: CharacterModel = CharacterBodies.instantiate(BODIES[i])
		holder.add_child(model)
		model.set_shirt_color(Color(0.85, 0.85, 0.85))
		var look: PlayerState = PlayerState.new()
		model.bind_look(look)
		_models.append(model)
		_looks.append(look)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_child(_camera)
	_place_camera()


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	layer.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_kit_label = _row(column, "Conjunto", _change_kit.bind(-1), _change_kit.bind(1))
	_level_label = _row(column, "Nível", _change_level.bind(-1), _change_level.bind(1))
	_animation_label = _row(column, "Animação", _change_animation.bind(-1), _change_animation.bind(1))
	var speeds: HBoxContainer = HBoxContainer.new()
	for pair: Array in [["100%", 1.0], ["50%", 0.5], ["25%", 0.25]]:
		var button: Button = Button.new()
		button.text = pair[0]
		button.pressed.connect(_set_speed.bind(float(pair[1])))
		speeds.add_child(button)
	var pause: Button = Button.new()
	pause.text = "Pausa"
	pause.pressed.connect(_toggle_pause)
	speeds.add_child(pause)
	column.add_child(speeds)
	var toggles: HBoxContainer = HBoxContainer.new()
	var turn: CheckBox = CheckBox.new()
	turn.text = "Girar sozinho"
	turn.button_pressed = _auto_turn
	turn.toggled.connect(func(on: bool) -> void: _auto_turn = on)
	toggles.add_child(turn)
	var rest: CheckBox = CheckBox.new()
	rest.text = "Pose T"
	rest.toggled.connect(func(on: bool) -> void: _rest_pose = on)
	toggles.add_child(rest)
	column.add_child(toggles)
	var views: HBoxContainer = HBoxContainer.new()
	for pair: Array in [["Frente", 0.0], ["Lado", -90.0], ["Costas", 180.0], ["3/4", -45.0]]:
		var button: Button = Button.new()
		button.text = pair[0]
		button.pressed.connect(_view.bind(float(pair[1])))
		views.add_child(button)
	var shot: Button = Button.new()
	shot.text = "Foto"
	shot.pressed.connect(_take_shot)
	views.add_child(shot)
	column.add_child(views)
	_status_label = Label.new()
	_status_label.text = "Arrastar gira · roda aproxima · A/D conjunto · W/S animação · espaço pausa"
	column.add_child(_status_label)


## Linha "Título: [◀] valor [▶]"; devolve o rótulo do valor.
func _row(parent: Container, title: String, previous: Callable, next: Callable) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.text = title + ":"
	caption.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(caption)
	var left: Button = Button.new()
	left.text = "◀"
	left.pressed.connect(previous)
	row.add_child(left)
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(220.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var right: Button = Button.new()
	right.text = "▶"
	right.pressed.connect(next)
	row.add_child(right)
	parent.add_child(row)
	return value


## Animações da biblioteca do primeiro corpo: parado, correndo e as ações (sem as versões "_full" e o "flinch").
func _collect_animations() -> void:
	_animations = ["idle", "run"]
	var library: AnimationLibrary = _models[0].animations
	if library == null:
		return
	var names: Array[String] = []
	for animation_name: StringName in library.get_animation_list():
		var text: String = String(animation_name)
		if text.ends_with(CharacterAnimator.FULL_SUFFIX) or text in ["idle", "run", "flinch", "RESET"] or text.begins_with("idle_"):
			continue
		names.append(text)
	names.sort()
	_animations.append_array(names)


func _change_kit(step: int) -> void:
	_kit = posmod(_kit + step, KITS.size())
	_apply_kit()


func _change_level(step: int) -> void:
	_level = posmod(_level + step, LEVELS.size())
	_apply_kit()


func _apply_kit() -> void:
	var look: Dictionary = KITS[_kit][1]
	var levels: Dictionary = {}
	for slot: String in look:
		levels[slot] = LEVELS[_level]
	for state: PlayerState in _looks:
		state.set_look(look, levels)
	_level_label.text = "+%d" % LEVELS[_level]
	_kit_label.text = String(KITS[_kit][0])
	_action_left = 0.0


func _change_animation(step: int) -> void:
	_animation = posmod(_animation + step, _animations.size())
	_apply_animation()


func _apply_animation() -> void:
	var animation_name: String = _animations[_animation]
	_animation_label.text = animation_name
	for model: CharacterModel in _models:
		model.stop_action()
		model.set_move_speed(1.0 if animation_name == "run" else 0.0)
	_action_left = 0.0


func _process(delta: float) -> void:
	if _auto_turn and not _dragging and not get_tree().paused:
		_turntable.rotation_degrees.y += AUTO_TURN_DPS * delta
	var animation_name: String = _animations[_animation] if not _animations.is_empty() else "idle"
	if animation_name != "idle" and animation_name != "run":
		_action_left -= delta
		if _action_left <= 0.0:
			var library: AnimationLibrary = _models[0].animations
			var length: float = library.get_animation(animation_name).length if library != null and library.has_animation(animation_name) else 1.0
			for model: CharacterModel in _models:
				model.play_action(animation_name, length)
			_action_left = length + 0.4
	if _rest_pose:
		for model: CharacterModel in _models:
			model.skeleton.reset_bone_poses()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(CAMERA_MIN_M, _distance * 0.9)
			_place_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(CAMERA_MAX_M, _distance / 0.9)
			_place_camera()
	elif event is InputEventMouseMotion and _dragging:
		_turntable.rotation_degrees.y += (event as InputEventMouseMotion).relative.x * DRAG_TURN_DEGREES_PER_PX
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_A: _change_kit(-1)
			KEY_D: _change_kit(1)
			KEY_Q: _change_level(-1)
			KEY_E: _change_level(1)
			KEY_W: _change_animation(-1)
			KEY_S: _change_animation(1)
			KEY_SPACE: _toggle_pause()
			KEY_1: _set_speed(1.0)
			KEY_2: _set_speed(0.5)
			KEY_3: _set_speed(0.25)
			KEY_R: _auto_turn = not _auto_turn
			KEY_T: _rest_pose = not _rest_pose
			KEY_F: _view(0.0)
			KEY_L: _view(-90.0)
			KEY_C: _view(180.0)
			KEY_O: _view(-45.0)
			KEY_P: _take_shot()


func _view(degrees: float) -> void:
	_auto_turn = false
	_turntable.rotation_degrees.y = degrees


func _set_speed(scale: float) -> void:
	Engine.time_scale = scale
	_status_label.text = "Velocidade %d%%" % roundi(scale * 100.0)


func _toggle_pause() -> void:
	# Pausa só a animação e o giro (a interface continua respondendo).
	var paused: bool = Engine.time_scale > 0.0
	Engine.time_scale = 0.0 if paused else 1.0
	_status_label.text = "Pausado" if paused else "Velocidade 100%"


func _place_camera() -> void:
	_camera.position = Vector3(0.0, CAMERA_TARGET_Y + _distance * 0.12, _distance)
	_camera.look_at(Vector3(0.0, CAMERA_TARGET_Y, 0.0))


func _take_shot() -> void:
	_shots += 1
	var path: String = "user://provador_%d.png" % _shots
	get_viewport().get_texture().get_image().save_png(path)
	_status_label.text = "Foto: %s" % ProjectSettings.globalize_path(path)
