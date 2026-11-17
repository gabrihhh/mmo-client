class_name ToonMaterials
extends RefCounted
## Visual de anime dos personagens ([ART-12]): troca o material de cada malha de um personagem (corpo, roupas,
## armas; jogadores, NPCs e zumbis) por um de cel shading (sombra em 2 tons, toon.gdshader) com contorno escuro
## (toon_outline.gdshader, next_pass), mantendo a textura e a cor do material original.
##
## Chamado pelo [CharacterModel] (corpo) e pelo [EquipmentView] (itens, sempre que a roupa muda). A troca é por
## superfície ([method MeshInstance3D.set_surface_override_material]); o brilho dos itens melhorados ([ItemGlow])
## fica no material_overlay e continua por cima.
## Não converte: material que já é shader (brilhos, efeitos), transparente de verdade (alfa misturado) e malhas
## com material_override (ex.: o brilho de lançamento na mão) ou marcadas com o meta [constant SKIP_META].

const SHADER: Shader = preload("res://assets/shaders/toon.gdshader")
const CUTOUT_SHADER: Shader = preload("res://assets/shaders/toon_cutout.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/toon_outline.gdshader")
const OUTLINE_CUTOUT_SHADER: Shader = preload("res://assets/shaders/toon_outline_cutout.gdshader")
## Meta que deixa uma malha (e as filhas) de fora.
const SKIP_META: StringName = &"no_toon"
## Espessura (m) do contorno. Câmera do jogo a 12 m ([CLI-02]): ~1,5 px num celular de 1080 px de largura.
const OUTLINE_WIDTH_M: float = 0.014
## Cor do contorno = cor da peça × isto.
const OUTLINE_DARKNESS: float = 0.18
## Textura branca 1×1 para material sem textura (a cor vem de albedo_color).
static var _white: Texture2D = null

## Material original → material de anime (peças iguais dividem o mesmo; o Godot não recompila o shader).
static var _cache: Dictionary[Material, ShaderMaterial] = {}


## Converte todas as malhas de [param root] e filhas (as já convertidas são puladas).
static func apply(root: Node) -> void:
	if root.has_meta(SKIP_META):
		return
	if root is MeshInstance3D:
		_apply_mesh(root as MeshInstance3D)
	for child: Node in root.get_children():
		apply(child)


static func _apply_mesh(instance: MeshInstance3D) -> void:
	# material_override (ex.: brilho de lançamento, efeitos) manda em todas as superfícies: fica como está.
	if instance.mesh == null or instance.material_override != null:
		return
	for surface: int in range(instance.mesh.get_surface_count()):
		var current: Material = instance.get_active_material(surface)
		var toon: ShaderMaterial = to_toon(current)
		if toon != null and toon != current:
			instance.set_surface_override_material(surface, toon)


## Material de anime equivalente a [param source]; null se não for para converter. Um material que já é de anime
## volta ele mesmo.
static func to_toon(source: Material) -> ShaderMaterial:
	if source == null:
		return null
	if source is ShaderMaterial:
		var shader: Shader = (source as ShaderMaterial).shader
		return source as ShaderMaterial if shader == SHADER or shader == CUTOUT_SHADER else null
	if not (source is BaseMaterial3D):
		return null
	if _cache.has(source):
		return _cache[source]
	var base: BaseMaterial3D = source as BaseMaterial3D
	if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
			or base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		return null
	var cutout: bool = base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
		or base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var texture: Texture2D = base.albedo_texture if base.albedo_texture != null else _white_texture()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CUTOUT_SHADER if cutout else SHADER
	_set_color(material, base, texture)
	var outline: ShaderMaterial = ShaderMaterial.new()
	outline.shader = OUTLINE_CUTOUT_SHADER if cutout else OUTLINE_SHADER
	_set_color(outline, base, texture)
	outline.set_shader_parameter("width", OUTLINE_WIDTH_M)
	outline.set_shader_parameter("darkness", OUTLINE_DARKNESS)
	if cutout:
		var cut: float = base.alpha_scissor_threshold if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5
		material.set_shader_parameter("alpha_cut", cut)
		outline.set_shader_parameter("alpha_cut", cut)
	material.next_pass = outline
	_cache[source] = material
	return material


static func _set_color(material: ShaderMaterial, base: BaseMaterial3D, texture: Texture2D) -> void:
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("albedo_color", base.albedo_color)
	material.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)


static func _white_texture() -> Texture2D:
	if _white == null:
		var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
