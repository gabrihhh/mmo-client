extends SceneTree
## Gera o personagem placeholder ([ART-03]): esqueleto humanoide, malha low poly ligada aos ossos e as animações.
##
## Rodar da pasta mmo-client:
##   godot --headless --path . --script res://tools/placeholders/make_character.gd
##
## Saídas (em assets/placeholders/):
## - character.tscn: Skeleton3D + malha (script CharacterModel na raiz). É o que o jogo usa.
## - character_animations.tres: AnimationLibrary com parado, correr e as ações ([JOGO-08]).
## - tools/placeholders/reference/character.glb: cópia para abrir no Blender/Nomad (tamanho, nomes de ossos e
##   animações). Fica numa pasta com .gdignore: não entra no jogo.
##
## Convenções ([ART-02], [ART-03]): metros; Y para cima; o modelo olha para +Z (lado direito dele = −X);
## pés em y = 0; altura 1,8 m. Ossos com os nomes do perfil humanoide do Godot (SkeletonProfileHumanoid) e
## rotação de descanso zero: girar em X leva o braço para a frente (negativo) ou para trás (positivo).

const OUTPUT_DIR: String = "res://assets/placeholders"
const MODEL_SCRIPT: String = "res://scripts/player/character_model.gd"
const REFERENCE_GLB: String = "res://tools/placeholders/reference/character.glb"

const _SHIRT: Color = Color(0.85, 0.85, 0.85) # neutra: o jogo pinta por cima (azul = você, vermelho = outros)
const _SKIN: Color = Color(0.93, 0.76, 0.6)
const _PANTS: Color = Color(0.3, 0.27, 0.25)
const _SHOES: Color = Color(0.25, 0.17, 0.1)
const _HAIR: Color = Color(0.32, 0.2, 0.12)
const _BELT: Color = Color(0.45, 0.3, 0.15)
const _EYES: Color = Color(0.08, 0.08, 0.1)

## Ossos do tronco e braços (camada de ação) e das pernas (camada de movimento): os mesmos do CharacterAnimator.
const UPPER_BONES: Array[String] = CharacterAnimator.UPPER_BONES
const LOWER_BONES: Array[String] = CharacterAnimator.LOWER_BONES
## Altura do quadril (m) no descanso.
const HIPS_Y: float = 0.95

## Posição (m, espaço do modelo) do início de cada osso.
var _heads: Dictionary[String, Vector3] = {}


func _initialize() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Character"
	var skeleton: Skeleton3D = _make_skeleton()
	root.add_child(skeleton)
	skeleton.owner = root
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _make_mesh(skeleton)
	skeleton.add_child(body)
	body.owner = root
	body.skeleton = NodePath("..")

	var library: AnimationLibrary = _make_animations()
	var failed: bool = false
	failed = ResourceSaver.save(library, OUTPUT_DIR + "/character_animations.tres") != OK or failed

	# Referência para o Blender: com as animações num AnimationPlayer (o glTF leva junto).
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", library)
	root.add_child(player)
	player.owner = root
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if document.append_from_scene(root, state) != OK or document.write_to_filesystem(state, REFERENCE_GLB) != OK:
		push_warning("character.glb (referência) não foi gerado")
	root.remove_child(player)
	player.free()

	# Cena do jogo: sem AnimationPlayer (o CharacterModel monta a árvore de animação com a biblioteca).
	root.set_script(load(MODEL_SCRIPT))
	var scene: PackedScene = PackedScene.new()
	failed = scene.pack(root) != OK or failed
	failed = ResourceSaver.save(scene, OUTPUT_DIR + "/character.tscn") != OK or failed
	root.free()
	print("personagem: %s" % ("FALHOU" if failed else "ok"))
	quit(1 if failed else 0)


func _make_skeleton() -> Skeleton3D:
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	_bone(skeleton, "Hips", "", Vector3(0.0, HIPS_Y, 0.0))
	_bone(skeleton, "Spine", "Hips", Vector3(0.0, 1.0, 0.0))
	_bone(skeleton, "Chest", "Spine", Vector3(0.0, 1.16, 0.0))
	_bone(skeleton, "Neck", "Chest", Vector3(0.0, 1.44, 0.0))
	_bone(skeleton, "Head", "Neck", Vector3(0.0, 1.53, 0.0))
	for side: String in ["Right", "Left"]:
		var x: float = -1.0 if side == "Right" else 1.0
		_bone(skeleton, side + "UpperArm", "Chest", Vector3(0.25 * x, 1.42, 0.0))
		_bone(skeleton, side + "LowerArm", side + "UpperArm", Vector3(0.25 * x, 1.15, 0.0))
		_bone(skeleton, side + "Hand", side + "LowerArm", Vector3(0.25 * x, 0.9, 0.0))
		_bone(skeleton, side + "UpperLeg", "Hips", Vector3(0.1 * x, 0.92, 0.0))
		_bone(skeleton, side + "LowerLeg", side + "UpperLeg", Vector3(0.1 * x, 0.5, 0.0))
		_bone(skeleton, side + "Foot", side + "LowerLeg", Vector3(0.1 * x, 0.1, 0.0))
	skeleton.reset_bone_poses()
	return skeleton


func _bone(skeleton: Skeleton3D, bone_name: String, parent: String, head: Vector3) -> void:
	var index: int = skeleton.add_bone(bone_name)
	var parent_head: Vector3 = Vector3.ZERO
	if not parent.is_empty():
		skeleton.set_bone_parent(index, skeleton.find_bone(parent))
		parent_head = _heads[parent]
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, head - parent_head))
	_heads[bone_name] = head


## Corpo low poly: cada peça segue um osso. A camisa vem primeiro (superfície 0: o jogo troca a cor dela).
func _make_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var b: LowPolyBuilder = LowPolyBuilder.new()
	var flat: Vector2 = Vector2(1.0, 0.62) # tronco mais largo que fundo

	b.bone = skeleton.find_bone("Spine")
	b.prism(8, 0.15, 0.17, 0.99, 1.17, _SHIRT, flat)                      # barriga
	b.bone = skeleton.find_bone("Chest")
	b.prism(8, 0.17, 0.2, 1.16, 1.39, _SHIRT, flat)                       # peito
	b.prism(8, 0.2, 0.11, 1.39, 1.47, _SHIRT, flat)                       # ombros
	for side: String in ["Right", "Left"]:
		var x: float = -0.25 if side == "Right" else 0.25
		b.bone = skeleton.find_bone(side + "UpperArm")
		b.prism(6, 0.05, 0.062, 1.14, 1.45, _SHIRT, Vector2.ONE, Vector3(x, 0.0, 0.0))  # manga
		b.bone = skeleton.find_bone(side + "LowerArm")
		b.prism(6, 0.04, 0.048, 0.9, 1.16, _SKIN, Vector2.ONE, Vector3(x, 0.0, 0.0))   # antebraço
		b.bone = skeleton.find_bone(side + "Hand")
		b.box(Vector3(x, 0.85, 0.01), Vector3(0.07, 0.1, 0.085), _SKIN)                 # mão
		var leg_x: float = -0.1 if side == "Right" else 0.1
		b.bone = skeleton.find_bone(side + "UpperLeg")
		b.prism(6, 0.065, 0.085, 0.5, 0.93, _PANTS, Vector2.ONE, Vector3(leg_x, 0.0, 0.0))  # coxa
		b.bone = skeleton.find_bone(side + "LowerLeg")
		b.prism(6, 0.05, 0.065, 0.1, 0.51, _PANTS, Vector2.ONE, Vector3(leg_x, 0.0, 0.0))   # canela
		b.bone = skeleton.find_bone(side + "Foot")
		b.box(Vector3(leg_x, 0.05, 0.035), Vector3(0.1, 0.1, 0.24), _SHOES)                # pé (ponta em +Z)

	b.bone = skeleton.find_bone("Hips")
	b.box(Vector3(0.0, 0.93, 0.0), Vector3(0.3, 0.15, 0.185), _PANTS)     # quadril
	b.box(Vector3(0.0, 1.0, 0.0), Vector3(0.31, 0.04, 0.195), _BELT)      # cinto
	b.bone = skeleton.find_bone("Neck")
	b.prism(6, 0.05, 0.05, 1.44, 1.56, _SKIN)                             # pescoço
	b.bone = skeleton.find_bone("Head")
	b.prism(8, 0.085, 0.11, 1.53, 1.65, _SKIN)                            # queixo
	b.prism(8, 0.11, 0.08, 1.65, 1.77, _SKIN)                             # crânio
	b.prism(8, 0.117, 0.07, 1.67, 1.8, _HAIR, Vector2.ONE, Vector3(0.0, 0.0, -0.012))  # cabelo
	b.box(Vector3(0.0, 1.62, 0.11), Vector3(0.03, 0.045, 0.03), _SKIN)    # nariz
	for x: float in [-0.042, 0.042]:
		b.box(Vector3(x, 1.655, 0.1), Vector3(0.03, 0.035, 0.025), _EYES)  # olhos (mostram para onde ele olha)
	print("personagem: %d triângulos" % b.triangle_count())
	return b.build()


# --- Animações ---------------------------------------------------------------------------------------------
# Graus em (X, Y, Z). Braço/perna: X negativo = para a frente. Tronco: X positivo = inclina para a frente.
# Braço direito: Z negativo = abre para o lado (o esquerdo é Z positivo). Tronco: Y negativo = gira para a direita.
# O "momento do golpe" (hit) de cada ação fica em CharacterAnimator.HIT_TIMES: mudou aqui, mude lá.

func _make_animations() -> AnimationLibrary:
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("idle", _idle())
	library.add_animation("run", _run())
	library.add_animation("attack_sword", _action(0.8, {
		0.3: {"RightUpperArm": Vector3(-150, 0, -20), "RightLowerArm": Vector3(-60, 0, 0), "RightHand": Vector3(-20, 0, 0), "Spine": Vector3(0, -25, 0), "Chest": Vector3(-5, 0, 0)},
		0.45: {"RightUpperArm": Vector3(-40, 0, -10), "RightLowerArm": Vector3(-10, 0, 0), "RightHand": Vector3(50, 0, 0), "Spine": Vector3(0, 20, 0), "Chest": Vector3(12, 0, 0)},
		0.6: {"RightUpperArm": Vector3(10, 0, 0), "RightLowerArm": Vector3(-20, 0, 0), "RightHand": Vector3(40, 0, 0), "Spine": Vector3(0, 25, 0), "Chest": Vector3(8, 0, 0)},
	}))
	library.add_animation("attack_staff", _action(0.9, {
		0.35: {"RightUpperArm": Vector3(-100, 0, 0), "RightLowerArm": Vector3(-40, 0, 0), "RightHand": Vector3(100, 0, 0), "LeftUpperArm": Vector3(-40, 0, 0), "Chest": Vector3(-8, 0, 0)},
		0.55: {"RightUpperArm": Vector3(-85, 0, 0), "RightLowerArm": Vector3(0, 0, 0), "RightHand": Vector3(85, 0, 0), "LeftUpperArm": Vector3(-20, 0, 0), "Chest": Vector3(10, 0, 0), "Spine": Vector3(0, -10, 0)},
		0.75: {"RightUpperArm": Vector3(-80, 0, 0), "RightLowerArm": Vector3(-10, 0, 0), "RightHand": Vector3(85, 0, 0), "Chest": Vector3(6, 0, 0)},
	}))
	library.add_animation("attack_punch", _action(0.6, {
		0.15: {"RightUpperArm": Vector3(-30, 0, -10), "RightLowerArm": Vector3(-110, 0, 0), "LeftUpperArm": Vector3(-30, 0, 0), "LeftLowerArm": Vector3(-100, 0, 0), "Spine": Vector3(0, -20, 0)},
		0.3: {"RightUpperArm": Vector3(-85, 0, 0), "RightLowerArm": Vector3(-5, 0, 0), "LeftUpperArm": Vector3(-30, 0, 0), "LeftLowerArm": Vector3(-100, 0, 0), "Spine": Vector3(0, 20, 0), "Chest": Vector3(8, 0, 0)},
		0.45: {"RightUpperArm": Vector3(-40, 0, 0), "RightLowerArm": Vector3(-70, 0, 0), "LeftUpperArm": Vector3(-30, 0, 0), "LeftLowerArm": Vector3(-100, 0, 0)},
	}))
	library.add_animation("heavy_strike", _action(0.9, {
		0.35: {"RightUpperArm": Vector3(-175, 0, 0), "LeftUpperArm": Vector3(-160, 0, 0), "RightLowerArm": Vector3(-40, 0, 0), "LeftLowerArm": Vector3(-40, 0, 0), "Chest": Vector3(-15, 0, 0)},
		0.6: {"RightUpperArm": Vector3(-50, 0, 0), "LeftUpperArm": Vector3(-50, 0, 0), "RightHand": Vector3(50, 0, 0), "Chest": Vector3(25, 0, 0), "Spine": Vector3(15, 0, 0)},
		0.75: {"RightUpperArm": Vector3(-45, 0, 0), "LeftUpperArm": Vector3(-45, 0, 0), "RightHand": Vector3(45, 0, 0), "Chest": Vector3(20, 0, 0), "Spine": Vector3(12, 0, 0)},
	}))
	library.add_animation("cast_forward", _action(0.9, {
		0.3: {"RightUpperArm": Vector3(-40, 0, 10), "LeftUpperArm": Vector3(-40, 0, -10), "RightLowerArm": Vector3(-100, 0, 0), "LeftLowerArm": Vector3(-100, 0, 0), "Chest": Vector3(-8, 0, 0)},
		0.55: {"RightUpperArm": Vector3(-90, 0, 0), "LeftUpperArm": Vector3(-90, 0, 0), "Chest": Vector3(10, 0, 0)},
		0.7: {"RightUpperArm": Vector3(-85, 0, 0), "LeftUpperArm": Vector3(-85, 0, 0), "Chest": Vector3(8, 0, 0)},
	}))
	library.add_animation("cast_up", _action(1.0, {
		0.4: {"RightUpperArm": Vector3(-170, 0, 0), "LeftUpperArm": Vector3(-170, 0, 0), "RightLowerArm": Vector3(-10, 0, 0), "LeftLowerArm": Vector3(-10, 0, 0), "Chest": Vector3(-15, 0, 0), "Head": Vector3(-15, 0, 0)},
		0.7: {"RightUpperArm": Vector3(-60, 0, 0), "LeftUpperArm": Vector3(-60, 0, 0), "Chest": Vector3(20, 0, 0), "Spine": Vector3(10, 0, 0)},
		0.85: {"RightUpperArm": Vector3(-55, 0, 0), "LeftUpperArm": Vector3(-55, 0, 0), "Chest": Vector3(15, 0, 0), "Spine": Vector3(8, 0, 0)},
	}))
	var arms_out: Dictionary = {"RightUpperArm": Vector3(0, 0, -80), "LeftUpperArm": Vector3(0, 0, 80)}
	library.add_animation("spin", _action(0.6, {
		0.05: _with(arms_out, {"Spine": Vector3(0, 0, 0)}),
		0.15: _with(arms_out, {"Spine": Vector3(0, -90, 0)}),
		0.25: _with(arms_out, {"Spine": Vector3(0, -180, 0)}),
		0.35: _with(arms_out, {"Spine": Vector3(0, -270, 0)}),
		0.45: _with(arms_out, {"Spine": Vector3(0, -360, 0)}),
	}))
	library.add_animation("buff", _action(0.8, {
		0.5: {"RightUpperArm": Vector3(-30, 0, -60), "LeftUpperArm": Vector3(-30, 0, 60), "RightLowerArm": Vector3(-40, 0, 0), "LeftLowerArm": Vector3(-40, 0, 0), "Chest": Vector3(-10, 0, 0), "Head": Vector3(-15, 0, 0)},
		0.65: {"RightUpperArm": Vector3(-25, 0, -50), "LeftUpperArm": Vector3(-25, 0, 50), "RightLowerArm": Vector3(-35, 0, 0), "LeftLowerArm": Vector3(-35, 0, 0), "Chest": Vector3(-6, 0, 0)},
	}))
	library.add_animation("dash", _action(0.45, {
		0.08: {"Spine": Vector3(25, 0, 0), "RightUpperArm": Vector3(-70, 0, 0), "LeftUpperArm": Vector3(40, 0, 0)},
		0.3: {"Spine": Vector3(20, 0, 0), "RightUpperArm": Vector3(-60, 0, 0), "LeftUpperArm": Vector3(30, 0, 0)},
	}))
	library.add_animation("flinch", _action(0.35, {
		0.08: {"Chest": Vector3(-15, 0, 0), "Head": Vector3(-10, 0, 0), "Spine": Vector3(0, 10, 0)},
	}))
	return library


## Pose de descanso dos braços com a mão da arma um pouco dobrada (segurando o item).
func _rest_arms() -> Dictionary:
	return {"RightUpperArm": Vector3(-8, 0, -6), "RightLowerArm": Vector3(-25, 0, 0), "RightHand": Vector3(60, 0, 0),
		"LeftUpperArm": Vector3(0, 0, 6), "LeftLowerArm": Vector3(-10, 0, 0)}


## Parado (loop de 2 s): respiração leve.
func _idle() -> Animation:
	var anim: Animation = _new_animation(2.0, true)
	var bones: Array[String] = UPPER_BONES + LOWER_BONES
	_pose(anim, 0.0, bones, _rest_arms(), HIPS_Y)
	_pose(anim, 1.0, bones, _with(_rest_arms(), {"Chest": Vector3(3, 0, 0), "Head": Vector3(-2, 0, 0), "RightUpperArm": Vector3(-11, 0, -7)}), HIPS_Y - 0.008)
	_pose(anim, 2.0, bones, _rest_arms(), HIPS_Y)
	return anim


## Correr (loop de 0,66 s, ciclo de 2 passos a 5 m/s): pernas e braços alternados, tronco inclinado.
func _run() -> Animation:
	var anim: Animation = _new_animation(0.66, true)
	var bones: Array[String] = UPPER_BONES + LOWER_BONES
	var lean: Dictionary = {"Spine": Vector3(10, 0, 0), "Head": Vector3(-8, 0, 0)}
	for half: int in range(2):
		var front: String = "Right" if half == 0 else "Left"
		var back: String = "Left" if half == 0 else "Right"
		var t: float = 0.33 * half
		var contact: Dictionary = _with(lean, {
			front + "UpperLeg": Vector3(-40, 0, 0), front + "LowerLeg": Vector3(10, 0, 0),
			back + "UpperLeg": Vector3(35, 0, 0), back + "LowerLeg": Vector3(45, 0, 0),
			front + "UpperArm": Vector3(30, 0, 0), back + "UpperArm": Vector3(-35, 0, 0),
			"RightLowerArm": Vector3(-50, 0, 0), "LeftLowerArm": Vector3(-50, 0, 0),
			"Spine": Vector3(10, 8.0 if half == 0 else -8.0, 0),
		})
		var passing: Dictionary = _with(lean, {
			front + "UpperLeg": Vector3(-5, 0, 0), front + "LowerLeg": Vector3(5, 0, 0),
			back + "UpperLeg": Vector3(-25, 0, 0), back + "LowerLeg": Vector3(85, 0, 0),
			"RightLowerArm": Vector3(-50, 0, 0), "LeftLowerArm": Vector3(-50, 0, 0),
		})
		_pose(anim, t, bones, contact, HIPS_Y - 0.03)
		_pose(anim, t + 0.165, bones, passing, HIPS_Y + 0.02)
	_pose(anim, 0.66, bones, _with(lean, {
		"RightUpperLeg": Vector3(-40, 0, 0), "RightLowerLeg": Vector3(10, 0, 0),
		"LeftUpperLeg": Vector3(35, 0, 0), "LeftLowerLeg": Vector3(45, 0, 0),
		"RightUpperArm": Vector3(30, 0, 0), "LeftUpperArm": Vector3(-35, 0, 0),
		"RightLowerArm": Vector3(-50, 0, 0), "LeftLowerArm": Vector3(-50, 0, 0), "Spine": Vector3(10, 8, 0),
	}), HIPS_Y - 0.03)
	return anim


## Ação de tronco/braços: começa e termina no descanso; [param keys] = tempo (s) → pose.
func _action(length: float, keys: Dictionary) -> Animation:
	var anim: Animation = _new_animation(length, false)
	_pose(anim, 0.0, UPPER_BONES, _rest_arms())
	for time: float in keys:
		var pose: Dictionary = keys[time]
		_pose(anim, time, UPPER_BONES, pose)
	_pose(anim, length, UPPER_BONES, _rest_arms())
	return anim


func _new_animation(length: float, loop: bool) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return anim


## Chave de rotação em [param time] para cada osso de [param bones] (o que não estiver em [param rotations] volta
## ao descanso). [param hips_y] (m) também move o quadril (sobe/desce ao correr); NAN = não mexe.
func _pose(anim: Animation, time: float, bones: Array[String], rotations: Dictionary, hips_y: float = NAN) -> void:
	for bone_name: String in bones:
		var degrees: Vector3 = rotations.get(bone_name, Vector3.ZERO)
		var radians: Vector3 = Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
		var track: int = _track(anim, Animation.TYPE_ROTATION_3D, bone_name)
		anim.rotation_track_insert_key(track, time, Quaternion.from_euler(radians))
	if not is_nan(hips_y):
		var hips: int = _track(anim, Animation.TYPE_POSITION_3D, "Hips")
		anim.position_track_insert_key(hips, time, Vector3(0.0, hips_y, 0.0))


func _track(anim: Animation, type: Animation.TrackType, bone_name: String) -> int:
	var path: NodePath = NodePath("Skeleton3D:" + bone_name)
	var index: int = anim.find_track(path, type)
	if index >= 0:
		return index
	index = anim.add_track(type)
	anim.track_set_path(index, path)
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	return index


## Cópia de [param base] com [param extra] por cima.
func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate()
	result.merge(extra, true)
	return result
