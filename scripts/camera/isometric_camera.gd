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
## Campo de visão HORIZONTAL (graus) quando em perspectiva. Horizontal porque o jogo é em retrato:
## a largura é a dimensão curta, então é ela que fixamos (a altura visível cresce com a tela).
@export_range(35.0, 60.0) var perspective_fov: float = 45.0
## Largura da área visível (m) quando ortográfica.
@export_range(14.0, 30.0) var orthographic_size: float = 22.0
## Distância da câmera até o ponto focado, em metros.
@export var distance: float = 30.0
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


## Aplica rotação e projeção a partir dos @export (chame após mudar algum).
func apply_settings() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	keep_aspect = Camera3D.KEEP_WIDTH
	match projection_mode:
		ProjectionMode.PERSPECTIVE:
			projection = Camera3D.PROJECTION_PERSPECTIVE
			fov = perspective_fov
		ProjectionMode.ORTHOGRAPHIC:
			projection = Camera3D.PROJECTION_ORTHOGONAL
			size = orthographic_size


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
