class_name ChatBubble
extends Node3D
## Balão de fala do chat Geral ([SOC-09]) em cima da cabeça de quem falou: um balão **2D** (painel branco com
## borda escura e rabinho apontando para a cabeça), sempre de frente para a tela, centralizado com a ponta do
## rabinho [constant GAP_ABOVE_NAME_PX] px acima do nome. Entra com uma animação de fala (cresce a partir do rabinho
## com um pequeno "pulo"), fica [constant SECONDS] s e some aos poucos. Só para quem está na tela (o nó só existe
## para quem está na área de visão, [INFRA-11]).
##
## O nó 3D marca o ponto acima da cabeça (segue o boneco); o balão é um [Control] filho, desenhado no canvas da
## tela (abaixo da HUD) e reposicionado a cada quadro pela projeção da câmera ([method to_screen]).

## Quanto tempo (s) o balão fica.
const SECONDS: float = 5.0
## Máximo de caracteres mostrados (o resto vira "…").
const MAX_CHARS: int = 60
## Folga (px na tela) entre o topo das letras do nome e a ponta do rabinho.
const GAP_ABOVE_NAME_PX: float = 5.0
## Topo do nome desenhado (letras + contorno), em múltiplos da altura da linha (font_size × pixel_size) acima do
## nó do nome (medido na tela com a câmera do jogo).
const NAME_GLYPH_RATIO: float = 1.2
## Sem nome visível: a ponta fica este tanto (m) acima do nó da barra de vida (`HealthBar`); sem barra, altura fixa
## (m) acima dos pés.
const ABOVE_HEALTH_BAR_M: float = 0.1
const FALLBACK_HEIGHT_M: float = 2.25
## Largura máxima do texto (px no espaço de referência 720×1280); texto curto deixa o balão mais estreito.
const MAX_TEXT_WIDTH_PX: float = 300.0
## Tamanho da fonte (px).
const FONT_PX: int = 24
## Altura do rabinho (px) e metade da largura dele na base.
const TAIL_HEIGHT_PX: float = 14.0
const TAIL_HALF_WIDTH_PX: float = 11.0
## Espessura da borda (px).
const BORDER_PX: int = 4
## Duração (s) da animação de entrada e do sumiço no fim.
const POP_SECONDS: float = 0.28
const FADE_SECONDS: float = 0.5
## Cores: fundo, borda e texto.
const FILL_COLOR: Color = Color(1.0, 0.99, 0.94)
const BORDER_COLOR: Color = Color(0.1, 0.07, 0.05)
const TEXT_COLOR: Color = Color(0.12, 0.09, 0.07)

## Tema da HUD (fonte pixel art): o balão fica fora da árvore da HUD e não herda o tema dela.
const UI_THEME: Theme = preload("res://assets/ui/theme.tres")

var _left: float = SECONDS
var _text: String = ""
var _panel: PanelContainer = null
var _label: Label = null
## Rabinho: a borda (escura, maior) por baixo e o preenchimento por cima.
var _tail_border: Polygon2D = null
var _tail_fill: Polygon2D = null
## Folga (px) acima do ponto 3D: [constant GAP_ABOVE_NAME_PX] quando o ponto é o topo do nome, 0 nos outros casos.
var _gap_px: float = 0.0


## Mostra [param text] em cima de [param entity] (troca o balão anterior, se houver).
static func show_on(entity: Node3D, text: String) -> void:
	var old: Node = entity.get_node_or_null("ChatBubble")
	if old != null:
		old.queue_free()
		entity.remove_child(old)
	var bubble: ChatBubble = ChatBubble.new()
	bubble.name = "ChatBubble"
	bubble._text = text if text.length() <= MAX_CHARS else text.substr(0, MAX_CHARS - 1) + "…"
	var name_label: Label3D = entity.get_node_or_null("NameLabel") as Label3D
	var health_bar: Node3D = entity.get_node_or_null("HealthBar") as Node3D
	if name_label != null and name_label.visible:
		# O nome cresce para cima a partir do nó (alinhado embaixo): o ponto é o topo das letras, [constant NAME_GLYPH_RATIO]
		# × a altura da linha (font_size × pixel_size). Não usa get_aabb(): no Label3D virado para a câmera ela vem inflada.
		var text_height: float = float(name_label.font_size) * name_label.pixel_size * NAME_GLYPH_RATIO
		bubble.position = Vector3(0.0, name_label.position.y + text_height, 0.0)
		bubble._gap_px = GAP_ABOVE_NAME_PX
	elif health_bar != null:
		bubble.position = Vector3(0.0, health_bar.position.y + ABOVE_HEALTH_BAR_M, 0.0)
	else:
		bubble.position = Vector3(0.0, FALLBACK_HEIGHT_M, 0.0)
	entity.add_child(bubble)


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UI_THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(BORDER_PX)
	style.set_corner_radius_all(8)
	style.anti_aliasing = false
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = _text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_PX)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_label)

	_tail_border = Polygon2D.new()
	_tail_border.color = BORDER_COLOR
	_panel.add_child(_tail_border)
	_tail_fill = Polygon2D.new()
	_tail_fill.color = FILL_COLOR
	_panel.add_child(_tail_fill)

	add_child(_panel)
	# Texto curto → balão estreito; longo → quebra linha em MAX_TEXT_WIDTH_PX.
	var font: Font = _label.get_theme_font("font")
	var text_width: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_PX).x
	var width: float = minf(ceilf(text_width) + 2.0, MAX_TEXT_WIDTH_PX)
	_label.custom_minimum_size.x = width
	# A altura do texto com quebra de linha depende da largura atual do Label: dá a largura antes de medir, e mede
	# de novo no fim do quadro (depois que o container arrumou o Label).
	_label.size = Vector2(width, 0.0)
	_refit()
	_refit.call_deferred()

	# Animação de fala: nasce pequeno no rabinho e cresce com um "pulo" (passa um pouco do tamanho e volta).
	_panel.scale = Vector2(0.2, 0.2)
	var pop: Tween = _panel.create_tween()
	pop.tween_property(_panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	_panel.modulate.a = clampf(_left / FADE_SECONDS, 0.0, 1.0)
	_place()


## Ponto 3D [param point] → posição na tela (px do canvas), igual a onde a câmera desenha o ponto.
##
## Na projeção "frustum" (a da [IsometricCamera] em perspectiva: lente descentralizada pelo `screen_focus_y` para o
## boneco ficar acima dos controles, [CLI-02]) [method Camera3D.unproject_position] e
## [method Camera3D.get_camera_projection] aplicam o deslocamento com outra proporção que a do desenho e erram a
## altura (medido em 2026-11-19: pé desenhado a 38,6% da altura da tela, eles diziam 32,8%; o balão ficava bem acima
## da cabeça). Aqui a conta é a do desenho: o ponto vai para o plano "near" e é medido contra o retângulo do
## frustum (`size` no eixo travado pelo `keep_aspect`, deslocado por `frustum_offset`). Outras projeções: o
## [method Camera3D.unproject_position] acerta.
static func to_screen(camera: Camera3D, point: Vector3) -> Vector2:
	if camera.projection != Camera3D.PROJECTION_FRUSTUM:
		return camera.unproject_position(point)
	var screen_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var view_point: Vector3 = camera.get_camera_transform().affine_inverse() * point
	if view_point.z >= -0.0001 or screen_size.y <= 0.0:
		return screen_size * 0.5
	var aspect: float = screen_size.x / screen_size.y
	var half_width: float = camera.size * 0.5
	var half_height: float = half_width / aspect
	if camera.keep_aspect == Camera3D.KEEP_HEIGHT:
		half_height = camera.size * 0.5
		half_width = half_height * aspect
	var on_near: Vector2 = Vector2(view_point.x, view_point.y) * (camera.near / -view_point.z)
	var ndc: Vector2 = Vector2((on_near.x - camera.frustum_offset.x) / half_width, (on_near.y - camera.frustum_offset.y) / half_height)
	return Vector2((ndc.x + 1.0) * 0.5 * screen_size.x, (1.0 - ndc.y) * 0.5 * screen_size.y)


## Põe a ponta do rabinho no ponto acima da cabeça, na tela; esconde se a câmera não vê o ponto.
func _place() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(global_position) or not is_visible_in_tree():
		_panel.visible = false
		return
	_panel.visible = true
	var tip: Vector2 = to_screen(camera, global_position)
	var size: Vector2 = _panel.size
	_panel.position = tip - Vector2(size.x * 0.5, size.y + TAIL_HEIGHT_PX + _gap_px)


## Encolhe o painel para o tamanho do texto e refaz o rabinho.
func _refit() -> void:
	_panel.reset_size()
	_layout_tail()
	_place()


## Rabinho centralizado embaixo do painel e o pivô da animação na ponta dele.
func _layout_tail() -> void:
	var size: Vector2 = _panel.size
	var center: float = size.x * 0.5
	var bottom: float = size.y
	var b: float = float(BORDER_PX)
	_tail_border.polygon = PackedVector2Array([
		Vector2(center - TAIL_HALF_WIDTH_PX - b, bottom - b),
		Vector2(center + TAIL_HALF_WIDTH_PX + b, bottom - b),
		Vector2(center, bottom + TAIL_HEIGHT_PX),
	])
	# O preenchimento cobre a borda de baixo do painel no encontro com o rabinho (fica "aberto" para ele).
	_tail_fill.polygon = PackedVector2Array([
		Vector2(center - TAIL_HALF_WIDTH_PX, bottom - b - 1.0),
		Vector2(center + TAIL_HALF_WIDTH_PX, bottom - b - 1.0),
		Vector2(center, bottom + TAIL_HEIGHT_PX - b * 1.6),
	])
	_panel.pivot_offset = Vector2(center, bottom + TAIL_HEIGHT_PX)
