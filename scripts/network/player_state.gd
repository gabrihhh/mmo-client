class_name PlayerState
extends RefCounted
## Estado de um jogador na zona, como recebido do servidor (PlayerSnapshot em [Protocol]).
##
## O [Network] mantém um objeto por jogador e, a cada "snapshot" (20 Hz), guarda a posição daquele
## tick num histórico curto. Assim os jogadores remotos são desenhados um pouco no PASSADO,
## interpolando entre dois snapshots reais ([method sample_position]) — fica suave mesmo com a rede
## oscilando. Ver mmo-docs [INFRA-09].

## Quantos snapshots guardar (~2 s a 20 Hz). Mais que o atraso de interpolação com folga.
const _HISTORY_SIZE: int = 40

## Ticks sem aparecer no snapshot a partir dos quais o histórico recomeça (voltou de longe: não desliza do lugar antigo).
const _GAP_TICKS: int = 10
## Extrapolação ([INFRA-12]): depois do último snapshot, segue andando na velocidade dos dois últimos por no máximo
## isto (ticks; 6 = 200 ms a 30 Hz) e então para. É o que faz os outros parecerem "na hora" (como nos MMOs): desenhados onde
## devem estar agora, não onde estavam. Errou (o outro parou/virou)? A diferença vira [member _correction], que o
## [RemotePlayer] some suavemente.
const MAX_EXTRAPOLATION_TICKS: float = 6.0
## Correção maior que isto (m) não é suavizada (teleporte, renasceu): pula direto.
const MAX_SMOOTH_CORRECTION: float = 2.0

## Diferença (m) entre onde o desenho estava (extrapolado) e onde ele fica com o snapshot novo, no mesmo instante;
## acumula até o [RemotePlayer] pegar ([method take_correction]).
var _correction: Vector3 = Vector3.ZERO
## Estatística das correções de extrapolação de todos (m): soma, maior e quantas (o resumo "Perf:" lê e zera,
## [method take_correction_stats]).
static var _stat_sum: float = 0.0
static var _stat_max: float = 0.0
static var _stat_count: int = 0

## Está na área de interesse (veio no último snapshot; o servidor só manda quem está perto, [INFRA-04]). Fora dela o
## nó fica escondido e congelado ([RemotePlayer]) e não serve de alvo.
var in_view: bool = true

## Id do jogador (playerId, estável).
var id: String = ""
## Nome exibido acima do personagem: o username exatamente como foi cadastrado.
var name: String = ""
## Último estado autoritativo recebido, em float de 64 bits (usado na reconciliação do jogador local).
var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
## Última rotação no eixo Y recebida, em radianos.
var rot_y: float = 0.0
## Tick do servidor do último estado recebido.
var tick: int = 0
## Vida atual e máxima, e se está morto (esperando renascer). Ver mmo-docs [JOGO-05].
var hp: float = 0.0
var max_hp: float = 0.0
var dead: bool = false
## Mana atual e máxima (ATENÇÃO: espelha PlayerSnapshot.mana/maxMana em mmo-server/src/net/protocol.ts).
## Só jogadores: bonecos/NPCs não mandam, e [member max_mana] fica 0 (sem barra de mana). Ver [CLI-04].
var mana: float = 0.0
var max_mana: float = 0.0
## Escudo ativo (dano que ainda absorve; 0 = sem escudo). Ver mmo-docs [JOGO-06].
var shield: float = 0.0
## Redução de dano ativa (0..1; 0 = nenhuma). Ver mmo-docs [JOGO-09].
## ATENÇÃO: espelha PlayerSnapshot.guard em mmo-server/src/net/protocol.ts.
var guard: float = 0.0
## O que veste: slot ("hand", "head", "chest", "feet") → itemId. Slot vazio não aparece. Ver [ART-02].
var look: Dictionary[String, String] = {}
## Nível de melhoria de cada peça vestida (slot → nível; sem chave = +0): o brilho que todos veem ([JOGO-17], [ItemGlow]).
## ATENÇÃO: LookLevels em mmo-server/src/net/protocol.ts.
var look_levels: Dictionary[String, int] = {}
## Corpo do personagem (qual modelo desenhar): [constant Protocol.BODY_MALE] ou [constant Protocol.BODY_FEMALE].
## Vem no PlayerInfo; bonecos/NPCs ficam com o padrão.
var body: String = Protocol.BODY_MALE
## NPC humano ([JOGO-11]): o servidor mandou um corpo, então ele é desenhado como personagem (não como boneco de palha).
## ATENÇÃO: NpcSnapshot.body em mmo-server/src/net/protocol.ts.
var has_body: bool = false
## NPC aliado (saco de pancadas, [JOGO-11]): os jogadores curam/protegem. ATENÇÃO: NpcSnapshot.ally.
var ally: bool = false
## NPC que serve de alvo de ataque (false: atirador invulnerável, aliado). ATENÇÃO: NpcSnapshot.targetable.
var targetable: bool = true
## Nível ([JOGO-12]): de jogadores e NPCs, público. ATENÇÃO: PlayerSnapshot.level em mmo-server/src/net/protocol.ts.
var level: int = 0
## Monstro (zumbi, [JOGO-13]): acima dele só vida, nível e barra de lançamento (sem nome). ATENÇÃO: NpcSnapshot.monster.
var monster: bool = false
## Tamanho do corpo (vezes o normal): o chefe é um zumbi maior ([JOGO-18]). ATENÇÃO: NpcSnapshot.scale.
var scale: float = 1.0
## Chefe ([JOGO-18]): nome à vista em dourado e marcador próprio no mapa. ATENÇÃO: NpcSnapshot.boss.
var boss: bool = false
## Guilda do jogador ([SOC-06]): id (cor de guildeiro, não é alvo) e tag ("[TAG][nível] nome"); vazio = sem guilda.
## Vem no PlayerInfo e muda por [constant Protocol.MSG_PLAYER_GUILD].
var guild_id: String = ""
var guild_tag: String = ""
## Serviço do NPC ([JOGO-16]): "blacksmith" = ferreiro (perto dele aparece o botão Ferreiro); "storage" = baú do
## Armazém ([JOGO-26], botão Armazém); vazio = nenhum.
## ATENÇÃO: NpcSnapshot.service.
var service: String = ""

## A aparência mudou ([member look]): o boneco troca os modelos dos itens.
signal look_changed

## Última posição recebida, em metros.
var position: Vector3:
	get:
		return Vector3(x, y, z)

var _ticks: Array[int] = []
var _positions: Array[Vector3] = []
var _rotations: Array[float] = []


## Cria a partir de um PlayerInfo (snapshot + name) recebido no [param at_tick]. Retorna null se o
## formato for inválido.
static func from_snapshot(data: Dictionary, at_tick: int) -> PlayerState:
	if not Protocol.is_player_snapshot(data):
		return null
	var state: PlayerState = PlayerState.new()
	state.id = Protocol.read_string(data, "id")
	state.name = Protocol.read_string(data, "name")
	state.set_look(Protocol.read_dict(data, "look"), Protocol.read_dict(data, "levels"))
	var info_body: String = Protocol.read_string(data, "body")
	if not info_body.is_empty():
		state.body = info_body
		state.has_body = true
	var ally_value: Variant = data.get("ally")
	state.ally = ally_value is bool and ally_value == true
	var targetable_value: Variant = data.get("targetable")
	state.targetable = not (targetable_value is bool and targetable_value == false)
	var monster_value: Variant = data.get("monster")
	state.monster = monster_value is bool and monster_value == true
	state.service = Protocol.read_string(data, "service")
	state.scale = clampf(Protocol.read_float(data, "scale", 1.0), 0.5, 4.0)
	var boss_value: Variant = data.get("boss")
	state.boss = boss_value is bool and boss_value == true
	state.guild_id = Protocol.read_string(data, "guildId")
	state.guild_tag = Protocol.read_string(data, "guildTag")
	state.apply_snapshot(data, at_tick)
	return state


## Troca a aparência a partir do Look do servidor ({ hand, head, chest, feet: itemId ou null }).
func set_look(data: Dictionary, levels: Dictionary = {}) -> void:
	var new_look: Dictionary[String, String] = {}
	var new_levels: Dictionary[String, int] = {}
	for slot: String in InventoryState.SLOTS:
		var item_id: String = Protocol.read_string(data, slot)
		if not item_id.is_empty():
			new_look[slot] = item_id
			var level: int = Protocol.read_int(levels, slot)
			if level > 0:
				new_levels[slot] = level
	if new_look == look and new_levels == look_levels:
		return
	look = new_look
	look_levels = new_levels
	look_changed.emit()


## Registra o estado do tick [param at_tick]. Snapshot por diferença ([INFRA-11]): só os campos que vieram mudam;
## os outros ficam como estavam ([code]{}[/code] = "igual ao último", e o tick entra no histórico mesmo assim, para a
## interpolação não ver um buraco). Ticks repetidos ou antigos atualizam só o "último estado", sem entrar no histórico.
func apply_snapshot(data: Dictionary, at_tick: int, render_tick: float = -1.0) -> void:
	# Onde o desenho estava neste instante, antes do snapshot novo (para manter o movimento contínuo, sem tranco).
	var shown_before: Vector3 = sample_position(render_tick) if render_tick >= 0.0 and not _ticks.is_empty() else Vector3.ZERO
	x = Protocol.read_float(data, "x", x)
	y = Protocol.read_float(data, "y", y)
	z = Protocol.read_float(data, "z", z)
	rot_y = Protocol.read_float(data, "rotY", rot_y)
	hp = Protocol.read_float(data, "hp", hp)
	max_hp = Protocol.read_float(data, "maxHp", max_hp)
	shield = Protocol.read_float(data, "shield", shield)
	guard = Protocol.read_float(data, "guard", guard)
	mana = Protocol.read_float(data, "mana", mana)
	max_mana = Protocol.read_float(data, "maxMana", max_mana)
	level = Protocol.read_int(data, "level", level)
	var dead_value: Variant = data.get("dead")
	if dead_value is bool:
		var is_dead: bool = dead_value
		dead = is_dead
	tick = at_tick
	if not _ticks.is_empty() and at_tick - _ticks[-1] > _GAP_TICKS:
		_ticks.clear()
		_positions.clear()
		_rotations.clear()
	if not _ticks.is_empty() and at_tick <= _ticks[-1]:
		return
	var was_extrapolating: bool = render_tick >= 0.0 and not _ticks.is_empty() and render_tick > float(_ticks[-1])
	_ticks.append(at_tick)
	_positions.append(position)
	_rotations.append(rot_y)
	if _ticks.size() > _HISTORY_SIZE:
		_ticks.pop_front()
		_positions.pop_front()
		_rotations.pop_front()
	# Só muda o que está na tela se o desenho estava ADIANTE do último snapshot (extrapolando): aí a diferença entre
	# o palpite e o certo vira correção suave em vez de tranco.
	if was_extrapolating:
		var difference: Vector3 = shown_before - sample_position(render_tick)
		_correction = _correction + difference if difference.length() < MAX_SMOOTH_CORRECTION else Vector3.ZERO
		if difference.length() > 0.005:
			_stat_sum += difference.length()
			_stat_max = maxf(_stat_max, difference.length())
			_stat_count += 1


## Correções de extrapolação desde a última chamada: Vector3(média m, maior m, quantas); zera.
static func take_correction_stats() -> Vector3:
	var result: Vector3 = Vector3(_stat_sum / float(_stat_count) if _stat_count > 0 else 0.0, _stat_max, float(_stat_count))
	_stat_sum = 0.0
	_stat_max = 0.0
	_stat_count = 0
	return result


## Pega (e zera) a correção acumulada ([member _correction]); o [RemotePlayer] soma ao desenho e faz sumir aos poucos.
func take_correction() -> Vector3:
	var value: Vector3 = _correction
	_correction = Vector3.ZERO
	return value


## Texto acima da cabeça de um jogador ([CLI-04]): "[TAG][nível] nome" (tag só com guilda, [SOC-06]; nível
## abreviado de 1.000 para cima, [LevelText]).
func title() -> String:
	return LevelText.title(level, name, guild_tag)


## Fração de vida (0..1); 1 se a vida máxima não é conhecida.
func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0


## Escudo como fração da vida máxima (0 = sem escudo), para a sobrevida azul na barra ([HealthBar3D.set_values]).
func shield_ratio() -> float:
	return clampf(shield / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


## true se tem mana (jogador); bonecos/NPCs não têm.
func has_mana() -> bool:
	return max_mana > 0.0


## Fração de mana (0..1); 0 sem mana.
func mana_ratio() -> float:
	return clampf(mana / max_mana, 0.0, 1.0) if max_mana > 0.0 else 0.0


## Posição no tick (fracionário) [param render_tick]: entre dois snapshots, interpola; antes do histórico, o primeiro;
## depois do último, **extrapola** na velocidade dos dois últimos por até [constant MAX_EXTRAPOLATION_TICKS] ([INFRA-12]).
func sample_position(render_tick: float) -> Vector3:
	var index: int = _segment(render_tick)
	if index < 0:
		return _positions[0] if not _positions.is_empty() else position
	if index >= _ticks.size() - 1:
		return _extrapolate(render_tick)
	return _positions[index].lerp(_positions[index + 1], _weight(index, render_tick))


## Depois do último snapshot: o último + velocidade (dos dois últimos, se forem seguidos) × o tempo passado (até
## [constant MAX_EXTRAPOLATION_TICKS]). Sem dois seguidos (acabou de aparecer, buraco), segura o último.
func _extrapolate(render_tick: float) -> Vector3:
	var last: Vector3 = _positions[-1]
	if _ticks.size() < 2:
		return last
	var span: int = _ticks[-1] - _ticks[-2]
	if span <= 0 or span > 2:
		return last
	var velocity: Vector3 = (last - _positions[-2]) / float(span)
	var ahead: float = clampf(render_tick - float(_ticks[-1]), 0.0, MAX_EXTRAPOLATION_TICKS)
	return last + velocity * ahead


## Rotação Y interpolada no tick [param render_tick] (mesmas regras de [method sample_position]).
func sample_rot_y(render_tick: float) -> float:
	var index: int = _segment(render_tick)
	if index < 0:
		return _rotations[0] if not _rotations.is_empty() else rot_y
	if index >= _ticks.size() - 1:
		return _rotations[-1]
	return lerp_angle(_rotations[index], _rotations[index + 1], _weight(index, render_tick))


## Índice i tal que _ticks[i] <= render_tick < _ticks[i + 1]; -1 se antes do início.
func _segment(render_tick: float) -> int:
	if _ticks.is_empty() or render_tick < float(_ticks[0]):
		return -1
	for i: int in range(_ticks.size() - 1, -1, -1):
		if float(_ticks[i]) <= render_tick:
			return i
	return -1


func _weight(index: int, render_tick: float) -> float:
	var t0: float = float(_ticks[index])
	var t1: float = float(_ticks[index + 1])
	return clampf((render_tick - t0) / (t1 - t0), 0.0, 1.0)
