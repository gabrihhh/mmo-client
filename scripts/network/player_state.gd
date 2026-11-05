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
	state.set_look(Protocol.read_dict(data, "look"))
	var info_body: String = Protocol.read_string(data, "body")
	if not info_body.is_empty():
		state.body = info_body
		state.has_body = true
	var ally_value: Variant = data.get("ally")
	state.ally = ally_value is bool and ally_value == true
	var targetable_value: Variant = data.get("targetable")
	state.targetable = not (targetable_value is bool and targetable_value == false)
	state.apply_snapshot(data, at_tick)
	return state


## Troca a aparência a partir do Look do servidor ({ hand, head, chest, feet: itemId ou null }).
func set_look(data: Dictionary) -> void:
	var new_look: Dictionary[String, String] = {}
	for slot: String in InventoryState.SLOTS:
		var item_id: String = Protocol.read_string(data, slot)
		if not item_id.is_empty():
			new_look[slot] = item_id
	if new_look == look:
		return
	look = new_look
	look_changed.emit()


## Registra o estado do tick [param at_tick] (PlayerSnapshot já validado). Ticks repetidos ou
## antigos atualizam só o "último estado", sem entrar no histórico.
func apply_snapshot(data: Dictionary, at_tick: int) -> void:
	x = Protocol.read_float(data, "x")
	y = Protocol.read_float(data, "y")
	z = Protocol.read_float(data, "z")
	rot_y = Protocol.read_float(data, "rotY")
	hp = Protocol.read_float(data, "hp", hp)
	max_hp = Protocol.read_float(data, "maxHp", max_hp)
	shield = Protocol.read_float(data, "shield")
	guard = Protocol.read_float(data, "guard")
	mana = Protocol.read_float(data, "mana", mana)
	max_mana = Protocol.read_float(data, "maxMana", max_mana)
	var dead_value: Variant = data.get("dead")
	if dead_value is bool:
		var is_dead: bool = dead_value
		dead = is_dead
	tick = at_tick
	if not _ticks.is_empty() and at_tick <= _ticks[-1]:
		return
	_ticks.append(at_tick)
	_positions.append(position)
	_rotations.append(rot_y)
	if _ticks.size() > _HISTORY_SIZE:
		_ticks.pop_front()
		_positions.pop_front()
		_rotations.pop_front()


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


## Posição interpolada no tick (fracionário) [param render_tick]. Antes do histórico, devolve o
## primeiro; depois do último, segura o último (não extrapola: evita "adivinhar" errado).
func sample_position(render_tick: float) -> Vector3:
	var index: int = _segment(render_tick)
	if index < 0:
		return _positions[0] if not _positions.is_empty() else position
	if index >= _ticks.size() - 1:
		return _positions[-1]
	return _positions[index].lerp(_positions[index + 1], _weight(index, render_tick))


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
