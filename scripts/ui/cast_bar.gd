class_name CastBar
extends Control
## Barra de carregamento do lançamento ([CLI-08]): aparece logo acima da moldura dos controles enquanto o SEU personagem
## carrega uma ação — o golpe do ataque simples, ou o tempo de invocação de uma carta — e some quando ela sai (no
## projétil, quando o tiro sai da mão). Só para o jogador saber quanto falta; não decide nada.
##
## Pixel art como o resto da HUD: à esquerda o ícone (imagem da carta, ou a espada no ataque simples) num quadro com o
## fundo das cartas (`card.png`); à direita a barra, com o mesmo fundo/borda (começo e fim sempre visíveis) e o
## preenchimento **branco** (igual para todas as ações; só o ícone muda) avançando da esquerda para a direita, com
## marcas no começo e no fim.

## Quadro em pixel art (fundo das cartas, 9-slice; [CLI-07]).
const FRAME: Texture2D = preload("res://assets/ui/pixel/card.png")
## Margem do 9-slice do quadro (px) e a borda desenhada nele (px): o conteúdo fica dentro dela.
const FRAME_MARGIN: int = 12
const FRAME_BORDER: float = 9.0
## Espada do ataque simples (a mesma do botão de ataque).
const SWORD: Texture2D = preload("res://assets/ui/pixel/sword.png")
## Cor do preenchimento (todas as ações) e do fundo vazio da barra.
const FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const EMPTY_COLOR: Color = Color(0.05, 0.05, 0.08, 0.85)
## Espaço (px) entre o quadro do ícone e a barra.
const GAP: float = 8.0

var _icon: Texture2D = null
## Instante (ms) do começo e duração (s) do carregamento em curso; duração 0 = nada carregando.
var _start_ms: int = 0
var _duration_s: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(false)


## Mostra a barra carregando por [param seconds] s com [param icon] (null = espada, ataque simples). 0 s = nada.
func start(icon: Texture2D, seconds: float) -> void:
	if seconds <= 0.0:
		stop()
		return
	_icon = icon if icon != null else SWORD
	_start_ms = Time.get_ticks_msec()
	_duration_s = seconds
	visible = true
	set_process(true)
	queue_redraw()


## Esconde (a ação saiu ou foi cancelada).
func stop() -> void:
	_duration_s = 0.0
	visible = false
	set_process(false)


## Fração carregada (0..1).
func progress() -> float:
	if _duration_s <= 0.0:
		return 0.0
	return clampf(float(Time.get_ticks_msec() - _start_ms) / 1000.0 / _duration_s, 0.0, 1.0)


func _process(_delta: float) -> void:
	if progress() >= 1.0:
		stop()
		return
	queue_redraw()


func _draw() -> void:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = FRAME
	box.set_texture_margin_all(FRAME_MARGIN)
	# Ícone num quadro quadrado à esquerda.
	var icon_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.y, size.y))
	draw_style_box(box, icon_rect)
	if _icon != null:
		draw_texture_rect(_icon, icon_rect.grow(-FRAME_BORDER - 2.0), false)
	# Barra: quadro inteiro (o fim fica sempre à vista), fundo escuro e o branco avançando.
	var bar_rect: Rect2 = Rect2(Vector2(size.y + GAP, 0.0), Vector2(size.x - size.y - GAP, size.y))
	draw_style_box(box, bar_rect)
	var inner: Rect2 = bar_rect.grow(-FRAME_BORDER - 3.0)
	draw_rect(inner, EMPTY_COLOR)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * progress(), inner.size.y)), FILL_COLOR)
	# Marcas de começo e fim (pixel): o jogador vê de onde sai e onde termina.
	var mark: Color = Color(1.0, 0.85, 0.45, 1.0)
	draw_rect(Rect2(inner.position - Vector2(3.0, 3.0), Vector2(3.0, inner.size.y + 6.0)), mark)
	draw_rect(Rect2(Vector2(inner.end.x, inner.position.y - 3.0), Vector2(3.0, inner.size.y + 6.0)), mark)
