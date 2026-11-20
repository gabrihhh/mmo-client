class_name CombatController
extends Node
## Liga os gestos da HUD (ataque simples e cartas) ao jogo: prévia da mira e o pedido da ação.
## Ver mmo-docs [JOGO-02], [JOGO-05].
##
## - Ataque (⚔), golpe livre SEM alvo fixo ([JOGO-05]): toque = golpe na direção do inimigo mais perto (ou para a
##   frente); arrastar = mostra o formato do golpe (leque/linha) na direção do arrasto e solta ao largar o dedo. Um golpe
##   por toque; enquanto um golpe está sendo executado, outro não sai (o toque é ignorado). Dá para andar batendo.
## - Carta, toque: habilidade em si mesmo sai na hora; com mira, vai no inimigo mais perto dentro do alcance dela
##   (aliado: em você). Arrastar: prévia translúcida saindo do personagem; soltar executa; voltar o dedo à carta cancela.
## - O desenho da mira **sai de baixo do personagem** e anda como um joystick: a direção do arrasto (relativa à câmera)
##   e a distância proporcional ao arrasto ([constant MAX_AIM_DRAG_PX] = alcance máximo). **O efeito cai exatamente onde
##   o desenho está** ([method _aim_point] é a mesma conta na prévia e no soltar): alvo/aliado = quem está dentro do
##   círculo desenhado; linha = direção desenhada; área = círculo desenhado.
##
## Ataque e cartas vêm do que está vestido ([InventoryState], mensagem "inventory" do servidor).
## Ataque simples ([JOGO-05]): manda "cast" com o id do ataque da arma e a direção ([method _swing]); o servidor aplica
## na hora. Cartas ([JOGO-06]): mandam "cast" ([method _cast]); o servidor valida e aplica o efeito.
## Relógios seguem o que o servidor confirma.

## Arrastar o dedo esta distância (px) a partir do botão = mira no alcance máximo.
const MAX_AIM_DRAG_PX: float = 220.0
## Cartas de alvo/aliado sem alcance: até onde (m) o círculo de mira vai. As outras vão só até o alcance delas (o
## círculo nunca mostra alguém que o servidor recusaria por "fora de alcance").
const TARGET_PICK_RANGE: float = 15.0
## Raio (m) em volta do ponto mirado em que um jogador conta como "debaixo da mira".
const TARGET_PICK_RADIUS: float = 1.5
## Toque no ⚔: mira no inimigo mais perto até o alcance do golpe + esta folga (m) — o corpo a corpo vira para quem
## está chegando — e nunca menos que [constant TAP_AIM_MIN_RANGE] m. Ninguém: golpe para a frente.
const TAP_AIM_MARGIN: float = 2.0
const TAP_AIM_MIN_RANGE: float = 4.0

var _zone: Zone = null
var _player: LocalPlayer = null
var _hud: Hud = null
var _preview: AimPreview = null
## Ataque simples e as 6 cartas atuais (do que está vestido, [InventoryState]); null = slot vazio.
var _attack: AbilityView = AbilityView.new("punch", "Soco", "Arma", AbilityView.AimType.DIRECTION, 1.5)
var _abilities: Array[AbilityView] = []
## Recarga por POSIÇÃO de carta (índice 0..5 → instante em ms em que fica pronta, e a duração total que começou), como
## no servidor ([JOGO-06], Zone.cardSlot): trocar de item não zera — a carta nova na mesma posição espera o que
## faltava da anterior (o relógio continua o mesmo); depois de usada, vale a recarga dela.
var _card_ready_ms: Dictionary[int, int] = {}
var _card_total_s: Dictionary[int, float] = {}
## Golpe do ataque simples em execução: instante em que acaba (relógio do ⚔ e trava de um golpe por vez) e quando o
## último foi pedido (o tempo confirmado pelo servidor conta a partir daí, sem somar o atraso da rede).
var _attack_ready_ms: int = 0
var _attack_sent_ms: int = 0
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
	var ability: AbilityView = _ability_at(index)
	# Recarregando: sem prévia (soltar só avisa).
	if ability != null and _cooldown_left(index) <= 0.0:
		_on_aim_moved(offset, ability)


func _on_card_index_released(offset: Vector2, index: int) -> void:
	var ability: AbilityView = _ability_at(index)
	if ability != null and not _is_cooling(index):
		_on_card_released(offset, ability)
	else:
		_end_aim()


## Lançamento meu confirmado pelo servidor ("cast_start"): ataque simples → acerta o relógio do ⚔ com o tempo de
## execução do servidor (já com Velocidade de ataque); carta → começa a recarga dela. "cast_cancel" (andei durante o
## lançamento da carta, [JOGO-06]): a carta volta pronta (o servidor zerou a recarga e devolveu a mana).
func _on_combat_event(event: Dictionary) -> void:
	var type: String = Protocol.read_string(event, "type")
	if type == "death" and Protocol.read_string(event, "id") == Network.instance.player_id:
		_hud.cast_bar.stop()
		return
	if Protocol.read_string(event, "source") != Network.instance.player_id:
		return
	var ability_id: String = Protocol.read_string(event, "ability")
	if type == "cast_start":
		_show_cast_bar(event, ability_id)
	if type == "cast_cancel":
		_hud.cast_bar.stop()
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
		_attack_ready_ms = _attack_sent_ms + int(duration * 1000.0)
		var left: float = maxf(0.0, float(_attack_ready_ms - Time.get_ticks_msec()) / 1000.0)
		_hud.attack_button.set_cooldown(left, duration)
		return
	var started: int = _index_of(ability_id)
	if started >= 0:
		_start_cooldown(started, _abilities[started])


## Barra de carregamento ([CastBar], [CLI-08]) do lançamento confirmado em [param event] ("cast_start"): ícone da carta
## e o tempo até a ação sair — no projétil, até o tiro sair da mão ("release" s antes do fim). Investida/Disparada e
## o ataque simples ("instant": sai na hora, [JOGO-05]) não carregam: sem barra.
func _show_cast_bar(event: Dictionary, ability_id: String) -> void:
	var seconds: float = Protocol.read_float(event, "duration") - Protocol.read_float(event, "release")
	if ability_id == _attack.id or event.has("instant"):
		return
	var index: int = _index_of(ability_id)
	if index >= 0 and _abilities[index].is_movement():
		return
	_hud.cast_bar.start(ItemIcons.ability(ability_id), seconds)


## Posição (0..5) da carta com [param ability_id] entre as vestidas, ou -1.
func _index_of(ability_id: String) -> int:
	for i: int in range(_abilities.size()):
		if _abilities[i] != null and _abilities[i].id == ability_id:
			return i
	return -1


func _process(_delta: float) -> void:
	# Carta "no alvo" em lançamento: o modelo fica virado para o alvo ([JOGO-05]).
	var casting_node: RemotePlayer = _zone.get_target_node(Network.instance.casting_target) if not Network.instance.casting_target.is_empty() else null
	if casting_node != null:
		_player.face_toward(casting_node.global_position, 0.15)


# --- Ataque simples (golpe livre, [JOGO-05]) ---

## Toque: golpe na direção do inimigo mais perto (ou para a frente).
func _on_attack_tapped() -> void:
	_swing(_auto_aim_direction())


## Soltar depois de arrastar: golpe na direção desenhada.
func _on_attack_released(offset: Vector2) -> void:
	var direction: Vector3 = _drag_direction(offset)
	_end_aim()
	_swing(direction)


## Pede o golpe na [param direction] (XZ). Ignora se o golpe anterior ainda está em execução (um por vez) ou se estou
## morto. Anima na hora (o servidor confirma com "cast_start" e acerta o relógio) e vira o modelo para lá durante a
## execução. Golpe com passo (adagas): vai na fila de passos com predição, como a Investida ([JOGO-07]).
func _swing(direction: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	var own: PlayerState = Network.instance.get_player(Network.instance.player_id)
	if now < _attack_ready_ms or (own != null and own.dead):
		return
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		flat = _player.get_facing()
	flat = flat.normalized()
	var execution: float = maxf(_attack.cast_time_s, 0.1)
	_attack_sent_ms = now
	_attack_ready_ms = now + int(execution * 1000.0)
	_hud.attack_button.set_cooldown(execution, execution)
	_player.face_toward(_player.global_position + flat * 3.0, execution)
	if _attack.is_movement():
		if not _player.cast_movement(_attack, flat.x, flat.z):
			_attack_ready_ms = 0
			return
	else:
		Network.instance.send_cast(_attack.id, "", flat.x, flat.z)
	_player.predict_action(_attack.id, AbilityVisuals.INSTANT_HIT_SECONDS)


## Direção do toque no ⚔: até o inimigo mais perto no alcance (+ folga); o Livro, sem inimigo, mira o aliado ferido mais
## perto (o raio cura). Ninguém: para a frente.
func _auto_aim_direction() -> Vector3:
	var origin: Vector3 = _player.global_position
	var reach: float = maxf(_attack.range_m + TAP_AIM_MARGIN, TAP_AIM_MIN_RANGE)
	var target: RemotePlayer = _nearest_remote(origin, reach)
	if target == null and _attack.heal > 0.0:
		target = _nearest_hurt_ally(origin, reach)
	if target == null:
		return _player.get_facing()
	return Vector3(target.global_position.x - origin.x, 0.0, target.global_position.z - origin.z)


## Aliado (jogador) ferido mais perto de [param point] até [param max_distance] m, ou null.
func _nearest_hurt_ally(point: Vector3, max_distance: float) -> RemotePlayer:
	var best: RemotePlayer = null
	var best_distance: float = max_distance
	for remote: RemotePlayer in _zone.get_allies():
		var state: PlayerState = Network.instance.get_entity(remote.session_id)
		if state == null or state.hp >= state.max_hp:
			continue
		var offset: Vector3 = remote.global_position - point
		var distance: float = Vector2(offset.x, offset.z).length()
		if distance <= best_distance:
			best = remote
			best_distance = distance
	return best


## Direção (XZ, normalizada) de um arrasto de [param offset] px, relativa à câmera; parado no centro = para a frente.
func _drag_direction(offset: Vector2) -> Vector3:
	var screen_direction: Vector3 = Vector3(offset.x, 0.0, offset.y).rotated(Vector3.UP, _player.get_camera_yaw())
	return screen_direction.normalized() if screen_direction.length() > 0.01 else _player.get_facing()


# --- Cartas ---

## Toque na carta (sem alvo fixo, [JOGO-05]): em si mesmo/ao redor sai na hora; "no alvo" vai no inimigo mais perto
## dentro do alcance da carta; aliado = em você; direção/área vão no inimigo mais perto no alcance ou, sem ninguém,
## para a frente.
func _on_card_tapped(ability: AbilityView) -> void:
	var target: RemotePlayer = _nearest_remote(_player.global_position, ability.range_m) if ability.range_m > 0.0 else null
	match ability.aim_type:
		AbilityView.AimType.SELF, AbilityView.AimType.AREA_SELF, AbilityView.AimType.ALLY:
			_cast(ability)
		AbilityView.AimType.TARGET:
			if target == null:
				_hud.show_toast("%s: ninguém no alcance (arraste para mirar)" % ability.title)
			else:
				_cast(ability, target.session_id, target.global_position)
		AbilityView.AimType.DIRECTION, AbilityView.AimType.AREA:
			var point: Vector3 = target.global_position if target != null else _player.global_position + _player.get_facing() * maxf(ability.range_m, 3.0)
			_cast(ability, "", point)


## Soltar a carta depois de arrastar: lança no que estava na mira.
func _on_card_released(offset: Vector2, ability: AbilityView) -> void:
	# Quem está dentro do círculo desenhado NA HORA de soltar (o último movimento pode ter sido antes).
	var picks_unit: bool = ability.aim_type == AbilityView.AimType.TARGET or ability.aim_type == AbilityView.AimType.ALLY
	var under: RemotePlayer = _nearest_remote(_aim_point(offset, ability), TARGET_PICK_RADIUS, ability.aim_type == AbilityView.AimType.ALLY) if picks_unit else null
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
	if ability == _attack:
		# Golpe livre ([JOGO-05]): só a direção do arrasto importa; mostra o formato de verdade (leque ou linha).
		var swing: Vector3 = _drag_direction(offset)
		if ability.arc_rad > 0.0:
			_preview.show_cone(origin, swing, ability.range_m, ability.arc_rad)
		else:
			_preview.show_line(origin, swing, ability.range_m, maxf(0.3, ability.radius_m * 2.0))
		_preview.hide_target()
		return
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
	_preview.hide_target()


## Ponto no chão onde o desenho da mira está (e onde o efeito vai cair): sai do personagem na direção do arrasto
## (relativa à câmera), a uma distância proporcional ao arrasto, até o alcance da habilidade (ou
## [constant TARGET_PICK_RANGE] para escolher alguém sem alcance). Mesma conta na prévia e no soltar.
func _aim_point(offset: Vector2, ability: AbilityView) -> Vector3:
	var picks_unit: bool = ability.aim_type == AbilityView.AimType.TARGET or ability.aim_type == AbilityView.AimType.ALLY
	var reach: float = ability.range_m
	if picks_unit and reach <= 0.0:
		reach = TARGET_PICK_RANGE
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
