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
	state.apply_snapshot(data, at_tick)
	return state


## Registra o estado do tick [param at_tick] (PlayerSnapshot já validado). Ticks repetidos ou
## antigos atualizam só o "último estado", sem entrar no histórico.
func apply_snapshot(data: Dictionary, at_tick: int) -> void:
	x = Protocol.read_float(data, "x")
	y = Protocol.read_float(data, "y")
	z = Protocol.read_float(data, "z")
	rot_y = Protocol.read_float(data, "rotY")
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
