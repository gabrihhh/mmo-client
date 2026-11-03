class_name SkeletonRetarget
extends RefCounted
## Converte poses do esqueleto de REFERÊNCIA (o placeholder de [ART-03]: todos os ossos com rotação de repouso
## zero e braços caídos) para outro esqueleto humanoide com os mesmos nomes de osso (ex.: modelo do Mixamo em
## T-pose, com eixos próprios em cada osso).
##
## Ideia: no placeholder, a rotação GLOBAL de um osso numa pose já é a "mudança desde o repouso" (o repouso é zero).
## No modelo novo, o osso faz a mesma mudança no espaço do mundo, partindo do repouso dele alinhado à pose de
## referência:
##     global_novo = global_referência × alinhamento × repouso_global_novo
## O alinhamento só existe nos braços (T-pose → braços caídos, como no placeholder); nos outros ossos é zero.
## Ossos que o placeholder não tem (UpperChest, ombros, dedos dos pés) ficam no repouso, presos ao pai.
##
## Usado para gerar as animações de um modelo novo a partir das do placeholder (tools/characters/) e para corrigir
## encaixes nos ossos (item na mão, brilho de magia): um deslocamento pensado no osso do placeholder vira o mesmo
## deslocamento no osso do modelo ([method mount_fix]).

## Ossos dos braços: no placeholder apontam para baixo; no modelo novo, para onde a pose de repouso mandar.
const ARM_CHAINS: Dictionary[String, String] = {
	"RightUpperArm": "RightLowerArm",
	"RightLowerArm": "RightHand",
	"LeftUpperArm": "LeftLowerArm",
	"LeftLowerArm": "LeftHand",
}
## A mão não tem filho no esqueleto: usa a direção do antebraço.
const HAND_DIRECTION_FROM: Dictionary[String, String] = {
	"RightHand": "RightLowerArm",
	"LeftHand": "LeftLowerArm",
}


## Rotação (no espaço do esqueleto) que leva o osso [param bone_name] de [param skeleton], em repouso, à direção
## que ele tem na pose de referência. Fora dos braços (ou osso inexistente): identidade.
static func alignment(skeleton: Skeleton3D, bone_name: String) -> Basis:
	var segment: String = HAND_DIRECTION_FROM.get(bone_name, bone_name)
	if not ARM_CHAINS.has(segment):
		return Basis.IDENTITY
	var from: int = skeleton.find_bone(segment)
	var to: int = skeleton.find_bone(ARM_CHAINS[segment])
	if from < 0 or to < 0:
		return Basis.IDENTITY
	var direction: Vector3 = skeleton.get_bone_global_rest(to).origin - skeleton.get_bone_global_rest(from).origin
	if direction.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(Quaternion(direction.normalized(), Vector3.DOWN))


## Transformação que leva um deslocamento pensado no osso [param bone_name] do placeholder para o espaço do mesmo
## osso de [param skeleton]. Ex.: o item na mão, posto com [code]mount_fix * Transform3D(grip, offset)[/code], fica
## igual nos dois modelos. No próprio placeholder é a identidade.
static func mount_fix(skeleton: Skeleton3D, bone_name: String) -> Transform3D:
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0:
		return Transform3D.IDENTITY
	var rest: Basis = skeleton.get_bone_global_rest(bone).basis
	return Transform3D((alignment(skeleton, bone_name) * rest).inverse(), Vector3.ZERO)


## Converte [param source] (animação do [param reference] — o placeholder) para [param target]. As trilhas novas
## apontam para [param target_path] (caminho do esqueleto a partir da raiz do personagem, ex.
## "Model/Armature/GeneralSkeleton"). Amostra a [param fps] quadros por segundo. Ossos que não mexem ficam sem trilha.
static func retarget(source: Animation, reference: Skeleton3D, reference_path: String, target: Skeleton3D, target_path: String, fps: float = 30.0) -> Animation:
	var result: Animation = Animation.new()
	result.length = source.length
	result.loop_mode = source.loop_mode
	var times: Array[float] = []
	var steps: int = maxi(1, ceili(source.length * fps))
	for i: int in range(steps + 1):
		times.append(minf(source.length, float(i) / fps))

	# Rotações locais do modelo novo, por osso e por quadro.
	var locals: Array[Array] = []
	for bone: int in range(target.get_bone_count()):
		locals.append([])
	var hips_offsets: Array[Vector3] = []
	for time: float in times:
		var reference_globals: Dictionary[String, Basis] = _reference_globals(source, reference, reference_path, time)
		var target_globals: Array[Basis] = []
		for bone: int in range(target.get_bone_count()):
			var bone_name: String = target.get_bone_name(bone)
			var parent: int = target.get_bone_parent(bone)
			var parent_global: Basis = target_globals[parent] if parent >= 0 else Basis.IDENTITY
			var global: Basis
			if reference_globals.has(bone_name):
				global = reference_globals[bone_name] * alignment(target, bone_name) * target.get_bone_global_rest(bone).basis
			else:
				global = parent_global * target.get_bone_rest(bone).basis
			target_globals.append(global)
			locals[bone].append((parent_global.inverse() * global).get_rotation_quaternion())
		hips_offsets.append(_hips_offset(source, reference, reference_path, time))

	for bone: int in range(target.get_bone_count()):
		var rest: Quaternion = target.get_bone_rest(bone).basis.get_rotation_quaternion()
		var moves: bool = false
		for value: Quaternion in locals[bone]:
			if not value.is_equal_approx(rest):
				moves = true
				break
		if not moves:
			continue
		var track: int = result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track, NodePath("%s:%s" % [target_path, target.get_bone_name(bone)]))
		for i: int in range(times.size()):
			result.rotation_track_insert_key(track, times[i], locals[bone][i])

	var hips: int = target.find_bone("Hips")
	var hips_moves: bool = hips_offsets.any(func(offset: Vector3) -> bool: return not offset.is_zero_approx())
	if hips >= 0 and hips_moves:
		var track: int = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(track, NodePath("%s:Hips" % target_path))
		for i: int in range(times.size()):
			result.position_track_insert_key(track, times[i], target.get_bone_rest(hips).origin + hips_offsets[i])
	return result


## Rotação global de cada osso do placeholder em [param time] (repouso zero: local = trilha, ou zero sem trilha).
static func _reference_globals(source: Animation, reference: Skeleton3D, reference_path: String, time: float) -> Dictionary[String, Basis]:
	var globals: Dictionary[String, Basis] = {}
	var by_index: Array[Basis] = []
	for bone: int in range(reference.get_bone_count()):
		var bone_name: String = reference.get_bone_name(bone)
		var local: Basis = reference.get_bone_rest(bone).basis
		var track: int = source.find_track(NodePath("%s:%s" % [reference_path, bone_name]), Animation.TYPE_ROTATION_3D)
		if track >= 0:
			local = Basis(source.rotation_track_interpolate(track, time))
		var parent: int = reference.get_bone_parent(bone)
		var global: Basis = (by_index[parent] if parent >= 0 else Basis.IDENTITY) * local
		by_index.append(global)
		globals[bone_name] = global
	return globals


## Quanto o quadril do placeholder saiu do repouso em [param time] (m), ou zero sem trilha de posição.
static func _hips_offset(source: Animation, reference: Skeleton3D, reference_path: String, time: float) -> Vector3:
	var track: int = source.find_track(NodePath("%s:Hips" % reference_path), Animation.TYPE_POSITION_3D)
	var hips: int = reference.find_bone("Hips")
	if track < 0 or hips < 0:
		return Vector3.ZERO
	return source.position_track_interpolate(track, time) - reference.get_bone_rest(hips).origin
