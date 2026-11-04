class_name CombatController
extends Node
## Liga os gestos da HUD (ataque simples e cartas) ao jogo: alvo fixo, prévia da mira e o pedido da ação.
## Ver mmo-docs [JOGO-02].
##
## - Ataque, toque: pega o alvo mais perto e ataca. Arrastar: mira; soltar sobre alguém fixa o alvo.
## - "Desfocar" (embaixo do ataque), toque: solta o alvo fixo (o servidor para de atacar).
## - Carta, toque: habilidade em si mesmo sai na hora; com mira, vai no alvo fixo (ou para a frente).
##   Arrastar: prévia translúcida saindo do personagem; soltar executa; voltar o dedo à carta cancela.
##
## Ataque e cartas vêm do que está vestido ([InventoryState], mensagem "inventory" do servidor).
## Ataque simples ([JOGO-05]): manda "attack" com o alvo; o servidor bate sozinho quando em alcance.
## Cartas ([JOGO-06]): mandam "cast" ([method _cast]); o servidor valida e aplica o efeito.
## Alvo fixo e relógios seguem o que o servidor confirma.

## Arrastar o dedo esta distância (px) a partir do botão = mira no alcance máximo.
const MAX_AIM_DRAG_PX: float = 220.0
## Ao arrastar o ataque, até onde (m) dá para escolher o alvo fixo.
const TARGET_PICK_RANGE: float = 15.0
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
## Recarga por HABILIDADE (id → instante em ms em que fica pronta). Por id, não por carta: trocar de
## item e voltar mantém o relógio. Provisório no cliente; no passo 3 o servidor confirma e recusa antes da hora.
var _ready_at_ms: Dictionary[String, int] = {}
## Quem está debaixo da mira durante um arrasto de alvo ("" = ninguém).
var _hovered_id: String = ""


## Liga nos botões da HUD. Chamar uma vez, depois de adicionar à árvore.
func setup(zone: Zone, player: LocalPlayer, hud: Hud, preview: AimPreview) -> void:
	_zone = zone
	_player = player
	_hud = hud
	_preview = preview

	var attack_button: TouchActionButton = _hud.attack_button
	attack_button.tapped.connect(_on_attack_tapped)
	attack_button.aim_moved.connect(func(offset: Vector2) -> void: _on_aim_moved(offset, _attack))
	attack_button.aim_released.connect(_on_attack_released)
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


## Segundos que faltam para [param ability] ficar pronta (0 = pronta).
func _cooldown_left(ability: AbilityView) -> float:
	if not _ready_at_ms.has(ability.id):
		return 0.0
	return maxf(0.0, float(_ready_at_ms[ability.id] - Time.get_ticks_msec()) / 1000.0)


## Começa a recarga de [param ability] e atualiza o relógio nos botões.
func _start_cooldown(ability: AbilityView) -> void:
	if ability.cooldown_s <= 0.0:
		return
	_ready_at_ms[ability.id] = Time.get_ticks_msec() + int(ability.cooldown_s * 1000.0)
	_refresh_cooldowns()


## Copia a recarga de cada habilidade para o botão que a mostra (cartas e ataque).
func _refresh_cooldowns() -> void:
	_hud.attack_button.set_cooldown(_cooldown_left(_attack), _attack.cooldown_s)
	for i: int in range(Hud.CARD_COUNT):
		var ability: AbilityView = _ability_at(i)
		_hud.get_card(i).set_cooldown(_cooldown_left(ability) if ability != null else 0.0, ability.cooldown_s if ability != null else 0.0)


## true (e avisa) se [param ability] ainda está recarregando.
func _is_cooling(ability: AbilityView) -> bool:
	var left: float = _cooldown_left(ability)
	if left <= 0.0:
		return false
	_hud.show_toast("%s recarrega em %.1f s" % [ability.title, left])
	return true


func _ability_at(index: int) -> AbilityView:
	return _abilities[index] if index < _abilities.size() else null


func _on_card_index_tapped(index: int) -> void:
	var ability: AbilityView = _ability_at(index)
	if ability != null and not _is_cooling(ability):
		_on_card_tapped(ability)


func _on_card_index_moved(offset: Vector2, index: int) -> void:
	var ability: AbilityView = _ability_at(index)
	# Recarregando: sem prévia (soltar só avisa).
	if ability != null and _cooldown_left(ability) <= 0.0:
		_on_aim_moved(offset, ability)


func _on_card_index_released(offset: Vector2, index: int) -> void:
	var ability: AbilityView = _ability_at(index)
	if ability != null and not _is_cooling(ability):
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
		_ready_at_ms.erase(ability_id)
		if ability_id == _attack.id:
			_hud.attack_button.set_cooldown(0.0, 0.0)
			return
		_refresh_cooldowns()
		for ability: AbilityView in _abilities:
			if ability != null and ability.id == ability_id:
				_hud.show_toast("%s cancelado (você andou)" % ability.title)
		return
	if type != "cast_start":
		return
	if ability_id == _attack.id:
		var duration: float = Protocol.read_float(event, "duration")
		_ready_at_ms[ability_id] = Time.get_ticks_msec() + int(duration * 1000.0)
		_hud.attack_button.set_cooldown(duration, duration)
		return
	for ability: AbilityView in _abilities:
		if ability != null and ability.id == ability_id:
			_start_cooldown(ability)
			return


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


func _on_attack_released(_offset: Vector2) -> void:
	var picked: String = _hovered_id
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
	var picked: String = _hovered_id
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
			var hovered: RemotePlayer = _nearest_remote(aim, TARGET_PICK_RADIUS, ability.aim_type == AbilityView.AimType.ALLY)
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


## Ponto no chão para onde o dedo aponta: direção do arrasto (relativa à câmera) e distância
## proporcional ao arrasto, até o alcance da habilidade (ou [constant TARGET_PICK_RANGE] para alvo).
func _aim_point(offset: Vector2, ability: AbilityView) -> Vector3:
	var picks_unit: bool = ability.aim_type == AbilityView.AimType.TARGET or ability.aim_type == AbilityView.AimType.ALLY
	var reach: float = TARGET_PICK_RANGE if picks_unit else ability.range_m
	var screen_direction: Vector3 = Vector3(offset.x, 0.0, offset.y).rotated(Vector3.UP, _player.get_camera_yaw())
	var amount: float = clampf(offset.length() / MAX_AIM_DRAG_PX, 0.0, 1.0)
	var world_direction: Vector3 = screen_direction.normalized() if screen_direction.length() > 0.01 else _player.get_facing()
	return _player.global_position + world_direction * reach * amount


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
		if _is_cooling(ability):
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
	if _cooldown_left(ability) <= 0.0 and Network.instance.mana >= ability.mana_cost:
		_player.predict_action(ability.id, ability.cast_time_s)
	match ability.aim_type:
		AbilityView.AimType.DIRECTION:
			Network.instance.send_cast(ability.id, "", point.x - origin.x, point.z - origin.z)
		AbilityView.AimType.AREA:
			Network.instance.send_cast(ability.id, "", point.x, point.z)
		_:
			Network.instance.send_cast(ability.id, target_id)
