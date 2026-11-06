class_name PixelLoader
extends Control
## Carregando em pixel art ([CLI-05]): uma fila de blocos quadrados com contorno escuro; uma "onda" dourada corre da
## esquerda para a direita sem parar (não diz quanto falta: é para esperas sem progresso conhecido, como "Entrando...").
## Desenhado por código em blocos inteiros (sem textura), nas cores da HUD pixel art ([CLI-08]).

## Quantos blocos na fila.
@export var block_count: int = 8
## Lado de cada bloco e espaço entre eles, em px.
@export var block_size: float = 22.0
@export var gap: float = 8.0
## Blocos por segundo que a onda anda.
@export var speed: float = 9.0

## Cores: contorno, bloco apagado e os dois tons do bloco aceso (miolo e brilho em cima).
const OUTLINE: Color = Color8(24, 16, 12)
const OFF: Color = Color8(52, 46, 40)
const ON: Color = Color8(246, 196, 82)
const ON_DARK: Color = Color8(170, 110, 34)
## Contorno em px (um "pixel" do desenho).
const BORDER: float = 3.0

var _phase: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(block_count * block_size + (block_count - 1) * gap, block_size)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase = fmod(_phase + delta * speed, float(block_count + 3))
	queue_redraw()


func _draw() -> void:
	var total: float = block_count * block_size + (block_count - 1) * gap
	var left: float = (size.x - total) / 2.0
	var top: float = (size.y - block_size) / 2.0
	for i: int in range(block_count):
		# Brilho do bloco: 1 na cabeça da onda, caindo nos 3 de trás.
		var behind: float = _phase - float(i)
		var glow: float = clampf(1.0 - behind / 3.0, 0.0, 1.0) if behind >= 0.0 else 0.0
		var rect: Rect2 = Rect2(left + i * (block_size + gap), top, block_size, block_size)
		draw_rect(rect, OUTLINE)
		var inner: Rect2 = rect.grow(-BORDER)
		draw_rect(inner, OFF.lerp(ON_DARK, glow))
		if glow > 0.0:
			# Miolo aceso e um filete de luz em cima (como as placas douradas da moldura).
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, BORDER)), OFF.lerp(ON.lightened(0.3), glow))
			draw_rect(Rect2(inner.position + Vector2(0, BORDER), inner.size - Vector2(0, BORDER * 2.0)), OFF.lerp(ON, glow))
