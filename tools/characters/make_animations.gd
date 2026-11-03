extends SceneTree
## Gera a biblioteca de animações de um personagem de verdade ([ART-03]) a partir de:
## - animações do próprio modelo (ex.: "Running" do Mixamo → "run"), com as trilhas apontando para o esqueleto
##   dentro da cena do personagem;
## - as animações do placeholder que o modelo ainda não tem (idle, ataques, magias...), convertidas pelo
##   [SkeletonRetarget] (pose do placeholder → esqueleto do modelo).
## Assim o modelo novo entra no jogo já com todas as ações; cada animação de verdade que chegar substitui a convertida.
##
## Rodar da pasta mmo-client (depois de importar o .glb):
##   godot --headless --path . --script res://tools/characters/make_animations.gd
## Saída: assets/characters/male/male_animations.tres (a cena male_character.tscn usa).

## Personagem: cena, .glb (com o AnimationPlayer das animações próprias) e saída.
const CHARACTER_SCENE: String = "res://assets/characters/male/male_character.tscn"
const MODEL_GLB: String = "res://assets/characters/male/male.glb"
const OUTPUT: String = "res://assets/characters/male/male_animations.tres"
## Animações próprias do modelo: nome no .glb → nome no jogo ([CharacterAnimator]).
const OWN_ANIMATIONS: Dictionary[String, String] = {"Running": "run"}
## Animações próprias que dão a volta (ciclo).
const LOOPED: Array[String] = ["run"]
## Placeholder (referência das poses convertidas).
const REFERENCE_SCENE: String = "res://assets/placeholders/character.tscn"
const REFERENCE_ANIMATIONS: String = "res://assets/placeholders/character_animations.tres"


func _initialize() -> void:
	var character: CharacterModel = (load(CHARACTER_SCENE) as PackedScene).instantiate() as CharacterModel
	var target: Skeleton3D = character.get_node(character.skeleton_path) as Skeleton3D
	var target_path: String = String(character.skeleton_path)
	var reference: CharacterModel = (load(REFERENCE_SCENE) as PackedScene).instantiate() as CharacterModel
	var reference_skeleton: Skeleton3D = reference.get_node(reference.skeleton_path) as Skeleton3D
	var reference_library: AnimationLibrary = load(REFERENCE_ANIMATIONS) as AnimationLibrary

	var library: AnimationLibrary = AnimationLibrary.new()
	var own: Dictionary[String, Animation] = _own_animations(target_path)
	for anim_name: String in own:
		library.add_animation(anim_name, own[anim_name])
		print("própria: %s" % anim_name)
	for anim_name: StringName in reference_library.get_animation_list():
		if library.has_animation(anim_name):
			continue
		var source: Animation = reference_library.get_animation(anim_name)
		library.add_animation(anim_name, SkeletonRetarget.retarget(source, reference_skeleton, String(reference.skeleton_path), target, target_path))
		print("convertida do placeholder: %s" % anim_name)
	var error: Error = ResourceSaver.save(library, OUTPUT)
	print("salvo: %s (%s)" % [OUTPUT, error_string(error)])
	character.free()
	reference.free()
	quit(0 if error == OK else 1)


## Animações do .glb renomeadas para o jogo, com as trilhas apontando para [param target_path]. O quadril fica no
## lugar (sem andar sozinho em X/Z: quem move o personagem é a simulação).
func _own_animations(target_path: String) -> Dictionary[String, Animation]:
	var result: Dictionary[String, Animation] = {}
	var model: Node = (load(MODEL_GLB) as PackedScene).instantiate()
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		model.free()
		return result
	var player: AnimationPlayer = players[0] as AnimationPlayer
	for source_name: String in OWN_ANIMATIONS:
		if not player.has_animation(source_name):
			push_warning("O modelo não tem a animação %s" % source_name)
			continue
		var anim: Animation = player.get_animation(source_name).duplicate(true) as Animation
		for track: int in range(anim.get_track_count() - 1, -1, -1):
			var path: String = String(anim.track_get_path(track))
			var bone: String = path.get_slice(":", 1)
			# Ossos-ponta do Mixamo/Meshy (sem peso na malha) não precisam de trilha.
			if bone.begins_with("mixamorig_") or bone == "headfront":
				anim.remove_track(track)
				continue
			anim.track_set_path(track, NodePath("%s:%s" % [target_path, bone]))
			if bone == "Hips" and anim.track_get_type(track) == Animation.TYPE_POSITION_3D:
				_keep_in_place(anim, track)
		var game_name: String = OWN_ANIMATIONS[source_name]
		anim.loop_mode = Animation.LOOP_LINEAR if game_name in LOOPED else Animation.LOOP_NONE
		result[game_name] = anim
	model.free()
	return result


## Tira o deslocamento em X/Z do quadril (mantém o sobe-e-desce).
func _keep_in_place(anim: Animation, track: int) -> void:
	if anim.track_get_key_count(track) == 0:
		return
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var drift: float = 0.0
	for key: int in range(anim.track_get_key_count(track)):
		var value: Vector3 = anim.track_get_key_value(track, key)
		drift = maxf(drift, Vector2(value.x - first.x, value.z - first.z).length())
		anim.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))
	print("  quadril: deslocamento X/Z removido (máx %.3f m)" % drift)
