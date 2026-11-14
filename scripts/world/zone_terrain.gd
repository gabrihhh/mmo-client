class_name ZoneTerrain
extends RefCounted
## Altura do chão da zona 1 ([MUN-03]), vinda do mapa feito no Blender ([ART-10]): a imagem
## `assets/zones/zone_1/zone_1_height.png` é uma grade de [constant HEIGHT_STEP] m de −[constant HEIGHT_HALF] a
## +[constant HEIGHT_HALF] nos dois eixos, com a altura do chão (`jogo_chao`, `jogo_praca` e malhas soltas na coleção
## `Terreno`) em cada ponto. Refazer: `python3 tools/blender/export_zone.py`.
##
## [method height_at] é a ÚNICA fonte da altura: os personagens, avisos no chão, impactos e projéteis ficam em cima
## dela. Por enquanto a altura é só VISUAL: o servidor simula em X/Z (y fixo) e não sabe de degraus nem morros
## ([INFRA-09]). Quando o servidor precisar (quedas, linha de visão), lê a mesma imagem.

## Metade do lado da grade de alturas (m) e distância entre pontos (m). ATENÇÃO: = HEIGHT_HALF / HEIGHT_STEP em
## tools/blender/blender_export_zone.py.
const HEIGHT_HALF: float = 160.0
const HEIGHT_STEP: float = 0.5
## A altura vai em centímetros + este valor (para caber altura negativa) em 16 bits: vermelho = byte alto, verde =
## byte baixo. ATENÇÃO: = HEIGHT_OFFSET_CM do exportador.
const HEIGHT_OFFSET_CM: int = 10000
## Imagem das alturas (importada como Image, sem compressão).
const HEIGHT_IMAGE: String = "res://assets/zones/zone_1/zone_1_height.png"
## Círculo de pedra no centro da praça, onde os jogadores nascem (m). ATENÇÃO: o spawnRadius da zona no servidor
## (mmo-server/src/zones/zones.ts) fica dentro dele.
const SPAWN_CIRCLE_RADIUS: float = 4.5
## Metade do lado da área andável (o servidor limita aqui). ATENÇÃO: = ZONE_HALF_SIZE do servidor.
const WALK_HALF: float = WorldConstants.ZONE_HALF_SIZE

## Alturas (m) da grade, linha a linha (z), carregadas na primeira consulta.
static var _heights: PackedFloat32Array = PackedFloat32Array()
static var _side: int = 0


## Altura do chão (m) em ([param x], [param z]): interpolada entre os 4 pontos da grade em volta; fora da grade,
## a da borda.
static func height_at(x: float, z: float) -> float:
	if _side == 0:
		_load()
		if _side == 0:
			return 0.0
	var gx: float = clampf((x + HEIGHT_HALF) / HEIGHT_STEP, 0.0, _side - 1.0)
	var gz: float = clampf((z + HEIGHT_HALF) / HEIGHT_STEP, 0.0, _side - 1.0)
	var i: int = mini(int(gx), _side - 2)
	var j: int = mini(int(gz), _side - 2)
	var fx: float = gx - i
	var fz: float = gz - j
	var top: float = lerpf(_heights[j * _side + i], _heights[j * _side + i + 1], fx)
	var bottom: float = lerpf(_heights[(j + 1) * _side + i], _heights[(j + 1) * _side + i + 1], fx)
	return lerpf(top, bottom, fz)


static func _load() -> void:
	var image: Image = load(HEIGHT_IMAGE) as Image
	if image == null or image.get_width() != image.get_height() or image.get_width() < 2:
		push_error("ZoneTerrain: não li a altura do chão em %s (rodar tools/blender/export_zone.py)" % HEIGHT_IMAGE)
		return
	image.convert(Image.FORMAT_RGB8)
	var side: int = image.get_width()
	var data: PackedByteArray = image.get_data()
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(side * side)
	for k: int in range(side * side):
		var raw: int = data[k * 3] * 256 + data[k * 3 + 1]
		heights[k] = (raw - HEIGHT_OFFSET_CM) / 100.0
	_heights = heights
	_side = side
