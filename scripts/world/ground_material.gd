class_name GroundMaterial
extends RefCounted
## Material do chão de grama ([MUN-04]): shader `assets/shaders/ground_grass.gdshader` com a textura
## `assets/textures/grass.png` (gerada por `tools/world/make_grass_texture.gd`). Cor = a pintada no Blender (cor por
## vértice) × a grama projetada de cima (coordenadas do mundo, a malha não precisa de UV) × uma variação grande para a
## repetição não aparecer.
## Um material só, dividido por todos os blocos do chão (um draw call por bloco, como antes).

const SHADER: Shader = preload("res://assets/shaders/ground_grass.gdshader")
const GRASS: Texture2D = preload("res://assets/textures/grass.png")
## Malhas do mapa que levam este material: os blocos de `jogo_chao` exportados do Blender ([ART-10], nome
## `zona_<objeto>_<i>_<j>`). ATENÇÃO: nome do objeto em workspace-blender/spawn.blend.
const GROUND_PREFIX: String = "zona_jogo_chao"

static var _material: ShaderMaterial = null


## O material (criado uma vez).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("grass_texture", GRASS)
	return _material


## true se a malha [param node] do mapa é do chão de grama.
static func is_ground(node: Node) -> bool:
	return node.name.begins_with(GROUND_PREFIX)
