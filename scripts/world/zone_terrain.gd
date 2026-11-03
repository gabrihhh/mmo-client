class_name ZoneTerrain
extends RefCounted
## Forma do chão da zona 1 ([MUN-03]): praça de pedra elevada no centro (círculo onde se nasce + piso quadrado),
## uma escada no meio de cada lado, campo em volta ondulando de leve e subindo na borda até as montanhas.
##
## [method height_at] é a ÚNICA fonte da altura: o cenário ([Zone1Scenery]) é desenhado com ela e os personagens
## são postos em cima dela. Por enquanto a altura é só VISUAL: o servidor simula em X/Z (y fixo) e não sabe de
## degraus nem morros ([INFRA-09]). Quando o servidor precisar (colisão, quedas), esta conta vira compartilhada.

## Praça: metade do lado do piso quadrado (m) e altura dele acima do campo (m).
const PLAZA_HALF: float = 10.0
const PLAZA_HEIGHT: float = 0.6
## Círculo de pedra no centro, onde os jogadores nascem (m). ATENÇÃO: o spawnRadius da zona no servidor
## (mmo-server/src/zones/zones.ts) fica dentro dele.
const SPAWN_CIRCLE_RADIUS: float = 4.5
## Escadas: uma no meio de cada lado da praça, descendo para o campo. Degraus com o topo em 0,45 / 0,30 / 0,15 m
## (STEP_COUNT × STEP_RISE + o último pulo para o chão = PLAZA_HEIGHT).
const STEP_COUNT: int = 3
const STEP_RISE: float = 0.15
const STEP_RUN: float = 0.5
const STAIR_HALF_WIDTH: float = 2.5
## Campo plano até este raio (m); depois ondula de leve.
const FLAT_RADIUS: float = 22.0
## Borda: o chão começa a subir aqui (m, em X ou Z) e chega a [constant EDGE_RISE] m no limite da zona.
const EDGE_START: float = 120.0
const EDGE_RISE: float = 8.0
## Metade do lado da área andável (o servidor limita aqui). ATENÇÃO: = ZONE_HALF_SIZE do servidor.
const WALK_HALF: float = WorldConstants.ZONE_HALF_SIZE


## Altura do chão (m) em ([param x], [param z]).
static func height_at(x: float, z: float) -> float:
	var ax: float = absf(x)
	var az: float = absf(z)
	if ax <= PLAZA_HALF and az <= PLAZA_HALF:
		return PLAZA_HEIGHT
	var stair: float = _stair_height(ax, az)
	if stair >= 0.0:
		return stair
	return field_height(x, z)


## true se ([param x], [param z]) está na praça (piso ou escadas).
static func is_plaza(x: float, z: float) -> bool:
	var ax: float = absf(x)
	var az: float = absf(z)
	return (ax <= PLAZA_HALF and az <= PLAZA_HALF) or _stair_height(ax, az) >= 0.0


## Altura do campo (sem a praça): plano perto do centro, morros suaves mais longe, subida na borda.
static func field_height(x: float, z: float) -> float:
	var hills: float = sin(x * 0.045) * 1.1 + cos(z * 0.038 + x * 0.02) * 1.3 + sin((x + z) * 0.09) * 0.4 + 0.2
	var away: float = smoothstep(FLAT_RADIUS, FLAT_RADIUS + 25.0, Vector2(x, z).length())
	var edge: float = smoothstep(EDGE_START, WALK_HALF, maxf(absf(x), absf(z)))
	return away * hills + edge * edge * EDGE_RISE


## Altura do degrau em (|x|, |z|), ou −1 fora das escadas.
static func _stair_height(ax: float, az: float) -> float:
	var depth: float = STEP_COUNT * STEP_RUN
	for pair: Vector2 in [Vector2(ax, az), Vector2(az, ax)]:
		# pair.x = distância no eixo da escada; pair.y = deslocamento lateral.
		if pair.y <= STAIR_HALF_WIDTH and pair.x > PLAZA_HALF and pair.x <= PLAZA_HALF + depth:
			var step: int = mini(STEP_COUNT - 1, int((pair.x - PLAZA_HALF) / STEP_RUN))
			return PLAZA_HEIGHT - STEP_RISE * (step + 1)
	return -1.0
