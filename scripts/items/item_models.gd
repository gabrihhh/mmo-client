class_name ItemModels
extends RefCounted
## Liga cada item ao modelo 3D que aparece no boneco quando ele está vestido ([ART-02]) e ao jeito de segurar.
##
## Cada item tem uma pasta em res://assets/itens/<slot>/<nome>/ ([ART-08]) com uma malha feita para cada corpo:
## male/<slot>-<nome>.tscn (ou .glb) e female/<slot>-<nome>.tscn. A cena (.tscn) acerta escala e origem em volta do .glb.
## Corpo sem malha própria usa a do outro corpo (reserva); item sem malha nenhuma não aparece no boneco.
## Item novo: crie a pasta (mesma arquitetura), ponha as malhas e adicione a linha itemId → pasta.
## Itens de peito e pés copiam os pesos do corpo ([EquipmentView], [ART-04]); o de pés é um pé só (o direito espelha).
## ATENÇÃO: os itemIds vêm de mmo-server/src/items/catalog.ts; o mmo-docs/tools/gerar_catalogo_itens.py lê esta tabela
## para escrever o index.md de cada pasta.

## itemId → pasta do item (res://assets/itens/<slot>/<nome>; slot: hand, head, chest, boot).
const _FOLDERS: Dictionary[String, String] = {
	"training_sword": "res://assets/itens/hand/training-sword",
	"training_staff": "res://assets/itens/hand/training-staff",
	"training_hood": "res://assets/itens/head/training",
	"training_vest": "res://assets/itens/chest/training",
	"training_boots": "res://assets/itens/boot/training",
	"arcane_staff": "res://assets/itens/hand/mage",
	"mage_hat": "res://assets/itens/head/mage",
	"mage_tunic": "res://assets/itens/chest/mage",
	"mage_shoes": "res://assets/itens/boot/mage",
	"knight_sword": "res://assets/itens/hand/knight",
	"knight_helm": "res://assets/itens/head/knight",
	"knight_plate": "res://assets/itens/chest/knight",
	"knight_greaves": "res://assets/itens/boot/knight",
	"ranger_crossbow": "res://assets/itens/hand/ranger",
	"ranger_hood": "res://assets/itens/head/ranger",
	"ranger_jerkin": "res://assets/itens/chest/ranger",
	"ranger_boots": "res://assets/itens/boot/ranger",
	"assassin_daggers": "res://assets/itens/hand/assassin",
	"assassin_hood": "res://assets/itens/head/assassin",
	"assassin_vest": "res://assets/itens/chest/assassin",
	"assassin_boots": "res://assets/itens/boot/assassin",
	"healer_tome": "res://assets/itens/hand/healer",
	"healer_circlet": "res://assets/itens/head/healer",
	"healer_robe": "res://assets/itens/chest/healer",
	"healer_sandals": "res://assets/itens/boot/healer",
}
## Corpos com pasta própria dentro da pasta do item. ATENÇÃO: = CharacterBodies.SCENES / BODY_TYPES do servidor.
const BODIES: Array[String] = [Protocol.BODY_MALE, Protocol.BODY_FEMALE]

## Cache de [method model_path]: "itemId|corpo" → caminho ("" = sem malha). Evita perguntar ao disco a cada troca.
static var _path_cache: Dictionary[String, String] = {}

## Como a mão segura (giro em X, graus, a partir do osso da mão). Os modelos de segurar têm o comprimento em +Y:
## 90 = "lâmina para a frente" (espada: com o braço caído aponta para a frente); 0 = em pé (cajado).
const _GRIP_PITCH: Dictionary[String, float] = {
	"training_staff": 0.0,
	"arcane_staff": 0.0,
}
## Pegada padrão (armas de lâmina).
const DEFAULT_GRIP_PITCH: float = 90.0
## Como cada item de segurar se acomoda na mão: [direção de descanso (espaço do personagem: +Z frente, +Y cima),
## puxão fora de ação, puxão durante uma ação, durante a ação segue o antebraço?]. Seguindo o antebraço, o puxão da
## ação vai na direção cotovelo → mão (a lâmina continua o braço: sobe na preparação, desce no golpe). A cada quadro o comprimento (+Y) do item é somado a direção × puxão
## (puxão 0 = preso ao osso da mão). As animações do Meshy são de mão vazia: o pulso gira e, preso ao osso, a espada
## apontava para cima e o cajado deitava para trás correndo (ou ficava de ponta-cabeça ao erguer o braço). Puxão > 1
## garante a direção; durante a ação a espada é puxada pouco, para o golpe seguir a mão.
const _HOLD: Dictionary[String, Array] = {
	"training_sword": [Vector3(0.0, 0.55, 1.0), 2.0, 2.0, true],
	"training_staff": [Vector3(0.0, 1.0, 0.3), 4.0, 4.0, false],
	"knight_sword": [Vector3(0.0, 0.55, 1.0), 2.0, 2.0, true],
	"arcane_staff": [Vector3(0.0, 1.0, 0.3), 4.0, 4.0, false],
	"ranger_crossbow": [Vector3(0.0, 0.15, 1.0), 3.0, 3.0, false],
}
## Posição de carregar (parado/correndo), no espaço do personagem (m; +Z frente, +Y cima, lado direito = −X):
## [onde fica a pegada da mão direita, direção do comprimento]. As mãos vão até a arma por IK ([EquipmentView]).
## Perto o bastante do ombro para o braço alcançar (~0,45 m do ombro).
const _CARRY: Dictionary[String, Array] = {
	"training_sword": [Vector3(-0.10, 1.10, 0.30), Vector3(0.0, 0.6, 1.0)],
	"training_staff": [Vector3(-0.24, 1.12, 0.26), Vector3(0.0, 1.0, 0.18)],
	"knight_sword": [Vector3(-0.10, 1.10, 0.30), Vector3(0.0, 0.6, 1.0)],
	"arcane_staff": [Vector3(-0.24, 1.12, 0.26), Vector3(0.0, 1.0, 0.18)],
	"ranger_crossbow": [Vector3(-0.12, 1.12, 0.32), Vector3(0.0, 0.1, 1.0)],
}
## Postura parada por arma na mão ([CharacterAnimator.set_idle_animation]); sem linha = "idle".
const _IDLE: Dictionary[String, String] = {
	"training_sword": "idle_sword",
	"training_staff": "idle_staff",
	"knight_sword": "idle_sword",
	"arcane_staff": "idle_staff",
}
## Armas de duas mãos: onde a mão esquerda segura (m, no espaço do modelo do item: comprimento em +Y, origem na mão
## direita). A mão esquerda vai até lá por IK ([EquipmentView]).
const _OFF_HAND_GRIP: Dictionary[String, Vector3] = {
	"training_sword": Vector3(0.0, -0.11, 0.0),
	"knight_sword": Vector3(0.0, -0.09, 0.0),
}
## Itens de mão que FLUTUAM perto do personagem em vez de ficar na mão ([EquipmentView], [ART-09]): a mão fica
## vazia e o item paira, balançando de leve. Durante um lançamento ([method EquipmentView.set_casting]) a blend shape
## dele vai a 1 (ex.: o livro abre) e ele vai para a posição de lançamento. O livro fica NA FRENTE do personagem (à
## altura da cintura, ~0,5 m à frente: aberto, as mãos da animação não alcançam). Valor: [posição parado, posição
## lançando, nome da blend shape] — posições no espaço do personagem (m; +Z frente, +Y cima, lado direito = −X), onde fica a
## origem do modelo (a base do livro). O modelo vira a sua frente (+Z, onde fica quem lê) para o peito do personagem.
## A malha vem do Blender sem corpo no nome (`hand-healer`), igual para os dois corpos.
const _FLOATING: Dictionary[String, Array] = {
	"healer_tome": [Vector3(0.0, 1.0, 0.45), Vector3(0.0, 1.0, 0.55), "aberto"],
}
## Armas que vêm em PAR (duas adagas): o mesmo modelo também aparece na mão esquerda, espelhado, seguindo a mão
## animada ([EquipmentView]).
const _PAIRED: Array[String] = ["assassin_daggers"]


## Começa a carregar, em segundo plano, os modelos de todos os itens (chamar ao abrir a zona). Sem isso, a primeira
## vez que um item aparece (alguém veste, o atirador de teste troca de conjunto) o jogo para para ler o modelo e as
## texturas do disco — no celular, um engasgo visível. [method instantiate] usa o que já carregou (ou espera terminar).
static func preload_all() -> void:
	for item_id: String in _FOLDERS:
		for body: String in BODIES:
			var path: String = model_path(item_id, body)
			if not path.is_empty() and not ResourceLoader.has_cached(path):
				ResourceLoader.load_threaded_request(path)


## Pasta do item [param item_id] (res://assets/itens/<slot>/<nome>), ou "" se ele não tiver pasta.
static func folder(item_id: String) -> String:
	return _FOLDERS.get(item_id, "")


## Cena da malha de [param item_id] feita para o corpo [param body] ("male"/"female"): o .tscn da pasta do corpo
## (ou o .glb, se não tiver cena). Sem malha desse corpo, a do outro corpo (reserva). "" = o item não tem malha.
static func model_path(item_id: String, body: String) -> String:
	var key: String = "%s|%s" % [item_id, body]
	if _path_cache.has(key):
		return _path_cache[key]
	var result: String = ""
	var item_folder: String = folder(item_id)
	if not item_folder.is_empty():
		# Nome do arquivo = "<slot>-<nome>", das duas últimas partes da pasta (ex.: head/healer → head-healer).
		var file_name: String = "%s-%s" % [item_folder.get_base_dir().get_file(), item_folder.get_file()]
		var order: Array[String] = [body]
		for other: String in BODIES:
			if other != body:
				order.append(other)
		for candidate_body: String in order:
			for extension: String in ["tscn", "glb"]:
				var path: String = "%s/%s/%s.%s" % [item_folder, candidate_body, file_name, extension]
				if result.is_empty() and ResourceLoader.exists(path):
					result = path
	_path_cache[key] = result
	return result


## true se a malha de [param item_id] para [param body] é **sob medida** ([ART-08]): um .glb direto na pasta do próprio
## corpo (sem .tscn), modelado em cima dele no Blender, no espaço do personagem (origem nos pés, metros, frente +Z).
## O jogo não estica (sem encaixe pela caixa) e, no peito, a roupa segue o braço inteiro. A genérica (Meshy, com
## .tscn de escala/origem, ou cópia de outro corpo) é encaixada como antes ([ART-04]). Hoje vale para peito e cabeça
## (cabeça: peça rígida que segue o osso Head, no lugar em que foi modelada) e para os itens de mão que flutuam
## ([method floats]; esses vêm no espaço do próprio objeto, a posição é a de [member _FLOATING]).
static func is_tailored(item_id: String, body: String) -> bool:
	var path: String = model_path(item_id, body)
	return path.ends_with(".glb") and path.get_base_dir().get_file() == body


## true se [param item_id] tem malha para algum corpo (ex.: as botas de treino ainda não têm).
static func has_model(item_id: String) -> bool:
	return not model_path(item_id, Protocol.BODY_MALE).is_empty()


## Cria a malha do item [param item_id] para o corpo [param body], ou null se ele não tiver malha.
static func instantiate(item_id: String, body: String) -> Node3D:
	var path: String = model_path(item_id, body)
	if path.is_empty():
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("Modelo do item %s não carregou: %s" % [item_id, path])
		return null
	return scene.instantiate() as Node3D


## Caixa (m) de todas as malhas de [param root], no espaço de [param root] (inclui as transformações dos filhos).
static func local_bounds(root: Node3D) -> AABB:
	return _bounds(root, Transform3D.IDENTITY)


static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	if node is MeshInstance3D:
		result = xform * (node as MeshInstance3D).get_aabb()
		found = true
	for child: Node in node.get_children():
		var child_xform: Transform3D = xform * (child as Node3D).transform if child is Node3D else xform
		var box: AABB = _bounds(child, child_xform)
		if box.size == Vector3.ZERO:
			continue
		result = box if not found else result.merge(box)
		found = true
	return result


## Rotação do item na mão (no espaço do osso da mão).
static func grip(item_id: String) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(_GRIP_PITCH.get(item_id, DEFAULT_GRIP_PITCH)))


## Direção de descanso do item [param item_id] na mão (espaço do personagem, normalizada); zero = sem correção.
static func hold_direction(item_id: String) -> Vector3:
	if not _HOLD.has(item_id):
		return Vector3.ZERO
	var direction: Vector3 = _HOLD[item_id][0]
	return direction.normalized()


## Quanto o item [param item_id] é puxado para a direção de descanso: fora de ação ([param acting] false) ou durante.
static func hold_pull(item_id: String, acting: bool) -> float:
	if not _HOLD.has(item_id):
		return 0.0
	return float(_HOLD[item_id][2 if acting else 1])


## Animação parada do personagem com [param item_id] na mão ("idle" se a arma não tiver postura própria).
static func idle_animation(item_id: String) -> String:
	return _IDLE.get(item_id, "idle")


## true se [param item_id] é um par (uma cópia espelhada vai na mão esquerda).
static func is_paired(item_id: String) -> bool:
	return item_id in _PAIRED


## true se [param item_id] flutua ao lado do personagem em vez de ficar na mão ([member _FLOATING]).
static func floats(item_id: String) -> bool:
	return _FLOATING.has(item_id)


## Onde o item flutuante [param item_id] fica (espaço do personagem, m): parado ([param casting] false) ou lançando.
static func float_position(item_id: String, casting: bool) -> Vector3:
	if not _FLOATING.has(item_id):
		return Vector3.ZERO
	var position: Vector3 = _FLOATING[item_id][1 if casting else 0]
	return position


## Blend shape que o item flutuante [param item_id] liga durante o lançamento ("" = nenhuma).
static func float_blend_shape(item_id: String) -> String:
	return String(_FLOATING[item_id][2]) if _FLOATING.has(item_id) else ""


## true se [param item_id] é segurado com as duas mãos ([method off_hand_grip]).
static func is_two_handed(item_id: String) -> bool:
	return _OFF_HAND_GRIP.has(item_id)


## true se, durante uma ação, o item [param item_id] segue a direção do antebraço (e não a de descanso).
static func follows_forearm_in_action(item_id: String) -> bool:
	return _HOLD.has(item_id) and bool(_HOLD[item_id][3])


## Ponto do item [param item_id] onde a mão esquerda segura (espaço do modelo do item, m).
static func off_hand_grip(item_id: String) -> Vector3:
	return _OFF_HAND_GRIP.get(item_id, Vector3.ZERO)


## Posição de carregar de [param item_id] (espaço do personagem): origem = pegada da mão direita, eixo Y = comprimento.
## Transform3D() = o item não tem (segue a mão animada).
static func carry(item_id: String) -> Transform3D:
	if not _CARRY.has(item_id):
		return Transform3D()
	var grip_point: Vector3 = _CARRY[item_id][0]
	var direction: Vector3 = _CARRY[item_id][1]
	var length_axis: Vector3 = direction.normalized()
	var side: Vector3 = Vector3.RIGHT - length_axis * length_axis.x
	return Transform3D(Basis(side.normalized(), length_axis, side.normalized().cross(length_axis)), grip_point)
