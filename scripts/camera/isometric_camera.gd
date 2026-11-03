class_name IsometricCamera
extends Camera3D
## Câmera isométrica que segue um alvo (estilo Albion). Ver mmo-docs [CLI-02].
##
## Fica como filha do jogador na cena, mas usa top_level para não herdar a
## rotação dele: só a posição acompanha o alvo.

enum ProjectionMode { PERSPECTIVE, ORTHOGRAPHIC }

## Nó seguido. Vazio = usa o nó pai.
@export var target: Node3D
## Inclinação (eixo X), em graus.
@export var pitch_degrees: float = -45.0
## Giro (eixo Y), em graus. O movimento do jogador é relativo a este ângulo.
@export var yaw_degrees: float = 45.0
@export var projection_mode: ProjectionMode = ProjectionMode.PERSPECTIVE
## Campo de visão HORIZONTAL (graus) na tela de referência ([member reference_aspect]), em perspectiva.
@export_range(35.0, 60.0) var perspective_fov: float = 45.0
## Largura da área visível (m) na tela de referência, quando ortográfica.
@export_range(14.0, 30.0) var orthographic_size: float = 22.0
## Proporção (largura ÷ altura) da tela de referência: 9:16 em retrato. A área visível de QUALQUER
## aparelho cabe dentro da área desta tela: ninguém enxerga mais do que ela (justiça no PvP). Tela mais
## comprida corta os lados; mais larga corta em cima/embaixo. Ver mmo-docs [CLI-02].
@export var reference_aspect: float = 9.0 / 16.0
## Distância da câmera até o ponto focado, em metros.
@export var distance: float = 10.0
## Altura do ponto focado acima da origem do alvo (meio do personagem de 1.8 m).
@export var focus_height: float = 0.9
## Suavidade do acompanhamento. 0 = colado no alvo.
@export var follow_smoothing: float = 10.0


func _ready() -> void:
	top_level = true
	if target == null:
		target = get_parent() as Node3D
	apply_settings()
	snap_to_target()
	get_viewport().size_changed.connect(apply_settings)


## Aplica rotação e projeção a partir dos @export e do formato da tela (chamado também quando a
## janela muda de tamanho).
func apply_settings() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = screen.x / screen.y if screen.y > 0.0 else reference_aspect
	# Mais comprida que a referência: trava a ALTURA da referência (corta os lados).
	# Mais larga (ou igual): trava a LARGURA da referência (corta em cima/embaixo).
	var lock_height: bool = aspect < reference_aspect
	keep_aspect = Camera3D.KEEP_HEIGHT if lock_height else Camera3D.KEEP_WIDTH
	match projection_mode:
		ProjectionMode.PERSPECTIVE:
			projection = Camera3D.PROJECTION_PERSPECTIVE
			if lock_height:
				# Abertura vertical da referência: tan(v/2) = tan(h/2) / proporção.
				var half_tan: float = tan(deg_to_rad(perspective_fov) / 2.0) / reference_aspect
				fov = rad_to_deg(2.0 * atan(half_tan))
			else:
				fov = perspective_fov
		ProjectionMode.ORTHOGRAPHIC:
			projection = Camera3D.PROJECTION_ORTHOGONAL
			size = orthographic_size / reference_aspect if lock_height else orthographic_size


## Posiciona a câmera no alvo sem suavização (ex.: após teleporte/spawn).
func snap_to_target() -> void:
	if target != null:
		global_position = _desired_position()


## Giro da câmera em radianos; usado para converter input de tela em direção no mundo.
func get_yaw_radians() -> float:
	return deg_to_rad(yaw_degrees)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = _desired_position()
	if follow_smoothing <= 0.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))


func _desired_position() -> Vector3:
	var focus: Vector3 = target.global_position + Vector3.UP * focus_height
	return focus + global_transform.basis.z * distance
