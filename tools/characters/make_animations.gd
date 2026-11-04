extends SceneTree
## Gera a biblioteca de animações de um personagem de verdade ([ART-03]) a partir de:
## - animações de verdade em arquivos .glb (as do próprio modelo, ex.: "Running" → "run", e as geradas à parte no
##   Meshy, ex.: "Idle" → "idle"), com as trilhas apontando para o esqueleto dentro da cena do personagem;
## - as animações do placeholder que ainda faltam (ataques, magias...), convertidas pelo [SkeletonRetarget]
##   (pose do placeholder → esqueleto do modelo).
## Assim o modelo novo entra no jogo já com todas as ações; cada animação de verdade que chegar substitui a convertida.
##
## Rodar da pasta mmo-client (depois de importar os .glb):
##   godot --headless --path . --script res://tools/characters/make_animations.gd
## Gera a biblioteca de TODOS os personagens de [constant CHARACTERS] (a cena de cada um usa a sua).
##
## Fontes de animação de fora do modelo (pasta tools/characters/animations, não vai no jogo) precisam importar com o
## mesmo mapa de ossos (mixamo_bone_map.tres) para os nomes dos ossos baterem; ver tools/characters/meshy_anim_source.py.

## Clipes de ação do Meshy (mesmos nomes nos dois corpos): nome no .glb → [nome no jogo, início (s), fim (s)].
## Cada clipe é cortado no trecho útil (sem preparação parada nem recuperação longa); o momento do golpe dentro do
## trecho cortado está em [constant CharacterAnimator.HIT_TIMES] (medido pelo pico de velocidade da mão).
const MESHY_ACTIONS: Dictionary[String, Array] = {
	"Right_Hand_Sword_Slash": ["attack_sword", 0.0, 1.3],
	"Heavy_Hammer_Swing": ["heavy_strike", 0.3, 1.83],
	"Axe_Spin_Attack": ["spin", 0.0, 1.5],
	"mage_soell_cast_7": ["attack_staff", 0.3, 1.4],
	"mage_soell_cast_3": ["cast_forward", 0.0, 1.5],
	"Charged_Spell_Cast": ["cast_up", 0.3, 2.4],
	"mage_soell_cast": ["buff", 0.0, 1.5],
	"Right_Jab_from_Guard": ["attack_punch", 0.2, 1.2],
	"Stand_Dodge_3": ["dash", 0.9, 2.7],
	"Hit_Reaction": ["flinch", 0.0, 1.0],
}
## Clipe inteiro (sem corte): fim negativo.
const WHOLE: float = -1.0
## Personagens: cena, biblioteca gerada e fontes ("glb" → {nome do clipe no .glb → [nome no jogo, início, fim]}).
## Se duas fontes dão o mesmo nome no jogo, vale a primeira.
const CHARACTERS: Array[Dictionary] = [
	{
		"scene": "res://assets/characters/male/male_character.tscn",
		"output": "res://assets/characters/male/male_animations.tres",
		"sources": {
			"res://assets/characters/male/male.glb": {"Running": ["run", 0.0, WHOLE]},
			"res://tools/characters/animations/male_idle.glb": {"Idle": ["idle", 0.0, WHOLE]},
			"res://tools/characters/animations/male_combat.glb": MESHY_ACTIONS,
		},
	},
	{
		"scene": "res://assets/characters/female/female_character.tscn",
		"output": "res://assets/characters/female/female_animations.tres",
		"sources": {
			"res://assets/characters/female/female.glb": {"Running": ["run", 0.0, WHOLE]},
			"res://tools/characters/animations/female_idle.glb": {"Idle": ["idle", 0.0, WHOLE]},
			"res://tools/characters/animations/female_combat.glb": MESHY_ACTIONS,
		},
	},
]
## Animações de verdade que dão a volta (ciclo).
const LOOPED: Array[String] = ["run", "idle"]
## Osso raiz (o único com trilha de posição que importa).
const HIPS: StringName = &"Hips"
## Placeholder (referência das poses convertidas).
const REFERENCE_SCENE: String = "res://assets/placeholders/character.tscn"
const REFERENCE_ANIMATIONS: String = "res://assets/placeholders/character_animations.tres"


func _initialize() -> void:
	var failed: bool = false
	for entry: Dictionary in CHARACTERS:
		print("== %s" % entry["scene"])
		failed = _make(entry["scene"], entry["sources"], entry["output"]) != OK or failed
	quit(1 if failed else 0)


## Gera e salva a biblioteca de um personagem.
func _make(scene_path: String, sources: Dictionary, output: String) -> Error:
	var character: CharacterModel = (load(scene_path) as PackedScene).instantiate() as CharacterModel
	var target: Skeleton3D = character.get_node(character.skeleton_path) as Skeleton3D
	var target_path: String = String(character.skeleton_path)
	var reference: CharacterModel = (load(REFERENCE_SCENE) as PackedScene).instantiate() as CharacterModel
	var reference_skeleton: Skeleton3D = reference.get_node(reference.skeleton_path) as Skeleton3D
	var reference_library: AnimationLibrary = load(REFERENCE_ANIMATIONS) as AnimationLibrary

	var library: AnimationLibrary = AnimationLibrary.new()
	for glb_path: String in sources:
		var clips: Dictionary = sources[glb_path]
		var own: Dictionary[String, Animation] = _own_animations(glb_path, clips, target, target_path)
		for anim_name: String in own:
			if library.has_animation(anim_name):
				continue
			library.add_animation(anim_name, own[anim_name])
			print("de verdade: %s (%s)" % [anim_name, glb_path.get_file()])
	for anim_name: StringName in reference_library.get_animation_list():
		if library.has_animation(anim_name):
			continue
		var source: Animation = reference_library.get_animation(anim_name)
		library.add_animation(anim_name, SkeletonRetarget.retarget(source, reference_skeleton, String(reference.skeleton_path), target, target_path))
		print("convertida do placeholder: %s" % anim_name)
	var error: Error = ResourceSaver.save(library, output)
	print("salvo: %s (%s)" % [output, error_string(error)])
	character.free()
	reference.free()
	return error


## Animações de um .glb renomeadas e cortadas para o jogo ([param clips]: nome no .glb → [nome no jogo, início, fim]),
## com as trilhas apontando
## para [param target_path]. Só ficam trilhas de ossos que existem em [param target]. O quadril fica no lugar (sem
## andar sozinho em X/Z: quem move o personagem é a simulação) e na altura do esqueleto alvo (o rig de outra fonte
## pode ter a origem e o quadril em outra altura).
func _own_animations(glb_path: String, clips: Dictionary, target: Skeleton3D, target_path: String) -> Dictionary[String, Animation]:
	var result: Dictionary[String, Animation] = {}
	var model: Node = (load(glb_path) as PackedScene).instantiate()
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		push_error("%s sem AnimationPlayer ou Skeleton3D" % glb_path)
		model.free()
		return result
	var player: AnimationPlayer = players[0] as AnimationPlayer
	var source_skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	# Diferença de repouso do quadril (fonte → alvo), em metros.
	var hips_offset: Vector3 = Vector3.ZERO
	var source_hips: int = source_skeleton.find_bone(HIPS)
	var target_hips: int = target.find_bone(HIPS)
	if source_hips >= 0 and target_hips >= 0:
		hips_offset = target.get_bone_rest(target_hips).origin - source_skeleton.get_bone_rest(source_hips).origin
	for source_name: String in clips:
		if not player.has_animation(source_name):
			push_warning("%s não tem a animação %s (tem: %s)" % [glb_path, source_name, player.get_animation_list()])
			continue
		var spec: Array = clips[source_name]
		var anim: Animation = _trim(player.get_animation(source_name), float(spec[1]), float(spec[2]))
		for track: int in range(anim.get_track_count() - 1, -1, -1):
			var bone: String = String(anim.track_get_path(track)).get_slice(":", 1)
			# Ossos-ponta (sem peso na malha) e o que não existe no alvo não precisam de trilha.
			if target.find_bone(bone) < 0:
				anim.remove_track(track)
				continue
			anim.track_set_path(track, NodePath("%s:%s" % [target_path, bone]))
			if bone == String(HIPS) and anim.track_get_type(track) == Animation.TYPE_POSITION_3D:
				_keep_in_place(anim, track, hips_offset)
		var game_name: String = String(spec[0])
		anim.loop_mode = Animation.LOOP_LINEAR if game_name in LOOPED else Animation.LOOP_NONE
		result[game_name] = anim
	model.free()
	return result


## Tira o deslocamento em X/Z do quadril (mantém o sobe-e-desce) e soma [param offset] (repouso da fonte → alvo).
func _keep_in_place(anim: Animation, track: int, offset: Vector3) -> void:
	if anim.track_get_key_count(track) == 0:
		return
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var drift: float = 0.0
	for key: int in range(anim.track_get_key_count(track)):
		var value: Vector3 = anim.track_get_key_value(track, key)
		drift = maxf(drift, Vector2(value.x - first.x, value.z - first.z).length())
		anim.track_set_key_value(track, key, Vector3(first.x, value.y, first.z) + offset)
	print("  quadril: deslocamento X/Z removido (máx %.3f m), ajuste de repouso %s" % [drift, offset])


## Cópia de [param source] só com o trecho [param from]..[param to] s (to < 0 = até o fim), começando em 0. Põe uma
## chave interpolada nas duas pontas de cada trilha para o corte não pular.
func _trim(source: Animation, from: float, to: float) -> Animation:
	var anim: Animation = source.duplicate(true) as Animation
	var end: float = source.length if to < 0.0 else minf(to, source.length)
	if from <= 0.0 and end >= source.length:
		return anim
	for track: int in range(anim.get_track_count()):
		var type: Animation.TrackType = anim.track_get_type(track)
		var first: Variant = _sample(source, track, type, from)
		var last: Variant = _sample(source, track, type, end)
		for key: int in range(anim.track_get_key_count(track) - 1, -1, -1):
			var time: float = anim.track_get_key_time(track, key)
			if time <= from or time >= end:
				anim.track_remove_key(track, key)
		# Desloca as chaves que sobraram para começar em 0 (de trás para frente não colide).
		for key: int in range(anim.track_get_key_count(track)):
			anim.track_set_key_time(track, key, anim.track_get_key_time(track, key) - from)
		anim.track_insert_key(track, 0.0, first)
		anim.track_insert_key(track, end - from, last)
	anim.length = end - from
	return anim


## Valor de uma trilha de [param anim] no instante [param time] (s).
func _sample(anim: Animation, track: int, type: Animation.TrackType, time: float) -> Variant:
	match type:
		Animation.TYPE_POSITION_3D:
			return anim.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D:
			return anim.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return anim.scale_track_interpolate(track, time)
		_:
			return anim.value_track_interpolate(track, time)
