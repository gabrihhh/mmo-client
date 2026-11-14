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

## Bytes da imagem (RGB, linha a linha em z), carregados na primeira consulta e lidos direto (sem converter os
## 410 mil pontos de uma vez: no celular isso travava o quadro ao entrar na zona).
static var _data: PackedByteArray = PackedByteArray()
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
	var top: float = lerpf(_point(i, j), _point(i + 1, j), fx)
	var bottom: float = lerpf(_point(i, j + 1), _point(i + 1, j + 1), fx)
	return lerpf(top, bottom, fz)


## Carrega a imagem das alturas (chamado sozinho na primeira consulta; o [Zone1Scenery] chama ao montar o cenário).
static func preload_heights() -> void:
	if _side == 0:
		_load()


## Altura (m) do ponto (i, j) da grade.
static func _point(i: int, j: int) -> float:
	var k: int = (j * _side + i) * 3
	return (_data[k] * 256 + _data[k + 1] - HEIGHT_OFFSET_CM) / 100.0


static func _load() -> void:
	var image: Image = load(HEIGHT_IMAGE) as Image
	if image == null or image.get_width() != image.get_height() or image.get_width() < 2:
		push_error("ZoneTerrain: não li a altura do chão em %s (rodar tools/blender/export_zone.py)" % HEIGHT_IMAGE)
		return
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	_data = image.get_data()
	_side = image.get_width()
