class_name ItemGlow
extends RefCounted
## Brilho dos itens melhorados no ferreiro ([JOGO-17], pedido do dono em 2026-11-15): cada conjunto tem uma cor
## (Assassino roxo, Atirador verde...). Nível 0 = nada. Do +1 ao +4 a peça ganha o brilho na cor do conjunto, **bem
## escuro**; a cada 5 níveis fica mais claro até a cor no brilho máximo (+[constant FULL_COLOR_LEVEL]); depois a cor
## vai se misturando com branco e aparecem faíscas brancas, até o **neon** final (+[constant NEON_LEVEL]: daí em diante
## não muda mais). Vale para arma e roupas, cada peça com o seu nível; todos veem ([member PlayerState.look_levels]).
## O efeito é uma passada extra por cima da peça ([member GeometryInstance3D.material_overlay]): leve brilho por
## dentro (shader item_glow) + contorno aceso em volta da silhueta (item_glow_outline, encadeado).

## Cor neon de cada conjunto, pela pasta do item em assets/itens (mage, knight...).
## Escolhidas para não repetir: Mago ciano (o cristal do cajado), Cavaleiro azul, Atirador verde,
## Assassino roxo, Curandeiro dourado.
const SET_COLORS: Dictionary[String, Color] = {
	"mage": Color(0.15, 0.9, 1.0),
	"knight": Color(0.2, 0.45, 1.0),
	"ranger": Color(0.2, 1.0, 0.3),
	"assassin": Color(0.65, 0.15, 1.0),
	"healer": Color(1.0, 0.82, 0.2),
}
## Cor de item de pasta desconhecida.
const DEFAULT_COLOR: Color = Color(1.0, 1.0, 1.0)
## Níveis por degrau de clareza.
const LEVELS_PER_STEP: int = 5
## Nível em que a cor chega ao brilho máximo (degrau 8) e em que o neon fica completo (degrau 12).
const FULL_COLOR_LEVEL: int = 40
const NEON_LEVEL: int = 60
## Clareza da cor no +1 (fração do brilho máximo) e quanto de branco no neon final.
const DARKEST: float = 0.18
const NEON_WHITE: float = 0.65
## Nível a partir do qual saem faíscas brancas (a cor já no máximo, começando a misturar branco).
const SPARKS_LEVEL: int = 45

const SHADER: Shader = preload("res://assets/shaders/item_glow.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/item_glow_outline.gdshader")
## Espessura (m) do contorno neon: no +1 e no neon final.
const OUTLINE_MIN_M: float = 0.004
const OUTLINE_MAX_M: float = 0.016

## Materiais já criados: "pasta|degrau" → material (todos os itens do mesmo conjunto e degrau dividem o mesmo).
static var _cache: Dictionary[String, ShaderMaterial] = {}


## Degrau do nível [param level] (0 = +1..+4; sobe a cada 5; para no neon).
static func step(level: int) -> int:
	return mini(level / LEVELS_PER_STEP, NEON_LEVEL / LEVELS_PER_STEP)


## Cor do brilho de um item do conjunto [param set_folder] no nível [param level] (> 0).
static func color(set_folder: String, level: int) -> Color:
	var base: Color = SET_COLORS.get(set_folder, DEFAULT_COLOR)
	var s: int = step(level)
	var full_steps: float = float(FULL_COLOR_LEVEL / LEVELS_PER_STEP)
	var neon_steps: float = float((NEON_LEVEL - FULL_COLOR_LEVEL) / LEVELS_PER_STEP)
	var brightness: float = lerpf(DARKEST, 1.0, clampf(float(s) / full_steps, 0.0, 1.0))
	var white: float = clampf((float(s) - full_steps) / neon_steps, 0.0, 1.0) * NEON_WHITE
	return (base * brightness).lerp(Color.WHITE, white)


## Material do brilho para o item [param item_id] no nível [param level]; null no nível 0.
static func material(item_id: String, level: int) -> ShaderMaterial:
	if level <= 0:
		return null
	var folder: String = set_folder(item_id)
	var s: int = step(level)
	var key: String = "%s|%d" % [folder, s]
	if _cache.has(key):
		return _cache[key]
	var progress: float = clampf(float(s) / float(NEON_LEVEL / LEVELS_PER_STEP), 0.0, 1.0)
	var glow: ShaderMaterial = ShaderMaterial.new()
	glow.shader = SHADER
	var c: Color = color(folder, level)
	glow.set_shader_parameter("glow_color", Vector3(c.r, c.g, c.b))
	# Neon = contorno aceso (casca por trás, OUTLINE_SHADER) + leve brilho por dentro: a peça continua aparecendo.
	# (Só o brilho por dentro, forte, pintava a peça inteira: as faces chapadas do low poly contam todas como borda.)
	glow.set_shader_parameter("fill", lerpf(0.0, 0.04, progress))
	glow.set_shader_parameter("energy", lerpf(0.35, 0.7, progress))
	glow.set_shader_parameter("rim_power", 4.0)
	var outline: ShaderMaterial = ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("glow_color", Vector3(c.r, c.g, c.b))
	outline.set_shader_parameter("width", lerpf(OUTLINE_MIN_M, OUTLINE_MAX_M, progress))
	glow.next_pass = outline
	_cache[key] = glow
	return glow


## Faíscas brancas no nível [param level]? (só no fim, quando a cor já está no máximo).
static func has_sparks(level: int) -> bool:
	return level >= SPARKS_LEVEL


## Quantas faíscas por vez (crescem até o neon).
static func spark_amount(level: int) -> int:
	return clampi(4 + 2 * (step(level) - SPARKS_LEVEL / LEVELS_PER_STEP), 4, 12)


## Pasta do conjunto do item ("assassin" de res://assets/itens/hand/assassin; a parte antes do "-" em pastas com hífen).
static func set_folder(item_id: String) -> String:
	var path: String = ItemModels.folder(item_id)
	return path.get_file().get_slice("-", 0) if not path.is_empty() else ""


## Põe o brilho em todas as malhas de [param root] (e filhas). [param glow] null tira.
static func apply(root: Node, glow: ShaderMaterial) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).material_overlay = glow
	for child: Node in root.get_children():
		apply(child, glow)


## Faíscas brancas em volta de [param parent] (a arma), [param amount] por vez.
static func make_sparks(amount: int) -> CPUParticles3D:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.name = "GlowSparks"
	sparks.amount = amount
	sparks.lifetime = 0.9
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.18
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 0.05
	sparks.initial_velocity_max = 0.2
	sparks.gravity = Vector3(0.0, 0.25, 0.0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_material.albedo_color = Color(1.0, 1.0, 1.0)
	quad.material = spark_material
	sparks.mesh = quad
	return sparks
