class_name EquipmentView
extends Node
## Mostra no boneco os itens vestidos ([ART-02], [ART-03]): segue o [member PlayerState.look] e troca os modelos.
##
## Cada slot com modelo tem um encaixe ([BoneAttachment3D]) num osso do esqueleto: arma na mão direita
## ("RightHand"), chapéu/capuz/elmo na cabeça ("Head"), túnica/peitoral no peito ("Chest") e um calçado em cada pé
## ("LeftFoot"; no "RightFoot" o mesmo modelo espelhado em X). Os encaixes acompanham as animações. **Peito e pés**
## são "vestidos" no corpo ([BodySkinning]): viram malhas com os pesos do corpo embaixo delas (dobram junto: ombreira
## com o braço, barra com a coxa, bota com pé e canela); o calçado é encaixado pelos vértices do pé do corpo.
## Modelos e o jeito de segurar cada item: [ItemModels]. Pegada e offsets são medidos no osso do placeholder;
## [method SkeletonRetarget.mount_fix] converte para o osso de outro modelo (eixos diferentes).
##
## Arma na mão (as animações do Meshy são de mão vazia, então a arma é posta "à moda dos jogos"):
## - **parado/correndo**: a arma fica numa posição de carregar à frente do corpo ([method ItemModels.carry]) e as
##   mãos vão até ela por IK ([TwoBoneIK3D]): a direita no cabo; a esquerda também, se for de duas mãos;
## - **durante uma ação** (ataque, magia): a arma volta a seguir a mão animada, com o comprimento puxado para a
##   direção de descanso ou para o antebraço ([method ItemModels.hold_direction]); ao terminar, volta suave para a
##   posição de carregar.
## A arma também escolhe a postura parada do personagem ([method CharacterAnimator.set_idle_animation]).
## Mãos fechadas ([HandGrip], [ART-07]): com item na mão a direita fecha; a esquerda também em arma de duas mãos ou em
## par. Só nos corpos importados com ossos de dedo.

## Encaixe → [slot do item, osso]. O slot "feet" tem dois encaixes (um por pé); o "hand" tem a mão esquerda só
## para armas em par ([method ItemModels.is_paired], ex.: adagas gêmeas).
const MOUNTS: Dictionary[String, Array] = {
	"hand": ["hand", "RightHand"],
	"off_hand": ["hand", "LeftHand"],
	"head": ["head", "Head"],
	"chest": ["chest", "Chest"],
	"foot_left": ["feet", "LeftFoot"],
	"foot_right": ["feet", "RightFoot"],
}
## Para onde cada cotovelo aponta no IK (espaço do personagem, m): para fora e para baixo. Lado direito = −X.
const POLES: Dictionary[String, Vector3] = {"Left": Vector3(0.8, 0.6, -0.2), "Right": Vector3(-0.8, 0.6, -0.2)}
## Pulso em relação ao ponto de pegada (espaço do personagem, m): a pegada fica na palma, o pulso um pouco atrás.
const WRIST_FROM_GRIP: Vector3 = Vector3(0.0, 0.0, -0.06)
## Rapidez com que a direção de puxão alcança a nova (1/s).
const DIRECTION_BLEND_RATE: float = 18.0
## Rapidez da troca de puxão (unidades de puxão por segundo).
const PULL_BLEND_RATE: float = 20.0
## Rapidez da entrada/saída da posição de carregar (fração por segundo): sai rápido ao atacar, volta mais devagar.
const CARRY_OUT_RATE: float = 10.0
const CARRY_IN_RATE: float = 4.0

## Encaixe automático ([ART-04]): encaixe ("chest") → caixa (m, espaço do encaixe) que o item deve preencher. Vem de
## [member CharacterModel.chest_fit_box]. Calçados não usam caixa (encaixe pelo pé do corpo, [BodySkinning]).
## Encaixe sem caixa usa o item como a cena dele está (ex.: mão e cabeça).
var fit_boxes: Dictionary[String, AABB] = {}

## Malha do corpo (com pesos): de onde as roupas copiam os pesos ([BodySkinning]). null = roupas rígidas.
var body: MeshInstance3D = null

## Corpo do personagem ("male"/"female"): escolhe a malha de cada item feita para ele ([ItemModels.model_path]).
var body_id: String = Protocol.BODY_MALE

## Animador do personagem (ação tocando? postura parada da arma); null = sem isso.
var animator: CharacterAnimator = null

var _mounts: Dictionary[String, Node3D] = {}
var _state: PlayerState = null
## Esqueleto do personagem (direção do antebraço durante a ação).
var _skeleton: Skeleton3D = null
## IK de cada braço ("Left"/"Right") e o alvo do pulso.
var _arm_ik: Dictionary[String, TwoBoneIK3D] = {}
var _arm_target: Dictionary[String, Node3D] = {}
## Item de segurar com direção de descanso (null = nenhum), o id dele e a pegada (rotação na mão).
var _held_model: Node3D = null
var _held_id: String = ""
var _held_grip: Basis = Basis.IDENTITY
## Puxão atual (suavizado entre fora de ação e durante a ação).
var _held_pull: float = 0.0
## Direção de puxão atual (global, suavizada: não pula ao começar/terminar a ação). Zero = ainda não definida.
var _held_direction: Vector3 = Vector3.ZERO
## Malha original do corpo (antes de esconder os pés).
var _body_mesh: Mesh = null
## Malhas com pesos criadas para o item de peito ([BodySkinning]); liberadas a cada troca de roupa.
var _skinned: Array[MeshInstance3D] = []
## Malhas vestidas das roupas sob medida do look atual: a pele embaixo delas afunda ([method BodySkinning.covered_mesh]).
var _covers: Array[Mesh] = []
## Chave das roupas em [member _covers] (itens), para o cache da malha do corpo.
var _covers_key: String = ""
## Fecha os dedos de quem segura algo (null = corpo sem ossos de dedo).
var _hand_grip: HandGrip = null
## Quanto a arma está na posição de carregar (0 = segue a mão animada, 1 = carregada à frente com IK).
var _carry_weight: float = 0.0


func _ready() -> void:
	process_priority = 100  # depois do AnimationTree, com a pose do quadro já aplicada


func _process(delta: float) -> void:
	if _held_model == null or not is_instance_valid(_held_model):
		_set_arm_weight("Right", 0.0)
		_set_arm_weight("Left", 0.0)
		if _hand_grip != null:
			_hand_grip.set_held(null)
			_hand_grip.set_hand_rotation("Right", Basis.IDENTITY, 0.0)
			_hand_grip.set_hand_rotation("Left", Basis.IDENTITY, 0.0)
		return
	var body: Node3D = get_parent() as Node3D
	var body_basis: Basis = body.global_basis.orthonormalized()
	var acting: bool = animator != null and animator.is_acting()

	# 1) Arma seguindo a mão animada (comprimento puxado para a direção de descanso ou para o antebraço).
	_held_pull = move_toward(_held_pull, ItemModels.hold_pull(_held_id, acting), PULL_BLEND_RATE * delta)
	var want_direction: Vector3 = body_basis * ItemModels.hold_direction(_held_id)
	if acting and ItemModels.follows_forearm_in_action(_held_id):
		var forearm: Vector3 = _bone_position("RightHand") - _bone_position("RightLowerArm")
		if forearm.length() > 0.001:
			want_direction = forearm.normalized()
	_held_direction = want_direction if _held_direction == Vector3.ZERO \
		else _held_direction.slerp(want_direction, minf(1.0, DIRECTION_BLEND_RATE * delta)).normalized()
	var mount: Node3D = _held_model.get_parent() as Node3D
	var rigid: Basis = mount.global_basis * _held_grip
	var size: float = rigid.get_scale().y
	var follow_basis: Basis = _basis_along((rigid.y.normalized() + _held_direction * _held_pull).normalized(), rigid.z)
	var follow_origin: Vector3 = mount.global_position
	# Mão fechada ([HandGrip]): o cabo passa pelo punho. A mão gira para o eixo da arma e a arma fica no punho.
	var fisted: bool = _hand_grip != null
	var follow_hand: Basis = Basis.IDENTITY
	if fisted:
		var wrist: Vector3 = _bone_position("RightHand")
		follow_hand = _hand_basis("Right", follow_basis.y, wrist - _bone_position("RightLowerArm"))
		follow_origin = wrist + follow_hand * _fist_offset("Right")

	# 2) Posição de carregar à frente do corpo (parado/correndo), misturada pelo peso.
	var carry: Transform3D = ItemModels.carry(_held_id)
	var has_carry: bool = carry != Transform3D()
	var target_weight: float = 1.0 if has_carry and not acting else 0.0
	_carry_weight = move_toward(_carry_weight, target_weight, (CARRY_IN_RATE if target_weight > _carry_weight else CARRY_OUT_RATE) * delta)
	var final_basis: Basis = follow_basis
	var final_origin: Vector3 = follow_origin
	if has_carry and _carry_weight > 0.0:
		var carry_origin: Vector3 = body.global_transform * carry.origin
		var carry_basis: Basis = _basis_along((body_basis * carry.basis.y).normalized(), body_basis.x)
		final_basis = Basis(follow_basis.get_rotation_quaternion().slerp(carry_basis.get_rotation_quaternion(), _carry_weight))
		final_origin = follow_origin.lerp(carry_origin, _carry_weight)
	_held_model.global_transform = Transform3D(final_basis.scaled_local(Vector3.ONE * size), final_origin)

	if fisted:
		_grip_hands(final_basis.y.normalized(), final_origin, follow_hand)
		return

	# 3) Mãos: a direita vai ao cabo só carregando (na ação quem manda é a animação); a esquerda, sempre que a arma
	#    for de duas mãos.
	_place_arm("Right", final_origin + body_basis * WRIST_FROM_GRIP, _carry_weight)
	if ItemModels.is_two_handed(_held_id):
		var off_grip: Vector3 = _held_model.global_transform * ItemModels.off_hand_grip(_held_id)
		_place_arm("Left", off_grip + body_basis * WRIST_FROM_GRIP, 1.0)
	else:
		_set_arm_weight("Left", 0.0)


## Mãos fechadas em volta do cabo ([HandGrip]). [param axis] = eixo da arma (global, do cabo para a ponta),
## [param grip] = ponto do cabo da mão direita (global), [param follow_hand] = rotação da mão direita seguindo a
## animação. Carregando, o pulso vai por IK até onde o punho envolve o cabo; na ação, o pulso é o da animação (a arma
## já foi posta no punho). Arma de duas mãos: a esquerda fecha no segundo ponto do cabo.
func _grip_hands(axis: Vector3, grip: Vector3, follow_hand: Basis) -> void:
	var carry_hand: Basis = _hand_basis("Right", axis, grip - _bone_position("RightUpperArm"))
	var hand: Basis = Basis(follow_hand.get_rotation_quaternion().slerp(carry_hand.get_rotation_quaternion(), _carry_weight))
	_place_arm("Right", grip - hand * _fist_offset("Right"), _carry_weight)
	_hand_grip.set_hand_rotation("Right", hand, 1.0)
	_hand_grip.set_held(_held_model)
	if ItemModels.is_two_handed(_held_id):
		var off_grip: Vector3 = _held_model.global_transform * ItemModels.off_hand_grip(_held_id)
		var left: Basis = _hand_basis("Left", axis, off_grip - _bone_position("LeftUpperArm"))
		_place_arm("Left", off_grip - left * _fist_offset("Left"), 1.0)
		_hand_grip.set_hand_rotation("Left", left, 1.0)
	else:
		_set_arm_weight("Left", 0.0)
		_hand_grip.set_hand_rotation("Left", Basis.IDENTITY, 0.0)


## Rotação global da mão [param side] com o buraco do punho no eixo [param axis] (polegar para o lado da ponta) e os
## dedos o mais perto possível de [param along_hint] (direção do braço até a mão).
func _hand_basis(side: String, axis: Vector3, along_hint: Vector3) -> Basis:
	var fist: Transform3D = _hand_grip.fist_frame(side)
	var x: Vector3 = axis.normalized()
	var y: Vector3 = along_hint - x * along_hint.dot(x)
	if y.length() < 0.001:
		y = x.cross(Vector3.UP if absf(x.y) < 0.9 else Vector3.FORWARD)
	y = y.normalized()
	return Basis(x, y, x.cross(y)) * fist.basis.inverse()


## Do pulso ao centro do punho da mão [param side], no espaço da mão já girada (multiplicar pela rotação global da mão).
func _fist_offset(side: String) -> Vector3:
	return _hand_grip.fist_frame(side).origin * _skeleton.global_basis.get_scale().x


## Cria os encaixes nos ossos de [param skeleton]. [param placements]: encaixe ("hand", "head", "chest", "foot_left")
## → onde o item assenta, a partir do início do osso, com os eixos do personagem em repouso (+Y cima, +Z frente;
## escala = tamanho do item para este corpo). Item de segurar: a origem é a pegada (osso do placeholder, ver
## [member CharacterModel.hand_item_offset]). "foot_right" = "foot_left" espelhado em X. Encaixe fora de
## [param placements] não é criado (o item daquele slot não aparece neste corpo).
func setup(skeleton: Skeleton3D, placements: Dictionary[String, Transform3D]) -> void:
	_skeleton = skeleton
	var all: Dictionary[String, Transform3D] = placements.duplicate()
	if all.has("hand"):
		# Mão esquerda = a direita espelhada em X (arma em par).
		all["off_hand"] = Transform3D(Basis.FLIP_X, Vector3.ZERO) * all["hand"]
	if all.has("foot_left"):
		# Espelho em X (lado direito do corpo): posição com X trocado e o modelo espelhado (pé esquerdo → direito).
		all["foot_right"] = Transform3D(Basis.FLIP_X, Vector3.ZERO) * all["foot_left"]
	for key: String in MOUNTS:
		if not all.has(key):
			continue
		var bone_name: String = MOUNTS[key][1]
		if skeleton.find_bone(bone_name) < 0:
			continue
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = bone_name + "Mount"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		var mount: Node3D = Node3D.new()
		mount.transform = SkeletonRetarget.mount_fix(skeleton, bone_name) * all[key]
		attachment.add_child(mount)
		_mounts[key] = mount
	for side: String in POLES:
		_setup_arm_ik(skeleton, side)
	if HandGrip.supports(skeleton):
		_hand_grip = HandGrip.new()
		_hand_grip.name = "HandGrip"
		skeleton.add_child(_hand_grip)
	_refresh()


## Cria o IK de um braço ([param side] = "Left"/"Right"), desligado. O alvo e o polo entram na cena depois
## (call_deferred); os caminhos são ligados em [method _place_arm].
func _setup_arm_ik(skeleton: Skeleton3D, side: String) -> void:
	for bone: String in ["UpperArm", "LowerArm", "Hand"]:
		if skeleton.find_bone(side + bone) < 0:
			return
	var body: Node3D = get_parent() as Node3D
	var pole: Node3D = Node3D.new()
	pole.name = side + "ArmPole"
	pole.position = POLES[side]
	body.add_child.call_deferred(pole)
	var target: Node3D = Node3D.new()
	target.name = side + "WristTarget"
	body.add_child.call_deferred(target)
	var ik: TwoBoneIK3D = TwoBoneIK3D.new()
	ik.name = side + "ArmIK"
	ik.set_setting_count(1)
	ik.set_root_bone_name(0, side + "UpperArm")
	ik.set_middle_bone_name(0, side + "LowerArm")
	ik.set_end_bone_name(0, side + "Hand")
	ik.active = false
	ik.set_meta(&"pole", pole)
	skeleton.add_child(ik)
	_arm_ik[side] = ik
	_arm_target[side] = target


## Leva o pulso do braço [param side] até [param wrist] (global) com peso [param weight] (0 = só a animação).
func _place_arm(side: String, wrist: Vector3, weight: float) -> void:
	if not _arm_ik.has(side):
		return
	var target: Node3D = _arm_target[side]
	if not target.is_inside_tree():
		return
	var ik: TwoBoneIK3D = _arm_ik[side]
	if ik.get_target_node(0).is_empty():
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(ik.get_meta(&"pole") as Node3D))
	target.global_position = wrist
	_set_arm_weight(side, weight)


## Peso do IK do braço [param side] (0 desliga).
func _set_arm_weight(side: String, weight: float) -> void:
	if not _arm_ik.has(side):
		return
	var ik: TwoBoneIK3D = _arm_ik[side]
	ik.influence = clampf(weight, 0.0, 1.0)
	ik.active = weight > 0.001


## Passa a seguir a aparência de [param state] (troca na hora e a cada [signal PlayerState.look_changed]).
func bind(state: PlayerState) -> void:
	if _state != null and _state.look_changed.is_connected(_refresh):
		_state.look_changed.disconnect(_refresh)
	_state = state
	if _state != null:
		_state.look_changed.connect(_refresh)
	_refresh()


## Recria os modelos de todos os slots a partir do look atual.
func _refresh() -> void:
	_held_model = null
	for instance: MeshInstance3D in _skinned:
		instance.queue_free()
	_skinned.clear()
	_covers.clear()
	_covers_key = ""
	_hide_body_feet(_state != null and _mounts.has("foot_left") and ItemModels.has_model(String(_state.look.get("feet", ""))))
	var hand_item: String = _state.look.get("hand", "") if _state != null else ""
	if animator != null:
		animator.set_idle_animation(ItemModels.idle_animation(hand_item))
	if _hand_grip != null:
		var holding: bool = not hand_item.is_empty() and _mounts.has("hand")
		_hand_grip.set_grip(holding, holding and (ItemModels.is_two_handed(hand_item) or ItemModels.is_paired(hand_item)))
	for key: String in _mounts:
		var mount: Node3D = _mounts[key]
		for child: Node in mount.get_children():
			child.queue_free()
		var slot: String = MOUNTS[key][0]
		var item_id: String = _state.look.get(slot, "") if _state != null else ""
		if item_id.is_empty():
			continue
		if key == "off_hand" and not ItemModels.is_paired(item_id):
			continue
		var model: Node3D = ItemModels.instantiate(item_id, body_id)
		if model == null:
			continue
		if key == "off_hand":
			# Cópia da arma em par: segue a mão esquerda animada, sem posição de carregar.
			model.basis = ItemModels.grip(item_id)
		elif slot == "hand":
			model.basis = ItemModels.grip(item_id)
			if ItemModels.hold_direction(item_id) != Vector3.ZERO:
				_held_model = model
				_held_id = item_id
				_held_grip = model.basis
				_held_pull = ItemModels.hold_pull(item_id, false)
				_held_direction = Vector3.ZERO
				_carry_weight = 1.0
		elif fit_boxes.has(key) and not ItemModels.is_tailored(item_id, body_id):
			# Malha sob medida já vem do tamanho do corpo: só a genérica é esticada para a caixa.
			_fit(model, fit_boxes[key], slot)
		mount.add_child(model)
		if (slot == "chest" or slot == "feet") and body != null:
			_dress(model, mount, key)
	_sink_covered_skin()


## Afunda a pele que fica embaixo das roupas sob medida ([member _covers]) para ela não atravessar a roupa quando o
## corpo se mexe ([method BodySkinning.covered_mesh]). Parte da malha que [method _hide_body_feet] escolheu.
func _sink_covered_skin() -> void:
	if body == null or _covers.is_empty():
		return
	var key: String = "%d|%d|%s" % [_body_mesh.get_instance_id(), body.mesh.get_instance_id(), _covers_key]
	var variant: ArrayMesh = BodySkinning.covered_mesh(_body_mesh, body.mesh, _covers, key)
	if variant != null:
		body.mesh = variant


## Com calçado ([param hidden] true), o corpo usa a malha com os pés escondidos ([method BodySkinning.feet_hidden_mesh]):
## o pé não aparece por fora do calçado. Sem calçado, a malha original.
func _hide_body_feet(hidden: bool) -> void:
	if body == null:
		return
	if _body_mesh == null:
		_body_mesh = body.mesh
	var wanted: Mesh = _body_mesh
	if hidden:
		BodySkinning.sample(body, _skeleton, _body_mesh)
		var variant: ArrayMesh = BodySkinning.feet_hidden_mesh(body, _skeleton, _body_mesh)
		if variant != null:
			wanted = variant
	if body.mesh != wanted:
		body.mesh = wanted


## Troca o item rígido [param model] (no encaixe [param mount], chave [param key]) por malhas com os pesos do corpo
## ([BodySkinning]). Peito: fica onde o encaixe pela caixa o pôs. Calçado: encaixado pelo pé do corpo.
## Peito sob medida ([method ItemModels.is_tailored], [ART-08]): a malha foi modelada em cima do corpo, no espaço do
## personagem (origem nos pés, metros): fica exatamente onde veio e segue o braço inteiro, como a pele embaixo.
func _dress(model: Node3D, mount: Node3D, key: String) -> void:
	var data: BodySkinning.BodyData = BodySkinning.sample(body, _skeleton, _body_mesh)
	var item_id: String = String(_state.look.get(MOUNTS[key][0], "")) if _state != null else ""
	var tailored: bool = key == "chest" and ItemModels.is_tailored(item_id, body_id)
	var rest: Transform3D
	if tailored:
		# Espaço do personagem (raiz do CharacterModel) → espaço do esqueleto, vezes o próprio item.
		var root: Node3D = get_parent() as Node3D
		rest = _skeleton.global_transform.affine_inverse() * root.global_transform * model.transform
	elif key == "chest":
		# Onde o item fica com o corpo em repouso: repouso do osso × encaixe × item (espaço do esqueleto).
		rest = _skeleton.get_bone_global_rest(_skeleton.find_bone(MOUNTS[key][1])) * mount.transform * model.transform
	else:
		rest = BodySkinning.foot_rest(model, data, _skeleton, "Left" if key == "foot_left" else "Right")
		if rest == Transform3D.IDENTITY:
			return
	var cache_key: String = "%d|%s|%s" % [_body_mesh.get_instance_id(), item_id, key]
	var created: Array[MeshInstance3D] = BodySkinning.skin(model, _skeleton, rest, data, key == "chest" and not tailored, cache_key)
	if created.is_empty():
		return
	_skinned.append_array(created)
	model.visible = false
	if tailored:
		_covers_key += item_id + ";"
		for instance: MeshInstance3D in created:
			_covers.append(instance.mesh)


## Encaixa o item de peito [param model] na caixa [param box] do tronco (espaço do encaixe), a partir do tamanho real
## dele (a escala e a posição da cena do item não importam, só a direção: frente em +Z): largura e profundidade
## esticadas para cobrir o tronco; altura proporcional à largura (túnica comprida continua comprida); topo na gola,
## centrado no tronco. [param slot] fica para itens futuros com caixa (hoje só "chest").
func _fit(model: Node3D, box: AABB, slot: String) -> void:
	var bounds: AABB = ItemModels.local_bounds(model)
	if slot != "chest" or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		return
	var center: Vector3 = box.get_center()
	var width: float = box.size.x / bounds.size.x
	var scale: Vector3 = Vector3(width, width, box.size.z / bounds.size.z)
	var anchor: Vector3 = Vector3(center.x, box.end.y, center.z)
	var top: Vector3 = Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
	model.transform = Transform3D(Basis.from_scale(scale), anchor - top * scale)


## Base com o eixo Y em [param length_axis] e o Z o mais perto possível de [param side_hint].
func _basis_along(length_axis: Vector3, side_hint: Vector3) -> Basis:
	var side: Vector3 = side_hint.normalized() - length_axis * side_hint.normalized().dot(length_axis)
	if side.length() < 0.001:
		side = length_axis.cross(Vector3.RIGHT if absf(length_axis.x) < 0.9 else Vector3.FORWARD)
	side = side.normalized()
	return Basis(length_axis.cross(side), length_axis, side)


## Posição global do osso [param bone_name] na pose atual.
func _bone_position(bone_name: String) -> Vector3:
	var bone: int = _skeleton.find_bone(bone_name)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin if bone >= 0 else _skeleton.global_position
