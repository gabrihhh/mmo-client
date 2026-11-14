class_name PixelMenuPanel
extends PanelContainer
## Base dos painéis do Menu feitos por código ([CLI-08]): moldura pixel art (variação `PixelPanel` do tema,
## [CLI-07]), centralizado na tela, com cabeçalho (título + X no canto superior direito), uma área de conteúdo
## ([member body]) e o botão "Voltar" embaixo. Quem herda só preenche [member body].
##
## Usado pelos painéis sociais ([SOC-02]: Jogadores Próximos, opções do jogador, Atributos); as próximas etapas
## (Grupo, Amigos) reaproveitam. A [Hud] abre/fecha (um painel por vez, fundo escurecido atrás).

## Tocou no X: fechar o menu inteiro.
signal close_pressed
## Tocou em "Voltar": volta para o painel anterior (a [Hud] decide qual).
signal back_pressed

## Largura do painel (px no espaço de referência 720×1280), igual à do Menu.
const PANEL_WIDTH_PX: float = 640.0
## Altura dos botões de lista/ação (px), igual à dos botões do Menu.
const BUTTON_HEIGHT_PX: float = 96.0
## Tamanho da fonte dos botões e do título (px).
const BUTTON_FONT_PX: int = 34
const TITLE_FONT_PX: int = 44
## Tamanho da fonte dos textos de conteúdo (px).
const TEXT_FONT_PX: int = 28

## Onde o painel filho põe o conteúdo (entre o cabeçalho e o "Voltar").
var body: VBoxContainer = null
## Botão "Voltar" (o filho pode esconder se não fizer sentido).
var back_button: Button = null

var _title: Label = null


## [param height_px] = altura fixa do painel (0 = só o necessário para o conteúdo).
func _init(height_px: float = 0.0) -> void:
	theme_type_variation = &"PixelPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	# Âncoras no centro e crescimento para os dois lados: o tamanho mínimo abre o painel centralizado.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(PANEL_WIDTH_PX, height_px)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	add_child(column)

	var header: Control = Control.new()
	header.custom_minimum_size = Vector2(0.0, 72.0)
	column.add_child(header)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_PX)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	# Não cobre o X.
	_title.offset_left = 76.0
	_title.offset_right = -76.0
	header.add_child(_title)
	var close: Button = make_button("✕")
	close.custom_minimum_size = Vector2(72.0, 72.0)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -72.0
	close.offset_bottom = 72.0
	close.pressed.connect(close_pressed.emit)
	header.add_child(close)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	back_button = make_button("Voltar")
	back_button.pressed.connect(back_pressed.emit)
	column.add_child(back_button)


## Troca o título do cabeçalho.
func set_title(text: String) -> void:
	_title.text = text


## Botão no estilo do Menu (`PixelButton`: fundo das cartas em pixel art), com o texto à esquerda se
## [param align_left].
static func make_button(text: String, align_left: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = &"PixelButton"
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT_PX)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_PX)
	button.focus_mode = Control.FOCUS_NONE
	if align_left:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	return button


## Texto de conteúdo (quebra linha se não couber).
static func make_label(text: String, color: Color = Color(1, 1, 1)) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TEXT_FONT_PX)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
