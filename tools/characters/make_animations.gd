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
## Elas vêm de OUTRO rig (o da API do Meshy), com os ossos em outros lugares dentro do corpo (ombro para trás, braço
## inclinado...): copiar só a rotação deixava braços e pernas tortos. Por isso são reconvertidas quadro a quadro
## ([method _bake]): cada osso aponta para a mesma direção que tem na animação original.
##
## Animação própria de habilidade ([ART-08]): res://assets/itens/<slot>/<nome>/animation-attack/ (ataque simples) e
## animation-skill-N/ (carta N) guardam male.glb e female.glb (o 1º clipe do arquivo, inteiro). Se existir, entra
## na biblioteca como "skill_<abilityId>" ([constant ItemAnimations.SKILL_PREFIX]) e o jogo toca ela no lugar da
## genérica de [AbilityVisuals]; sem o do corpo, usa o do outro corpo (é reconvertido do mesmo jeito). A pasta de
## cada habilidade vem de [constant ItemAnimations.FOLDERS] (gerada). Importar o .glb com o mapa de ossos:
## python3 tools/characters/animation_import.py (escreve o .import), depois importar no Godot.

## Clipes de ação do Meshy (mesmos nomes nos dois corpos): nome no .glb → [nome no jogo, início (s), fim (s)].
## Cada clipe é cortado no trecho útil (sem preparação parada nem recuperação longa); o momento do golpe dentro do
## trecho cortado está em [constant CharacterAnimator.HIT_TIMES] (medido pelo pico de velocidade da mão).
const MESHY_ACTIONS: Dictionary[String, Array] = {
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
## Posturas de combate e golpe de duas mãos (Meshy texto→movimento e catálogo, [MESHY-06]), por corpo.
const MESHY_IDLE_SWORD: Dictionary[String, Array] = {"IdleSword": ["idle_sword", 0.0, -1.0]}
const MESHY_IDLE_STAFF: Dictionary[String, Array] = {"IdleStaff": ["idle_staff", 0.0, -1.0]}
const MESHY_TWO_HANDED: Dictionary[String, Array] = {"Attack2H": ["attack_sword", 0.2, 1.7]}
## Golpe de espadão do Mixamo ("Great Sword Slash", FBX sem pele, 30 fps, sem redução de quadros): ataque simples
## da espada do Cavaleiro ([JOGO-08]). Mesmo arquivo para os dois corpos (o rig do Mixamo é reconvertido em cada um).
const MIXAMO_GREAT_SWORD: Dictionary[String, Array] = {"mixamo_com": ["attack_greatsword", 0.0, -1.0]}
## Nome do clipe numa fonte que significa "o primeiro clipe do arquivo" (animações próprias das pastas dos itens).
const FIRST_CLIP: String = "*"
## Clipe inteiro (sem corte): fim negativo.
const WHOLE: float = -1.0
## Personagens: cena, biblioteca gerada e fontes ("glb" → {nome do clipe no .glb → [nome no jogo, início, fim]}).
## Se duas fontes dão o mesmo nome no jogo, vale a primeira.
const CHARACTERS: Array[Dictionary] = [
	{
		"body": "male",
		"scene": "res://assets/characters/male/male_character.tscn",
		"output": "res://assets/characters/male/male_animations.tres",
		"sources": {
			"res://assets/characters/male/male.glb": {"Running": ["run", 0.0, WHOLE]},
			"res://tools/characters/animations/male_idle.glb": {"Idle": ["idle", 0.0, WHOLE]},
			"res://tools/characters/animations/male_idle_sword.glb": MESHY_IDLE_SWORD,
			"res://tools/characters/animations/male_idle_staff.glb": MESHY_IDLE_STAFF,
			"res://tools/characters/animations/male_attack2h.glb": MESHY_TWO_HANDED,
			"res://tools/characters/animations/male_combat.glb": MESHY_ACTIONS,
			"res://tools/characters/animations/mixamo_great_sword_slash.fbx": MIXAMO_GREAT_SWORD,
		},
	},
	{
		"body": "female",
		"scene": "res://assets/characters/female/female_character.tscn",
		"output": "res://assets/characters/female/female_animations.tres",
		"sources": {
			"res://assets/characters/female/female.glb": {"Running": ["run", 0.0, WHOLE]},
			"res://tools/characters/animations/female_idle.glb": {"Idle": ["idle", 0.0, WHOLE]},
			"res://tools/characters/animations/female_idle_sword.glb": MESHY_IDLE_SWORD,
			"res://tools/characters/animations/female_idle_staff.glb": MESHY_IDLE_STAFF,
			"res://tools/characters/animations/female_attack2h.glb": MESHY_TWO_HANDED,
			"res://tools/characters/animations/female_combat.glb": MESHY_ACTIONS,
			"res://tools/characters/animations/mixamo_great_sword_slash.fbx": MIXAMO_GREAT_SWORD,
		},
	},
	{
		# Zumbi (monstro, [JOGO-13]): modelo do Meshy com rig da API. Anda arrastado: o "Walking" do próprio rig faz
		# o papel de "run"; o resto vem das animações do masculino (reconvertidas para este esqueleto).
		"body": "zombie",
		"scene": "res://assets/characters/zombie/zombie_character.tscn",
		"output": "res://assets/characters/zombie/zombie_animations.tres",
		"sources": {
			"res://tools/characters/animations/zombie_walk.glb": {"Walking": ["run", 0.0, WHOLE]},
			"res://tools/characters/animations/male_idle.glb": {"Idle": ["idle", 0.0, WHOLE]},
			"res://tools/characters/animations/male_idle_sword.glb": MESHY_IDLE_SWORD,
			"res://tools/characters/animations/male_idle_staff.glb": MESHY_IDLE_STAFF,
			"res://tools/characters/animations/male_attack2h.glb": MESHY_TWO_HANDED,
			"res://tools/characters/animations/male_combat.glb": MESHY_ACTIONS,
			"res://tools/characters/animations/mixamo_great_sword_slash.fbx": MIXAMO_GREAT_SWORD,
		},
	},
]
## Animações de verdade que dão a volta (ciclo).
const LOOPED: Array[String] = ["run", "idle", "idle_sword", "idle_staff"]
## Animações de corpo todo (camada de movimento). As outras são ações da camada de cima, que no jogo não mexe no
## quadril ([CharacterAnimator]): nelas a rotação do quadril passa para a base da coluna ([method _hips_to_spine]).
## Cada ação também sai como "<nome>_full" (corpo todo, com quadril e pernas), que o jogo toca com o personagem parado.
const FULL_BODY: Array[String] = ["run", "idle", "idle_sword", "idle_staff"]
## Ações que só existem na versão de cima (sem "<nome>_full" para tocar parado no corpo todo).
const UPPER_ONLY: Array[String] = ["flinch"]
## Osso raiz (o único com trilha de posição que importa).
const HIPS: StringName = &"Hips"
## Ossos que, vindos do rig da API, não copiam a rotação: ficam retos em relação ao pai (no repouso). No rig da API a
## junta "mão" fica na base dos dedos (o antebraço vai até a palma) e a rotação dela só dobra os dedos; aplicada à
## mão deste rig (que começa no pulso) dobrava a mão inteira para trás.
const KEEP_REST: Array[String] = ["LeftHand", "RightHand"]
## Quadros por segundo da reconversão entre rigs ([method _bake]).
const BAKE_FPS: float = 30.0
## Osso → filho que dá a direção dele (o "para onde aponta"). Osso fora da lista só recebe a rotação de corpo todo.
const AIM_CHILD: Dictionary[String, String] = {
	"Spine": "Chest", "Chest": "UpperChest", "UpperChest": "Neck", "Neck": "Head",
	"LeftShoulder": "LeftUpperArm", "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand",
	"RightShoulder": "RightUpperArm", "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand",
	"LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "LeftToes",
	"RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "RightToes",
}
## Placeholder (referência das poses convertidas).
const REFERENCE_SCENE: String = "res://assets/placeholders/character.tscn"
const REFERENCE_ANIMATIONS: String = "res://assets/placeholders/character_animations.tres"


func _initialize() -> void:
	var failed: bool = false
	for entry: Dictionary in CHARACTERS:
		print("== %s" % entry["scene"])
		var sources: Dictionary = (entry["sources"] as Dictionary).duplicate()
		sources.merge(_item_sources(String(entry["body"])))
		failed = _make(entry["scene"], sources, entry["output"]) != OK or failed
	quit(1 if failed else 0)


## Animações próprias das pastas dos itens para o corpo [param body] ([ART-08]): .glb → {primeiro clipe →
## ["skill_<abilityId>", 0, inteiro]}. Usa o arquivo do corpo; sem ele, o do outro corpo.
func _item_sources(body: String) -> Dictionary:
	var result: Dictionary = {}
	for ability_id: String in ItemAnimations.FOLDERS:
		var folder: String = ItemAnimations.FOLDERS[ability_id]
		var candidates: Array[String] = ["%s/%s.glb" % [folder, body]]
		for other: String in ItemModels.BODIES:
			if other != body:
				candidates.append("%s/%s.glb" % [folder, other])
		for path: String in candidates:
			if ResourceLoader.exists(path):
				result[path] = {FIRST_CLIP: [ItemAnimations.SKILL_PREFIX + ability_id, 0.0, WHOLE]}
				break
	return result


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
		# Fonte que não é o próprio modelo do personagem = outro rig: reconverter.
		var other_rig: bool = glb_path != (character.get_node("Model") as Node).scene_file_path
		var own: Dictionary[String, Animation] = _own_animations(glb_path, clips, target, target_path, other_rig)
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
## pode ter a origem e o quadril em outra altura). [param other_rig]: a fonte é outro rig ([method _bake]).
func _own_animations(glb_path: String, clips: Dictionary, target: Skeleton3D, target_path: String, other_rig: bool) -> Dictionary[String, Animation]:
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
	if source_hips < 0:
		push_warning("%s sem osso Hips: importar com o mapa de ossos (python3 tools/characters/animation_import.py)" % glb_path)
	if source_hips >= 0 and target_hips >= 0:
		hips_offset = target.get_bone_rest(target_hips).origin - source_skeleton.get_bone_rest(source_hips).origin
	for clip_name: String in clips:
		var source_name: String = clip_name
		if clip_name == FIRST_CLIP:
			source_name = ""
			for candidate: StringName in player.get_animation_list():
				if source_name.is_empty() and candidate != &"RESET":
					source_name = String(candidate)
		if not player.has_animation(source_name):
			push_warning("%s não tem a animação %s (tem: %s)" % [glb_path, source_name, player.get_animation_list()])
			continue
		var spec: Array = clips[clip_name]
		var anim: Animation = _trim(player.get_animation(source_name), float(spec[1]), float(spec[2]))
		if other_rig:
			anim = _bake(anim, source_skeleton, target)
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
		if game_name not in FULL_BODY:
			# Versão de corpo todo (parado) antes de dobrar o quadril na coluna (versão só de cima, andando).
			if game_name not in UPPER_ONLY:
				var full: Animation = anim.duplicate(true) as Animation
				full.loop_mode = Animation.LOOP_NONE
				result[game_name + CharacterAnimator.FULL_SUFFIX] = full
			_hips_to_spine(anim, target)
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


## Reconverte [param anim] (do esqueleto [param source]) para [param target], quadro a quadro ([constant BAKE_FPS]).
## Para cada osso: a rotação de corpo todo da fonte (pose global × inverso do repouso global) é aplicada ao repouso
## do alvo já corrigido para apontar como o osso da fonte no repouso ([constant AIM_CHILD]); assim a direção de cada
## osso na pose bate com a original mesmo que os dois rigs ponham as juntas em lugares diferentes. Devolve trilhas de
## rotação (caminho "<skeleton>:<osso>", trocado depois pelo do personagem) e a de posição do quadril original.
func _bake(anim: Animation, source: Skeleton3D, target: Skeleton3D) -> Animation:
	var rotation_tracks: Dictionary[String, int] = {}
	var hips_track: int = -1
	for track: int in range(anim.get_track_count()):
		var bone: String = String(anim.track_get_path(track)).get_slice(":", 1)
		match anim.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = track
			Animation.TYPE_POSITION_3D:
				if bone == String(HIPS):
					hips_track = track
	var source_order: PackedInt32Array = _bone_order(source)
	var target_order: PackedInt32Array = _bone_order(target)
	# Correção de repouso por osso do alvo (global): gira a direção do osso do alvo até a do osso da fonte.
	var rest_fix: Dictionary[int, Quaternion] = {}
	for bone: int in target_order:
		var name: String = target.get_bone_name(bone)
		var child_name: String = AIM_CHILD.get(name, "")
		var source_bone: int = source.find_bone(name)
		if child_name.is_empty() or source_bone < 0 or target.find_bone(child_name) < 0 or source.find_bone(child_name) < 0:
			rest_fix[bone] = Quaternion.IDENTITY
			continue
		var target_dir: Vector3 = target.get_bone_global_rest(target.find_bone(child_name)).origin - target.get_bone_global_rest(bone).origin
		var source_dir: Vector3 = source.get_bone_global_rest(source.find_bone(child_name)).origin - source.get_bone_global_rest(source_bone).origin
		rest_fix[bone] = Quaternion(target_dir.normalized(), source_dir.normalized())

	var result: Animation = Animation.new()
	result.length = anim.length
	var out_tracks: Dictionary[int, int] = {}
	for bone: int in target_order:
		if source.find_bone(target.get_bone_name(bone)) < 0:
			continue
		var track: int = result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track, NodePath("Skeleton:%s" % target.get_bone_name(bone)))
		out_tracks[bone] = track
	if hips_track >= 0:
		var track: int = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(track, NodePath("Skeleton:%s" % HIPS))
		for key: int in range(anim.track_get_key_count(hips_track)):
			result.position_track_insert_key(track, anim.track_get_key_time(hips_track, key), anim.track_get_key_value(hips_track, key))

	var frames: int = ceili(anim.length * BAKE_FPS)
	for frame: int in range(frames + 1):
		var time: float = minf(float(frame) / BAKE_FPS, anim.length)
		# Pose global (rotação) da fonte neste instante.
		var source_global: Dictionary[int, Quaternion] = {}
		for bone: int in source_order:
			var local: Quaternion = source.get_bone_rest(bone).basis.get_rotation_quaternion()
			var name: String = source.get_bone_name(bone)
			if rotation_tracks.has(name):
				local = anim.rotation_track_interpolate(rotation_tracks[name], time)
			var parent: int = source.get_bone_parent(bone)
			source_global[bone] = (source_global[parent] if parent >= 0 else Quaternion.IDENTITY) * local
		# Pose global do alvo, do pai para os filhos.
		var target_global: Dictionary[int, Quaternion] = {}
		for bone: int in target_order:
			var parent: int = target.get_bone_parent(bone)
			var parent_global: Quaternion = target_global[parent] if parent >= 0 else Quaternion.IDENTITY
			var rest_global: Quaternion = target.get_bone_global_rest(bone).basis.get_rotation_quaternion()
			var source_bone: int = source.find_bone(target.get_bone_name(bone))
			var global: Quaternion = parent_global * target.get_bone_rest(bone).basis.get_rotation_quaternion()
			if source_bone >= 0 and target.get_bone_name(bone) not in KEEP_REST:
				var delta: Quaternion = source_global[source_bone] * source.get_bone_global_rest(source_bone).basis.get_rotation_quaternion().inverse()
				global = delta * rest_fix[bone] * rest_global
			target_global[bone] = global.normalized()
			if out_tracks.has(bone):
				result.rotation_track_insert_key(out_tracks[bone], time, (parent_global.inverse() * global).normalized())
	return result


## Índices dos ossos de [param skeleton] com cada pai antes dos filhos.
func _bone_order(skeleton: Skeleton3D) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	var pending: Array[int] = []
	pending.assign(skeleton.get_parentless_bones())
	while not pending.is_empty():
		var bone: int = pending.pop_front()
		order.append(bone)
		pending.append_array(skeleton.get_bone_children(bone))
	return order


## Passa a rotação do quadril de [param anim] para o osso "Spine" (tira a trilha de rotação do quadril). No jogo a
## ação toca só nos ossos de cima, sobre o quadril do idle/corrida: sem isso o tronco perdia a inclinação e o giro
## que o clipe faz pelo quadril (ex.: o golpe forte curva o corpo todo para a frente).
func _hips_to_spine(anim: Animation, skeleton: Skeleton3D) -> void:
	var hips_track: int = -1
	var spine_track: int = -1
	for track: int in range(anim.get_track_count()):
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: String = String(anim.track_get_path(track)).get_slice(":", 1)
		if bone == String(HIPS):
			hips_track = track
		elif bone == "Spine":
			spine_track = track
	if hips_track < 0 or spine_track < 0:
		return
	var rest_inverse: Quaternion = skeleton.get_bone_rest(skeleton.find_bone(HIPS)).basis.get_rotation_quaternion().inverse()
	for key: int in range(anim.track_get_key_count(spine_track)):
		var time: float = anim.track_get_key_time(spine_track, key)
		var hips: Quaternion = anim.rotation_track_interpolate(hips_track, time)
		var spine: Quaternion = anim.track_get_key_value(spine_track, key)
		anim.track_set_key_value(spine_track, key, (rest_inverse * hips * spine).normalized())
	anim.remove_track(hips_track)
