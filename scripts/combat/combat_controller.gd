class_name CombatController
extends Node
## Liga os gestos da HUD (ataque simples e cartas) ao jogo: alvo fixo, prévia da mira e o pedido da ação.
## Ver mmo-docs [JOGO-02].
##
## - Ataque, toque: pega o alvo mais perto e ataca. Arrastar: mira; soltar sobre alguém fixa o alvo.
## - "Desfocar" (embaixo do ataque), toque: solta o alvo fixo (o servidor para de atacar).
## - Carta, toque: habilidade em si mesmo sai na hora; com mira, vai no alvo fixo (ou para a frente).
##   Arrastar: prévia translúcida saindo do personagem; soltar executa; voltar o dedo à carta cancela.
## - A mira segue o **ponto da tela embaixo do dedo** ([method _finger_ground]): arrastar até o personagem que você vê
##   e soltar em cima dele escolhe ele ([method _unit_under_finger], até [constant PICK_SCREEN_PX] na tela); linha e
##   área vão para o ponto do chão embaixo do dedo, limitado ao alcance.
##
## Ataque e cartas vêm do que está vestido ([InventoryState], mensagem "inventory" do servidor).
## Ataque simples ([JOGO-05]): manda "attack" com o alvo; o servidor bate sozinho quando em alcance.
## Cartas ([JOGO-06]): mandam "cast" ([method _cast]); o servidor valida e aplica o efeito.
## Alvo fixo e relógios seguem o que o servidor confirma.

## Distância máxima (px, na tela) entre o dedo e o personagem para ele contar como "debaixo da mira".
const PICK_SCREEN_PX: float = 70.0
## Altura (m) do ponto do personagem usado para medir a distância na tela (meio do corpo).
const PICK_BODY_HEIGHT: float = 1.0
## Raio (m) em volta do ponto mirado em que um jogador conta como "debaixo da mira".
const TARGET_PICK_RADIUS: float = 1.5
## Toque no ataque: procura o alvo mais perto até esta distância (m).
const TAP_TARGET_RANGE: float = 10.0

var _zone: Zone = null
var _player: LocalPlayer = null
var _hud: Hud = null
var _preview: AimPreview = null
## Ataque simples e as 6 cartas atuais (do que está vestido, [InventoryState]); null = slot vazio.
var _attack: AbilityView = AbilityView.new("punch", "Soco", "Arma", AbilityView.AimType.TARGET, 1.5)
var _abilities: Array[AbilityView] = []
## Id do alvo fixo ("" = nenhum).
var _target_id: String = ""
## Recarga por POSIÇÃO de carta (índice 0..5 → instante em ms em que fica pronta, e a duração total que começou), como
## no servidor ([JOGO-06], Zone.cardSlot): trocar de item não zera — a carta nova na mesma posição espera o que
## faltava da anterior (o relógio continua o mesmo); depois de usada, vale a recarga dela.
var _card_ready_ms: Dictionary[int, int] = {}
var _card_total_s: Dictionary[int, float] = {}
## Golpe do ataque simples em andamento: instante em que acaba (relógio do botão Atacar).
var _attack_ready_ms: int = 0
## Quem está debaixo da mira durante um arrasto de alvo ("" = ninguém).
var _hovered_id: String = ""
## Centro (px, na tela) do botão de onde o arrasto atual começou: dedo = este ponto + deslocamento do arrasto.
var _aim_origin_px: Vector2 = Vector2.ZERO


## Liga nos botões da HUD. Chamar uma vez, depois de adicionar à árvore.
func setup(zone: Zone, player: LocalPlayer, hud: Hud, preview: AimPreview) -> void:
	_zone = zone
	_player = player
	_hud = hud
	_preview = preview

	var attack_button: TouchActionButton = _hud.attack_button
	attack_button.tapped.connect(_on_attack_tapped)
	attack_button.aim_moved.connect(func(offset: Vector2) -> void:
		_aim_origin_px = attack_button.get_global_rect().get_center()
		_on_aim_moved(offset, _attack))
	attack_button.aim_released.connect(func(offset: Vector2) -> void:
		_aim_origin_px = attack_button.get_global_rect().get_center()
		_on_attack_released(offset))
	attack_button.aim_cancelled.connect(_end_aim)
	_hud.clear_target_button.tapped.connect(_on_clear_target_tapped)
	# Cada carta é ligada pelo ÍNDICE: a habilidade dela muda quando o inventário muda.
	for i: int in range(Hud.CARD_COUNT):
		var card: TouchActionButton = _hud.get_card(i)
		card.tapped.connect(_on_card_index_tapped.bind(i))
		card.aim_moved.connect(_on_card_index_moved.bind(i))
		card.aim_released.connect(_on_card_index_released.bind(i))
		card.aim_cancelled.connect(_end_aim)

	var network: Network = Network.instance
	network.inventory_changed.connect(_apply_inventory)
	network.combat_event.connect(_on_combat_event)
	if network.inventory != null:
		_apply_inventory(network.inventory)


## Troca o ataque e as cartas pelo que está vestido agora.
func _apply_inventory(inventory: InventoryState) -> void:
	_attack = inventory.basic_attack()
	_abilities = inventory.cards()
	_hud.set_abilities(_abilities)
	_hud.set_inventory(inventory)
	_refresh_cooldowns()


## Segundos que faltam para a carta da posição [param index] ficar pronta (0 = pronta).
func _cooldown_left(index: int) -> float:
	if not _card_ready_ms.has(index):
		return 0.0
	return maxf(0.0, float(_card_ready_ms[index] - Time.get_ticks_msec()) / 1000.0)


## Começa a recarga da posição [param index] com a recarga de [param ability] e atualiza o relógio nos botões.
func _start_cooldown(index: int, ability: AbilityView) -> void:
	if ability.cooldown_s <= 0.0:
		return
	_card_ready_ms[index] = Time.get_ticks_msec() + int(ability.cooldown_s * 1000.0)
	_card_total_s[index] = ability.cooldown_s
	_refresh_cooldowns()


## Copia a recarga de cada posição para a carta que está nela (mesmo que seja outra habilidade) e o golpe para o Atacar.
func _refresh_cooldowns() -> void:
	var attack_left: float = maxf(0.0, float(_attack_ready_ms - Time.get_ticks_msec()) / 1000.0)
	_hud.attack_button.set_cooldown(attack_left, _attack.cooldown_s)
	for i: int in range(Hud.CARD_COUNT):
		var left: float = _cooldown_left(i) if _ability_at(i) != null else 0.0
		_hud.get_card(i).set_cooldown(left, _card_total_s.get(i, 0.0))


## true (e avisa) se a posição [param index] ainda está recarregando.
func _is_cooling(index: int) -> bool:
	var left: float = _cooldown_left(index)
	if left <= 0.0:
		return false
	var ability: AbilityView = _ability_at(index)
	_hud.show_toast("%s recarrega em %.1f s" % [ability.title if ability != null else "Carta", left])
	return true


func _ability_at(index: int) -> AbilityView:
	return _abilities[index] if index < _abilities.size() else null


func _on_card_index_tapped(index: int) -> void:
	var ability: AbilityView = _ability_at(index)
	if ability != null and not _is_cooling(index):
		_on_card_tapped(ability)


func _on_card_index_moved(offset: Vector2, index: int) -> void:
	_aim_origin_px = _hud.get_card(index).get_global_rect().get_center()
	var ability: AbilityView = _ability_at(index)
	# Recarregando: sem prévia (soltar só avisa).
	if ability != null and _cooldown_left(index) <= 0.0:
		_on_aim_moved(offset, ability)


func _on_card_index_released(offset: Vector2, index: int) -> void:
	_aim_origin_px = _hud.get_card(index).get_global_rect().get_center()
	var ability: AbilityView = _ability_at(index)
	if ability != null and not _is_cooling(index):
		_on_card_released(offset, ability)
	else:
		_end_aim()


## Lançamento meu confirmado pelo servidor ("cast_start"): ataque simples → relógio do Atacar durante o
## golpe; carta → começa a recarga dela. "cast_cancel" (andei durante o lançamento, [JOGO-05]/[JOGO-06]): a carta
## volta pronta (o servidor zerou a recarga e devolveu a mana); o golpe do Atacar some do relógio (recomeça quando
## eu parar no alcance).
func _on_combat_event(event: Dictionary) -> void:
	if Protocol.read_string(event, "source") != Network.instance.player_id:
		return
	var type: String = Protocol.read_string(event, "type")
	var ability_id: String = Protocol.read_string(event, "ability")
	if type == "cast_cancel":
		if ability_id == _attack.id:
			_attack_ready_ms = 0
			_hud.attack_button.set_cooldown(0.0, 0.0)
			return
		var cancelled: int = _index_of(ability_id)
		if cancelled >= 0:
			_card_ready_ms.erase(cancelled)
			_hud.show_toast("%s cancelado (você andou)" % _abilities[cancelled].title)
		_refresh_cooldowns()
		return
	if type != "cast_start":
		return
	if ability_id == _attack.id:
		var duration: float = Protocol.read_float(event, "duration")
		_attack_ready_ms = Time.get_ticks_msec() + int(duration * 1000.0)
		_hud.attack_button.set_cooldown(duration, duration)
		return
	var started: int = _index_of(ability_id)
	if started >= 0:
		_start_cooldown(started, _abilities[started])


## Posição (0..5) da carta com [param ability_id] entre as vestidas, ou -1.
func _index_of(ability_id: String) -> int:
	for i: int in range(_abilities.size()):
		if _abilities[i] != null and _abilities[i].id == ability_id:
			return i
	return -1


func _process(_delta: float) -> void:
	# O alvo fixo de verdade é o do servidor (ele limpa quando o alvo morre ou sai).
	_target_id = Network.instance.attack_target
	_hud.set_target_active(not _target_id.is_empty())
	# Golpe em andamento: o modelo fica virado para o alvo ([JOGO-05]).
	var casting_node: RemotePlayer = _zone.get_target_node(Network.instance.casting_target) if not Network.instance.casting_target.is_empty() else null
	if casting_node != null:
		_player.face_toward(casting_node.global_position, 0.15)
	# Marcador do alvo fixo segue o alvo; some se ele saiu da zona.
	if _hovered_id.is_empty():
		var target: RemotePlayer = _zone.get_target_node(_target_id) if not _target_id.is_empty() else null
		if target != null:
			_preview.show_target(target.global_position)
		else:
			_target_id = ""
			_preview.hide_target()


# --- Ataque simples ---

## Toque: fixa o alvo mais perto e o servidor passa a atacar (não bloqueia na recarga: só troca o alvo).
## Ataque de cura (Livro, [JOGO-09]): o alvo é o aliado mais perto.
func _on_attack_tapped() -> void:
	var heals: bool = _attack.aim_type == AbilityView.AimType.ALLY
	var nearest: RemotePlayer = _nearest_remote(_player.global_position, TAP_TARGET_RANGE, heals)
	if nearest == null:
		_hud.show_toast("Nenhum aliado por perto" if heals else "Ninguém por perto")
		return
	_set_attack_target(nearest)


func _on_attack_released(offset: Vector2) -> void:
	# Quem está embaixo do dedo NA HORA de soltar (o último movimento pode ter sido antes).
	var under: RemotePlayer = _unit_under_finger(offset, _attack.aim_type == AbilityView.AimType.ALLY)
	var picked: String = under.session_id if under != null else _hovered_id
	_end_aim()
	if picked.is_empty():
		_hud.show_toast("Nenhum alvo ali")
		return
	var target: RemotePlayer = _zone.get_target_node(picked)
	if target != null:
		_set_attack_target(target)


## "Desfocar": pede ao servidor para soltar o alvo fixo (attack com alvo vazio, [JOGO-05]). O marcador e o
## botão apagam quando o servidor confirma (alvo vazio no "me").
func _on_clear_target_tapped() -> void:
	if _target_id.is_empty():
		return
	Network.instance.send_attack("")
	_target_id = ""
	_preview.hide_target()
	_hud.show_toast("Alvo solto")


## Pede ao servidor para atacar [param target]. O marcador muda quando o servidor confirma.
func _set_attack_target(target: RemotePlayer) -> void:
	_target_id = target.session_id
	Network.instance.send_attack(target.session_id)
	_hud.show_toast("Alvo: %s" % target.display_name)


# --- Cartas ---

## Toque na carta: em si mesmo/ao redor sai na hora; "no alvo" usa o alvo fixo; direção/área vão na
## direção do alvo fixo ou, sem alvo, para a frente.
func _on_card_tapped(ability: AbilityView) -> void:
	var target: RemotePlayer = _zone.get_target_node(_target_id) if not _target_id.is_empty() else null
	match ability.aim_type:
		AbilityView.AimType.SELF, AbilityView.AimType.AREA_SELF:
			_cast(ability)
		AbilityView.AimType.TARGET:
			if target == null:
				_hud.show_toast("%s: sem alvo (arraste para mirar)" % ability.title)
			else:
				_cast(ability, target.session_id, target.global_position)
		AbilityView.AimType.ALLY:
			# Alvo fixo que é aliado (jogador) recebe; senão é em você ([JOGO-09]).
			if target != null and target in _zone.get_allies():
				_cast(ability, target.session_id, target.global_position)
			else:
				_cast(ability)
		AbilityView.AimType.DIRECTION, AbilityView.AimType.AREA:
			var point: Vector3 = target.global_position if target != null else _player.global_position + _player.get_facing() * maxf(ability.range_m, 3.0)
			_cast(ability, "", point)


## Soltar a carta depois de arrastar: lança no que estava na mira.
func _on_card_released(offset: Vector2, ability: AbilityView) -> void:
	# Quem está embaixo do dedo NA HORA de soltar (o último movimento pode ter sido antes).
	var picks_unit: bool = ability.aim_type == AbilityView.AimType.TARGET or ability.aim_type == AbilityView.AimType.ALLY
	var under: RemotePlayer = _unit_under_finger(offset, ability.aim_type == AbilityView.AimType.ALLY) if picks_unit else null
	var picked: String = under.session_id if under != null else _hovered_id
	_end_aim()
	var aim: Vector3 = _aim_point(offset, ability)
	match ability.aim_type:
		AbilityView.AimType.SELF, AbilityView.AimType.AREA_SELF:
			_cast(ability)
		AbilityView.AimType.TARGET:
			var target: RemotePlayer = _zone.get_target_node(picked)
			if target == null:
				_hud.show_toast("%s: ninguém na mira" % ability.title)
			else:
				_cast(ability, target.session_id, target.global_position)
		AbilityView.AimType.ALLY:
			# Ninguém na mira: em você.
			var ally: RemotePlayer = _zone.get_target_node(picked)
			if ally == null:
				_cast(ability)
			else:
				_cast(ability, ally.session_id, ally.global_position)
		AbilityView.AimType.DIRECTION, AbilityView.AimType.AREA:
			_cast(ability, "", aim)


# --- Prévia da mira (ataque e cartas) ---

func _on_aim_moved(offset: Vector2, ability: AbilityView) -> void:
	var origin: Vector3 = _player.global_position
	var aim: Vector3 = _aim_point(offset, ability)
	var flat: Vector3 = Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
	var direction: Vector3 = flat.normalized() if flat.length() > 0.01 else _player.get_facing()
	_hovered_id = ""
	match ability.aim_type:
		AbilityView.AimType.TARGET, AbilityView.AimType.ALLY:
			_preview.show_circle(aim, TARGET_PICK_RADIUS, origin)
			var hovered: RemotePlayer = _unit_under_finger(offset, ability.aim_type == AbilityView.AimType.ALLY)
			if hovered != null:
				_hovered_id = hovered.session_id
				_preview.show_target(hovered.global_position)
			else:
				_preview.hide_target()
		AbilityView.AimType.DIRECTION:
			_preview.show_line(origin, direction, ability.range_m, maxf(0.3, ability.radius_m))
		AbilityView.AimType.AREA:
			_preview.show_circle(aim, ability.radius_m, origin)
		AbilityView.AimType.AREA_SELF:
			_preview.show_circle(origin, ability.radius_m)
		AbilityView.AimType.SELF:
			_preview.hide_aim()


func _end_aim() -> void:
	_hovered_id = ""
	_preview.hide_aim()


## Ponto no chão para onde a mira vai: o ponto embaixo do dedo ([method _finger_ground]) ou, em linha/área, o inimigo
## embaixo do dedo. Área: limitado ao alcance da habilidade (o servidor limita igual). Alvo/aliado/linha: sem limite
## (a linha só usa a direção).
func _aim_point(offset: Vector2, ability: AbilityView) -> Vector3:
	var origin: Vector3 = _player.global_position
	var point: Vector3 = _finger_ground(offset)
	# Linha/área com um inimigo embaixo do dedo: mira nele. O dedo fica em cima do CORPO; com a câmera inclinada, o
	# chão embaixo do dedo cai atrás dele e a linha sairia torta (passava do lado).
	if ability.aim_type == AbilityView.AimType.DIRECTION or ability.aim_type == AbilityView.AimType.AREA:
		var enemy: RemotePlayer = _unit_under_finger(offset, false)
		if enemy != null:
			point = enemy.global_position
	if ability.aim_type == AbilityView.AimType.AREA and ability.range_m > 0.0:
		var flat: Vector3 = Vector3(point.x - origin.x, 0.0, point.z - origin.z)
		if flat.length() > ability.range_m:
			point = origin + flat.normalized() * ability.range_m
	return point


## Ponto do chão (plano na altura do jogador) embaixo do dedo, que está em [member _aim_origin_px] + [param offset]
## na tela. Sem câmera: o próprio jogador.
func _finger_ground(offset: Vector2) -> Vector3:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if camera == null:
		return _player.global_position
	var finger: Vector2 = _aim_origin_px + offset
	var hit: Variant = Plane(Vector3.UP, _player.global_position.y).intersects_ray(camera.project_ray_origin(finger), camera.project_ray_normal(finger))
	return hit if hit is Vector3 else _player.global_position


## Quem está embaixo do dedo na tela: o mais perto do dedo (meio do corpo projetado na tela) até
## [constant PICK_SCREEN_PX]. [param allies] true: entre os aliados; senão entre os alvos de ataque.
func _unit_under_finger(offset: Vector2, allies: bool) -> RemotePlayer:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if camera == null:
		return null
	var finger: Vector2 = _aim_origin_px + offset
	var best: RemotePlayer = null
	var best_distance: float = PICK_SCREEN_PX
	for remote: RemotePlayer in (_zone.get_allies() if allies else _zone.get_targetables()):
		var body: Vector3 = remote.global_position + Vector3.UP * PICK_BODY_HEIGHT
		if camera.is_position_behind(body):
			continue
		var distance: float = camera.unproject_position(body).distance_to(finger)
		if distance <= best_distance:
			best = remote
			best_distance = distance
	return best


## Alvo (boneco/monstro, ou jogador se a zona tem PvP) mais perto de [param point] até
## [param max_distance] metros (no plano), ou null. [param allies] true: entre os aliados (outros jogadores,
## para cura/escudo, [JOGO-09]).
func _nearest_remote(point: Vector3, max_distance: float, allies: bool = false) -> RemotePlayer:
	var best: RemotePlayer = null
	var best_distance: float = max_distance
	for remote: RemotePlayer in (_zone.get_allies() if allies else _zone.get_targetables()):
		var offset: Vector3 = remote.global_position - point
		var distance: float = Vector2(offset.x, offset.z).length()
		if distance <= best_distance:
			best = remote
			best_distance = distance
	return best


## Pede ao servidor para lançar [param ability] ([JOGO-06]): "no alvo" com [param target_id]; direção
## (vetor até [param point]) ou área (o próprio [param point]). O servidor confere tudo; o relógio da carta
## só começa quando ele confirma ("cast_start"), e a recusa aparece como aviso. Enquanto isso, o modelo
## já vira para onde a habilidade vai (o servidor também vira, para todos).
func _cast(ability: AbilityView, target_id: String = "", point: Vector3 = Vector3.INF) -> void:
	var origin: Vector3 = _player.global_position
	# Investida/Disparada: predição local na fila de passos ([JOGO-07]). Confere recarga e mana antes,
	# para não prever algo que o servidor vai recusar.
	if ability.is_movement():
		if _is_cooling(_index_of(ability.id)):
			return
		if Network.instance.mana < ability.mana_cost:
			_hud.show_toast("Mana insuficiente.")
			return
		var direction: Vector3 = (point - origin) if point != Vector3.INF else _player.get_facing()
		if _player.cast_movement(ability, direction.x, direction.z):
			_player.predict_action(ability.id, 0.0)
		return
	if point != Vector3.INF:
		_player.face_toward(point, maxf(ability.cast_time_s, 0.3))
	# Pronta e com mana: já anima no toque ([JOGO-08]); o servidor ainda pode recusar (aí a animação para).
	if _cooldown_left(_index_of(ability.id)) <= 0.0 and Network.instance.mana >= ability.mana_cost:
		_player.predict_action(ability.id, ability.cast_time_s)
	match ability.aim_type:
		AbilityView.AimType.DIRECTION:
			Network.instance.send_cast(ability.id, "", point.x - origin.x, point.z - origin.z)
		AbilityView.AimType.AREA:
			Network.instance.send_cast(ability.id, "", point.x, point.z)
		_:
			Network.instance.send_cast(ability.id, target_id)
