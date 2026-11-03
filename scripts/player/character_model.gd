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


## Recuo ao apanhar.
func flinch() -> void:
	_animator.flinch()


## Posição (global) de onde saem as magias: um pouco acima da mão da arma.
func cast_point() -> Vector3:
	var bone: int = skeleton.find_bone("RightHand")
	if bone < 0:
		return global_position + Vector3.UP * 1.2
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin + Vector3.UP * 0.15
