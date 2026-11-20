class_name Movement
extends RefCounted
## Simulação de movimento COMPARTILHADA com o servidor. Ver mmo-docs [INFRA-09].
##
## O servidor roda esta conta para valer (ele é a autoridade). O cliente roda a mesma conta para
## PREVER o próprio movimento na hora (sem esperar a rede) e para refazer os inputs ainda não
## confirmados quando chega um snapshot (reconciliação). Por isso tem que dar o mesmo resultado.
##
## ATENÇÃO: espelho de mmo-server/src/sim/movement.ts. Mesma ordem de operações e tudo em float
## (64 bits, igual ao number do JS) — nada de Vector3 aqui, que é 32 bits.

## Abaixo deste comprimento o input é "parado" (não move nem gira).
const MIN_INPUT_LENGTH: float = 0.01
## Passos por metro: posições em milímetros ([method quantize], [INFRA-11]).
## ATENÇÃO: = POSITION_STEPS em mmo-server/src/sim/movement.ts.
const POSITION_STEPS: float = 1000.0


## Arredonda [param value] (m) ao milímetro, com a MESMA conta do servidor: floor(v × 1000 + 0,5) / 1000 (o round()
## do GDScript trata o ,5 negativo diferente do JS). Cada passo da simulação arredonda X e Z com isto.
## ATENÇÃO: espelho de quantize em mmo-server/src/sim/movement.ts.
static func quantize(value: float) -> float:
	return floor(value * POSITION_STEPS + 0.5) / POSITION_STEPS


## Estado simulado de um personagem. Metros e radianos, em float de 64 bits.
class State:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var rot_y: float = 0.0

	func _init(px: float = 0.0, py: float = 0.0, pz: float = 0.0, protation: float = 0.0) -> void:
		x = px
		y = py
		z = pz
		rot_y = protation

	## Posição para desenhar (aí sim Vector3).
	func position() -> Vector3:
		return Vector3(x, y, z)

	func duplicate_state() -> State:
		return State.new(x, y, z, rot_y)


## Aplica UM tick de input: anda speed * dt na direção (input_x, input_z) do mundo, com comprimento
## no máximo 1, limita a ±half_size e vira para a direção do movimento. Devolve um estado novo.
static func step(state: State, input_x: float, input_z: float, dt: float, speed: float, half_size: float) -> State:
	var dx: float = input_x
	var dz: float = input_z
	var length: float = sqrt(dx * dx + dz * dz)
	if length < MIN_INPUT_LENGTH:
		return state.duplicate_state()
	if length > 1.0:
		dx /= length
		dz /= length
	return State.new(
		quantize(minf(half_size, maxf(-half_size, state.x + dx * speed * dt))),
		state.y,
		quantize(minf(half_size, maxf(-half_size, state.z + dz * speed * dt))),
		atan2(-dx, -dz),
	)


## Um passo da Investida: desloca [param distance] metros na direção ([param dir_x], [param dir_z]), limitado a
## ±half_size, e vira para ela. A Investida inteira são vários destes, um por passo. Direção quase zero = não
## muda. Ver mmo-docs [JOGO-07].
## ATENÇÃO: espelho de dashMovement em mmo-server/src/sim/movement.ts (mesma ordem de operações).
static func dash(state: State, dir_x: float, dir_z: float, distance: float, half_size: float) -> State:
	var length: float = sqrt(dir_x * dir_x + dir_z * dir_z)
	if length < MIN_INPUT_LENGTH:
		return state.duplicate_state()
	var dx: float = dir_x / length
	var dz: float = dir_z / length
	return State.new(
		quantize(minf(half_size, maxf(-half_size, state.x + dx * distance))),
		state.y,
		quantize(minf(half_size, maxf(-half_size, state.z + dz * distance))),
		atan2(-dx, -dz),
	)



## Arena do Coliseu ([JOGO-28]): prende a posição dentro do muro redondo de [param radius] m e, com a barreira ligada
## ([param side] −1 = time 0 só em x ≤ −[param barrier_gap]; 1 = time 1 só em x ≥ [param barrier_gap]; 0 = sem
## barreira), no lado do time. Primeiro o muro, depois a barreira; dentro dos limites devolve uma cópia igual (sem
## quantizar de novo). Roda depois de cada [method step]/[method dash].
## ATENÇÃO: mesma conta e ordem de constrainArena em mmo-server/src/sim/movement.ts ([INFRA-09]).
static func constrain_arena(state: State, radius: float, side: int, barrier_gap: float) -> State:
	var x: float = state.x
	var z: float = state.z
	var distance: float = sqrt(x * x + z * z)
	if distance > radius:
		x = (x * radius) / distance
		z = (z * radius) / distance
	if side < 0:
		x = minf(x, -barrier_gap)
	elif side > 0:
		x = maxf(x, barrier_gap)
	if x == state.x and z == state.z:
		return state.duplicate_state()
	return State.new(quantize(x), state.y, quantize(z), state.rot_y)
