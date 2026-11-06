class_name HealthBar3D
extends Node3D
## Barra acima da cabeça (vida ou mana), sempre de frente para a câmera. Ver mmo-docs [JOGO-05], [CLI-04].
## Só visual: chame [method set_ratio] com a fração (0..1). A cena do jogador usa duas: "HealthBar"
## (vermelha) logo abaixo do nome e "ManaBar" (azul, mais fina) logo abaixo dela.
## Vida com escudo ([method set_values]): o escudo aparece como **sobrevida azul-clara** logo depois do vermelho,
## sem a barra crescer para a direita — se vida + escudo passam do máximo, o azul cobre o fim da barra ([JOGO-06]).
##
## Monstros ([JOGO-13]): [method set_level_badge] põe um quadrado preto com o nível em ciano à esquerda da barra
## (mesmas cores do quadrado da HUD, [CLI-08]). A barra de lançamento deles também é um [HealthBar3D] (branca).
##
## O nó inteiro copia a rotação da câmera a cada quadro (em vez de billboard no material): assim o
## preenchimento, ancorado na borda esquerda do nó, encolhe para a esquerda da TELA.

## Tamanho da barra no mundo, em metros.
@export var bar_size: Vector2 = Vector2(0.85, 0.13)
## Cor do preenchimento (vida = vermelho; a ManaBar troca para azul na cena).
@export var fill_color: Color = Color(0.85, 0.2, 0.2)
## Cor do fundo (parte vazia).
@export var back_color: Color = Color(0, 0, 0, 0.6)
## Cor da sobrevida do escudo (por cima da vida).
@export var shield_color: Color = Color(0.55, 0.85, 1.0, 0.95)

## Lado do quadrado do nível, em metros.
const BADGE_SIZE: float = 0.22
## Cor do número do nível (ciano, igual à HUD).
const BADGE_TEXT_COLOR: Color = Color(0.0, 0.9, 1.0)

var _fill: MeshInstance3D = null
var _shield: MeshInstance3D = null
## Número do quadrado do nível (null até o primeiro [method set_level_badge]).
var _badge_label: Label3D = null


func _ready() -> void:
	_make_quad(back_color, Vector3.ZERO, 0)
	# O preenchimento começa na borda esquerda e encolhe para a esquerda.
	_fill = _make_quad(fill_color, Vector3(-bar_size.x / 2.0, 0.0, 0.001), 1)
	_shield = _make_quad(shield_color, Vector3(-bar_size.x / 2.0, 0.0, 0.002), 2)
	_shield.visible = false
	set_ratio(1.0)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		global_basis = camera.global_basis


## Fração de vida mostrada (0 = vazia, 1 = cheia).
func set_ratio(ratio: float) -> void:
	if _fill != null:
		_fill.scale.x = maxf(0.001, clampf(ratio, 0.0, 1.0))


## Vida ([param hp_ratio]) e escudo ([param shield_ratio], fração da vida máxima): o azul começa onde a vida acaba,
## mas nunca passa da borda — com vida cheia ele cobre o final da barra. Sem escudo, some.
func set_values(hp_ratio: float, shield_ratio: float) -> void:
	set_ratio(hp_ratio)
	if _shield == null:
		return
	var shield: float = clampf(shield_ratio, 0.0, 1.0)
	_shield.visible = shield > 0.001
	if not _shield.visible:
		return
	var start: float = clampf(minf(hp_ratio, 1.0 - shield), 0.0, 1.0)
	_shield.position.x = -bar_size.x / 2.0 + start * bar_size.x
	_shield.scale.x = maxf(0.001, shield)


## Mostra o quadrado do nível ([param level]) à esquerda da barra; criado na primeira chamada.
func set_level_badge(level: int) -> void:
	if _badge_label == null:
		var center: Vector3 = Vector3(-bar_size.x / 2.0 - 0.03 - BADGE_SIZE / 2.0, 0.0, 0.0)
		var square: MeshInstance3D = _make_quad(Color(0, 0, 0, 0.95), center, 0, Vector2(BADGE_SIZE, BADGE_SIZE))
		square.material_override.render_priority = 3
		_badge_label = Label3D.new()
		_badge_label.position = center + Vector3(0.0, 0.0, 0.003)
		_badge_label.pixel_size = 0.0045
		_badge_label.font_size = 40
		_badge_label.outline_size = 0
		_badge_label.modulate = BADGE_TEXT_COLOR
		_badge_label.no_depth_test = true
		_badge_label.render_priority = 4
		_badge_label.shaded = false
		add_child(_badge_label)
	_badge_label.text = str(level)


func _make_quad(color: Color, offset: Vector3, priority: int, size: Vector2 = Vector2.ZERO) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = bar_size if size == Vector2.ZERO else size
	# Com o centro deslocado meia barra, a escala X encolhe a partir da borda esquerda.
	quad.center_offset = Vector3(bar_size.x / 2.0, 0.0, 0.0) if priority > 0 and size == Vector2.ZERO else Vector3.ZERO
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = priority
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
