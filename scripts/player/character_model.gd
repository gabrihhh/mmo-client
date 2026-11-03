class_name CharacterModel
extends Node3D
## Personagem na tela ([ART-03]): esqueleto + malha, animação ([CharacterAnimator]) e itens vestidos ([EquipmentView]).
##
## A cena (assets/placeholders/character.tscn) é gerada por tools/placeholders/make_character.gd; o modelo final
## do Blender entra no lugar dela com os mesmos nomes de ossos. O modelo olha para +Z: quem usa gira 180° em Y
## (o personagem do jogo olha para −Z).

## Biblioteca de animações do personagem (placeholder gerado junto com a cena).
const ANIMATIONS_PATH: String = "res://assets/placeholders/character_animations.tres"
## Superfície da malha que é a camisa (a primeira cor gerada): o jogo pinta por cima.
const SHIRT_SURFACE: int = 0

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var _body: MeshInstance3D = $Skeleton3D/Body

var _animator: CharacterAnimator = null
var _equipment: EquipmentView = null
## Brilho de lançamento na mão (um só por personagem, reaproveitado).
var _glow: MeshInstance3D = null
var _glow_material: StandardMaterial3D = null
var _glow_left: float = 0.0
var _glow_total: float = 0.0

## Raio máximo (m) do brilho de lançamento.
const GLOW_RADIUS: float = 0.13


func _ready() -> void:
	_animator = CharacterAnimator.new()
	_animator.name = "Animator"
	add_child(_animator)
	var library: AnimationLibrary = load(ANIMATIONS_PATH) as AnimationLibrary
	if library != null:
		_animator.setup(library)
	_equipment = EquipmentView.new()
	_equipment.name = "Equipment"
	add_child(_equipment)
	_equipment.setup(skeleton)


## Cor da camisa (azul = você, vermelho = os outros).
func set_shirt_color(color: Color) -> void:
	var base: Material = _body.mesh.surface_get_material(SHIRT_SURFACE)
	var material: StandardMaterial3D = (base.duplicate() as StandardMaterial3D) if base is StandardMaterial3D else StandardMaterial3D.new()
	material.albedo_color = color
	_body.set_surface_override_material(SHIRT_SURFACE, material)


## Passa a mostrar o que [param state] veste ([member PlayerState.look]).
func bind_look(state: PlayerState) -> void:
	_equipment.bind(state)


## Velocidade de movimento como fração da normal (0 = parado, 1 = correndo).
func set_move_speed(ratio: float) -> void:
	_animator.set_move_speed(ratio)


## Ação de tronco/braços sincronizada com o lançamento ([method CharacterAnimator.play_action]).
func play_action(animation_name: String, duration: float) -> void:
	_animator.play_action(animation_name, duration)


## Interrompe a ação em andamento.
func stop_action() -> void:
	_animator.stop_action()


## Recuo ao apanhar.
func flinch() -> void:
	_animator.flinch()


## Brilho na mão durante o lançamento de uma magia ([JOGO-08]): cresce até o momento do efeito e some.
func show_cast_glow(color: Color, seconds: float) -> void:
	if _glow == null:
		_create_glow()
	if _glow == null:
		return
	_glow_material.albedo_color = color.lightened(0.3)
	_glow_total = maxf(seconds, 0.1)
	_glow_left = _glow_total
	_glow.visible = true


func _process(delta: float) -> void:
	if _glow == null or _glow_left <= 0.0:
		return
	_glow_left -= delta
	var t: float = 1.0 - clampf(_glow_left / _glow_total, 0.0, 1.0)
	_glow.scale = Vector3.ONE * lerpf(0.25, 1.0, t) * (1.0 + 0.12 * sin(t * 40.0))
	if _glow_left <= 0.0:
		_glow.visible = false


func _create_glow() -> void:
	if skeleton.find_bone("RightHand") < 0:
		return
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "CastGlowMount"
	attachment.bone_name = "RightHand"
	skeleton.add_child(attachment)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = GLOW_RADIUS
	sphere.height = GLOW_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow = MeshInstance3D.new()
	_glow.mesh = sphere
	_glow.material_override = _glow_material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position = Vector3(0.0, -0.08, 0.12)  # na frente do punho
	_glow.visible = false
	attachment.add_child(_glow)


## Posição (global) de onde saem as magias: um pouco acima da mão da arma.
func cast_point() -> Vector3:
	var bone: int = skeleton.find_bone("RightHand")
	if bone < 0:
		return global_position + Vector3.UP * 1.2
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin + Vector3.UP * 0.15
