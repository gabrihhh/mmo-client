class_name Zone
extends Node3D
## Cena de uma zona do mundo: cria/remove os jogadores conforme o servidor e monta a HUD.
##
## É aberta pela tela de login depois do welcome (já conectado). Fluxo: cria quem já está em
## [method Network.get_players] e depois segue [signal Network.player_added] / [signal Network.player_removed].
## O próprio player id vira o [LocalPlayer]; os outros, [RemotePlayer].
## Se a conexão cair (ou o jogador sair pelo menu), volta para a tela de login, que mostra o motivo.

const LOCAL_PLAYER_SCENE: PackedScene = preload("res://scenes/player/local_player.tscn")
const REMOTE_PLAYER_SCENE: PackedScene = preload("res://scenes/player/remote_player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/world/training_dummy.tscn")
## Altura (m) acima da origem da entidade onde nascem os números de dano.
const _FLOATING_TEXT_HEIGHT: float = 2.9
## Para onde voltar quando a conexão cai.
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"

@onready var _players_root: Node3D = $Players
@onready var _hud: Hud = $Hud

var _local_player: LocalPlayer = null
var _remote_players: Dictionary[String, RemotePlayer] = {}
## Bonecos/monstros da zona (usam o mesmo script de desenho dos jogadores remotos).
var _npcs: Dictionary[String, RemotePlayer] = {}
var _aim_preview: AimPreview = null
var _combat: CombatController = null
## Projéteis do servidor na tela, por id do evento "projectile" ([JOGO-08]).
var _projectiles: Dictionary[int, ProjectileVisual] = {}
## Lançamento atual de cada personagem (id → número que sobe a cada início/cancelamento): efeitos agendados
## para o fim do lançamento (clarão, projétil visual) só saem se o lançamento ainda for o mesmo ([JOGO-06]).
var _cast_serial: Dictionary[String, int] = {}
## Aviso no chão do lançamento atual de cada personagem (some na hora se for cancelado).
var _cast_warnings: Dictionary[String, GroundWarning] = {}
## Nível e XP do último snapshot (para mostrar "+20 XP" quando a XP sobe; −1 = ainda não recebeu).
var _last_level: int = -1
var _last_xp: float = 0.0

## Altura (m) de onde os projéteis voam (mais ou menos a mão de quem lança).
const _PROJECTILE_HEIGHT: float = 1.3


func _ready() -> void:
	if Network.instance == null or not Network.instance.is_in_zone():
		# Aberta sem passar pelo login (ex.: F6 no editor): volta para lá.
		_back_to_login.call_deferred()
		return
	# Modelos dos itens em segundo plano: sem engasgo quando alguém (ou o atirador de teste) veste um item novo.
	ItemModels.preload_all()
	Network.instance.player_added.connect(_on_player_added)
	Network.instance.player_removed.connect(_on_player_removed)
	Network.instance.left_zone.connect(_on_left_zone)
	_hud.logout_requested.connect(_on_logout_requested)
	_hud.equip_requested.connect(Network.instance.send_equip)
	_hud.unequip_requested.connect(Network.instance.send_unequip)
	# Recusas que não são de login (ex.: mochila cheia) viram aviso na tela.
	Network.instance.server_error.connect(_on_server_error)

	_aim_preview = AimPreview.new()
	_aim_preview.name = "AimPreview"
	add_child(_aim_preview)

	for state: PlayerState in Network.instance.get_players():
		_on_player_added(state.id, state)
	for npc: PlayerState in Network.instance.get_npcs():
		_spawn_npc(npc)
	Network.instance.combat_event.connect(_on_combat_event)
	Network.instance.snapshot_received.connect(_on_snapshot)
	_update_online_status()


## Quem pode ser alvo agora: bonecos/monstros vivos (menos os que o servidor marca como não-alvo: atirador de teste
## invulnerável e o saco de pancadas, que é aliado, [JOGO-11]) e, se a zona tem PvP ([JOGO-02]), jogadores vivos.
func get_targetables() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	for npc_id: String in _npcs:
		var npc: RemotePlayer = _npcs[npc_id]
		var state: PlayerState = Network.instance.get_entity(npc_id)
		if npc.is_alive() and (state == null or state.targetable):
			result.append(npc)
	if Network.instance.pvp:
		for remote: RemotePlayer in _remote_players.values():
			if remote.is_alive():
				result.append(remote)
	return result


## Aliados que dá para curar/proteger ([JOGO-09]): outros jogadores vivos (sem grupos ainda, todo jogador é
## aliado, mesmo com PvP) e NPCs aliados (saco de pancadas, [JOGO-11]). ATENÇÃO: mesma regra de Zone.isAlly em
## mmo-server/src/zones/Zone.ts.
func get_allies() -> Array[RemotePlayer]:
	var result: Array[RemotePlayer] = []
	for remote: RemotePlayer in _remote_players.values():
		if remote.is_alive():
			result.append(remote)
	for npc_id: String in _npcs:
		var npc: RemotePlayer = _npcs[npc_id]
		var state: PlayerState = Network.instance.get_entity(npc_id)
		if npc.is_alive() and state != null and state.ally:
			result.append(npc)
	return result


## Jogador remoto ou boneco pelo id (para o marcador do alvo), ou null.
func get_target_node(entity_id: String) -> RemotePlayer:
	if _remote_players.has(entity_id):
		return _remote_players[entity_id]
	if _npcs.has(entity_id):
		return _npcs[entity_id]
	return null


## Nó de qualquer entidade (inclusive o jogador local), para efeitos visuais; ou null.
func get_entity_node(entity_id: String) -> Node3D:
	if _local_player != null and entity_id == Network.instance.player_id:
		return _local_player
	return get_target_node(entity_id)


func _on_player_added(player_id: String, state: PlayerState) -> void:
	if player_id == Network.instance.player_id:
		_spawn_local_player(state)
	elif not _remote_players.has(player_id):
		var remote: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
		remote.setup(player_id, state)
		remote.name = "Remote_%s" % player_id
		_players_root.add_child(remote)
		_remote_players[player_id] = remote
	_update_online_status()


func _on_player_removed(player_id: String) -> void:
	if _remote_players.has(player_id):
		# Subscript de Dictionary tipado já devolve RemotePlayer (get() devolveria Variant).
		var remote: RemotePlayer = _remote_players[player_id]
		remote.queue_free()
		_remote_players.erase(player_id)
	_update_online_status()


func _spawn_npc(state: PlayerState) -> void:
	if _npcs.has(state.id):
		return
	# NPC humano ([JOGO-11]): personagem vestido, como um jogador; os outros: boneco de palha.
	var scene: PackedScene = REMOTE_PLAYER_SCENE if state.has_body else DUMMY_SCENE
	var npc: RemotePlayer = scene.instantiate() as RemotePlayer
	npc.setup(state.id, state)
	npc.name = "Npc_%s" % state.id
	_players_root.add_child(npc)
	_npcs[state.id] = npc


## Eventos de combate: animações, projéteis, avisos no chão ([JOGO-08]), números de dano e mortes ([JOGO-05]).
func _on_combat_event(event: Dictionary) -> void:
	var type: String = Protocol.read_string(event, "type")
	var me: String = Network.instance.player_id
	match type:
		"cast_start":
			_on_cast_start(event)
		"cast_cancel":
			_on_cast_cancel(Protocol.read_string(event, "source"))
		"projectile":
			_on_projectile(event)
		"projectile_end":
			var ended: int = Protocol.read_int(event, "id", -1)
			if _projectiles.has(ended):
				var visual: ProjectileVisual = _projectiles[ended]
				if is_instance_valid(visual):
					visual.finish(Vector3(Protocol.read_float(event, "x"), 0.0, Protocol.read_float(event, "z")))
				_projectiles.erase(ended)
		"damage":
			var target_id: String = Protocol.read_string(event, "target")
			var node: Node3D = get_entity_node(target_id)
			if node == null:
				return
			var hurt: RemotePlayer = get_target_node(target_id)
			if hurt != null:
				hurt.react_to_hit()
			elif target_id == me and _local_player != null:
				_local_player.model.flinch()
			# Vermelho: dano em mim. Amarelo: dano que eu dei. Branco: entre outros.
			var color: Color = Color(1, 0.35, 0.3) if target_id == me else (Color(1, 0.85, 0.4) if Protocol.read_string(event, "source") == me else Color(1, 1, 1, 0.85))
			var above: Vector3 = node.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT
			var amount: int = roundi(Protocol.read_float(event, "amount"))
			var absorbed: int = roundi(Protocol.read_float(event, "absorbed"))
			if amount > 0:
				FloatingText.spawn(self, above, "-%d" % amount, color)
			# Parte do golpe que o escudo segurou, em azul claro.
			if absorbed > 0:
				FloatingText.spawn(self, above + Vector3.UP * 0.4, "-%d escudo" % absorbed, Color(0.55, 0.8, 1.0))
		"heal":
			var healed: Node3D = get_entity_node(Protocol.read_string(event, "target"))
			var heal_amount: int = roundi(Protocol.read_float(event, "amount"))
			if healed != null and heal_amount > 0:
				FloatingText.spawn(self, healed.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT, "+%d" % heal_amount, Color(0.4, 1.0, 0.45))
		"impact":
			# Onde a área/projétil bateu ([JOGO-06]).
			ImpactFlash.spawn(self, Protocol.read_float(event, "x"), Protocol.read_float(event, "z"), Protocol.read_float(event, "radius"))
		"miss":
			# Golpe terminou com o alvo fora do alcance ([JOGO-05]).
			var missed: Node3D = get_entity_node(Protocol.read_string(event, "target"))
			if missed != null and Protocol.read_string(event, "source") == me:
				FloatingText.spawn(self, missed.global_position + Vector3.UP * _FLOATING_TEXT_HEIGHT, "Errou", Color(0.85, 0.85, 0.85))
		"death":
			var dead_id: String = Protocol.read_string(event, "id")
			if Protocol.read_string(event, "killer") == me and dead_id != me:
				var victim: RemotePlayer = get_target_node(dead_id)
				_hud.show_toast("Você derrotou %s" % (victim.display_name if victim != null else dead_id))
		"level_up":
			# Todos veem quem subiu ([JOGO-12]); quem subiu também ganha o aviso no topo.
			var leveled_id: String = Protocol.read_string(event, "id")
			var new_level: int = Protocol.read_int(event, "level")
			var leveled: Node3D = get_entity_node(leveled_id)
			if leveled != null:
				FloatingText.spawn(self, leveled.global_position + Vector3.UP * (_FLOATING_TEXT_HEIGHT + 0.5), "Nível %d!" % new_level, Color(0.0, 0.9, 1.0))
			if leveled_id == me:
				_hud.show_toast("Você subiu para o nível %d!" % new_level)


## Alguém começou a lançar: o personagem anima (golpe no fim do lançamento), aparece o aviso no chão das
## áreas/linhas e, nas habilidades de alvo, um projétil visual que chega junto com o dano ([JOGO-08]).
func _on_cast_start(event: Dictionary) -> void:
	var source_id: String = Protocol.read_string(event, "source")
	var ability: String = Protocol.read_string(event, "ability")
	var duration: float = Protocol.read_float(event, "duration")
	# Monstro: barra de lançamento acima da vida ([JOGO-13]).
	var npc_node: RemotePlayer = get_target_node(source_id)
	if npc_node != null:
		npc_node.show_cast(duration)
	var model: CharacterModel = _character_of(source_id)
	var serial: int = _cast_serial.get(source_id, 0) + 1
	_cast_serial[source_id] = serial
	var already_animated: bool = _local_player != null and source_id == Network.instance.player_id and _local_player.consume_prediction(ability)
	if model != null and not already_animated:
		model.play_action(AbilityVisuals.animation(ability), duration)
	var color: Color = AbilityVisuals.color(ability)
	if model != null and duration > 0.0 and AbilityVisuals.has_cast_glow(ability):
		model.show_cast_glow(color, duration)
	var radius: float = Protocol.read_float(event, "radius")
	var has_point: bool = event.has("x") and event.has("z")
	var caster: Node3D = get_entity_node(source_id)
	if has_point and radius > 0.0 and duration > 0.0 and caster != null:
		var point: Vector3 = Vector3(Protocol.read_float(event, "x"), 0.0, Protocol.read_float(event, "z"))
		if Protocol.read_string(event, "aim") == "direction":
			_cast_warnings[source_id] = GroundWarning.spawn_line(self, caster.global_position, point, radius, duration, color)
		else:
			_cast_warnings[source_id] = GroundWarning.spawn_area(self, point.x, point.z, radius, duration, color)
	var reach: float = AbilityVisuals.slash_reach(ability)
	if reach != 0.0 and caster != null:
		get_tree().create_timer(maxf(duration, 0.0)).timeout.connect(_slash.bind(source_id, serial, caster, reach, color))
	# Quando o tiro sai da mão: o servidor manda ("release", s antes do fim); depois disso andar não cancela mais.
	var flight: float = Protocol.read_float(event, "release") if event.has("release") else AbilityVisuals.homing_flight(ability)
	var target: Node3D = get_entity_node(Protocol.read_string(event, "target"))
	if flight > 0.0 and target != null and model != null:
		# Sai antes do fim do lançamento para chegar junto com o dano.
		var delay: float = maxf(duration - flight, 0.0)
		get_tree().create_timer(delay).timeout.connect(_launch_homing.bind(source_id, serial, model, target, minf(flight, duration), color))


## [param source_id] andou durante o lançamento e o servidor cancelou ([JOGO-06]): para a animação e o brilho,
## tira o aviso do chão e invalida os efeitos agendados (clarão, projétil visual).
func _on_cast_cancel(source_id: String) -> void:
	_cast_serial[source_id] = _cast_serial.get(source_id, 0) + 1
	var npc_node: RemotePlayer = get_target_node(source_id)
	if npc_node != null:
		npc_node.hide_cast()
	var model: CharacterModel = _character_of(source_id)
	if model != null:
		model.stop_action()
		model.hide_cast_glow()
	# O aviso pode já ter sumido sozinho (liberado): checar antes de pôr numa variável tipada.
	var entry: Variant = _cast_warnings.get(source_id, null)
	if is_instance_valid(entry):
		(entry as GroundWarning).queue_free()
	_cast_warnings.erase(source_id)


## true se o lançamento [param serial] de [param source_id] ainda é o atual (não foi cancelado nem substituído).
func _is_current_cast(source_id: String, serial: int) -> bool:
	return _cast_serial.get(source_id, 0) == serial


## Clarão do golpe corpo a corpo no momento do golpe, na frente de [param caster] ([JOGO-08]).
func _slash(source_id: String, serial: int, caster: Node3D, reach: float, color: Color) -> void:
	if not _is_current_cast(source_id, serial) or not is_instance_valid(caster) or not caster.is_visible_in_tree():
		return
	SlashArc.spawn(self, caster.global_position, caster.global_rotation.y, absf(reach), reach < 0.0, Color(1, 1, 1) if color == AbilityVisuals.DEFAULT_COLOR else color)


## Projétil de alvo (visual): sai da mão de [param model] e chega em [param target] em [param seconds].
func _launch_homing(source_id: String, serial: int, model: CharacterModel, target: Node3D, seconds: float, color: Color) -> void:
	if not _is_current_cast(source_id, serial) or not is_instance_valid(model) or not is_instance_valid(target) or not model.is_visible_in_tree():
		return
	ProjectileVisual.spawn_homing(self, model.cast_point(), target, seconds, color)


## Projétil de verdade saiu ([JOGO-08]): desenha o voo na mesma velocidade do servidor.
func _on_projectile(event: Dictionary) -> void:
	var id: int = Protocol.read_int(event, "id", -1)
	var start_x: float = Protocol.read_float(event, "x")
	var start_z: float = Protocol.read_float(event, "z")
	var from: Vector3 = Vector3(start_x, ZoneTerrain.height_at(start_x, start_z) + _PROJECTILE_HEIGHT, start_z)
	var direction: Vector3 = Vector3(Protocol.read_float(event, "dirX"), 0.0, Protocol.read_float(event, "dirZ"))
	if direction.length() < 0.01:
		return
	var ability: String = Protocol.read_string(event, "ability")
	var visual: ProjectileVisual = ProjectileVisual.spawn_linear(self, from, direction.normalized(),
		Protocol.read_float(event, "speed"), Protocol.read_float(event, "range"), AbilityVisuals.color(ability))
	_projectiles[id] = visual
	# Limpa entradas de projéteis que já sumiram sozinhos (fim do alcance antes do "projectile_end").
	for old: int in _projectiles.keys():
		if not is_instance_valid(_projectiles[old]):
			_projectiles.erase(old)


## Recusa do servidor (ex.: mochila cheia, recarga): aviso na tela; se era uma carta animada no toque, para.
func _on_server_error(_code: String, message: String) -> void:
	_hud.show_toast(message)
	if _local_player != null:
		_local_player.cancel_prediction()


## Boneco animado de [param id] (você ou outro jogador); null para bonecos de treino e desconhecidos.
func _character_of(id: String) -> CharacterModel:
	if _local_player != null and id == Network.instance.player_id:
		return _local_player.model
	if _remote_players.has(id):
		return _remote_players[id].model
	return null


## A cada snapshot: barras de vida/mana/XP do jogador local e o aviso de morte.
func _on_snapshot(_tick: int, _ack: int) -> void:
	var network: Network = Network.instance
	var own: PlayerState = network.get_player(network.player_id)
	if own == null:
		return
	_hud.set_health(own.hp, own.max_hp, own.shield)
	_hud.set_mana(network.mana, network.max_mana)
	_hud.set_experience(network.level, network.xp, network.xp_next)
	# XP subiu no mesmo nível (matou um monstro): "+20 XP" em ciano acima de você. Subir de nível tem o aviso próprio.
	if _last_level == network.level and network.xp > _last_xp + 0.05 and _local_player != null:
		FloatingText.spawn(self, _local_player.global_position + Vector3.UP * (_FLOATING_TEXT_HEIGHT + 0.5),
			"+%s XP" % _format_xp(network.xp - _last_xp), Color(0.0, 0.9, 1.0))
	_last_level = network.level
	_last_xp = network.xp
	if own.dead:
		_hud.show_toast("Você morreu · renasce em %d s" % ceili(network.respawn_in))


## XP com no máximo 1 casa, sem ",0" ("20", "20.2").
static func _format_xp(value: float) -> String:
	var rounded: float = snappedf(value, 0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded


func _on_left_zone(_code: int, _reason: String) -> void:
	_back_to_login()


## "Sair da conta" (Menu): encerra a sessão; a queda da conexão traz de volta ao login.
func _on_logout_requested() -> void:
	Network.instance.logout()


func _back_to_login() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _spawn_local_player(state: PlayerState) -> void:
	if _local_player != null:
		return
	_local_player = LOCAL_PLAYER_SCENE.instantiate() as LocalPlayer
	_local_player.name = "LocalPlayer"
	_local_player.joystick = _hud.joystick
	_players_root.add_child(_local_player)
	_local_player.spawn_at(state)
	# Boneco no meio do espaço livre entre as molduras da HUD, não no centro da tela ([CLI-02]).
	_hud.play_area_changed.connect(_center_camera_on_play_area)
	_center_camera_on_play_area()
	BotFight.attach_if_requested(self, _local_player)

	_combat = CombatController.new()
	_combat.name = "CombatController"
	add_child(_combat)
	_combat.setup(self, _local_player, _hud, _aim_preview)


func _center_camera_on_play_area() -> void:
	if _local_player != null:
		_local_player.get_camera().screen_focus_y = _hud.play_area_center_ratio()


func _update_online_status() -> void:
	var online: int = _remote_players.size() + (1 if _local_player != null else 0)
	_hud.set_status("%s · Online: %d" % [Network.instance.username, online])
