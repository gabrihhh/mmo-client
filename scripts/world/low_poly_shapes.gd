class_name LowPolyShapes
extends RefCounted
## Ajudantes para montar cenário low poly por código ([MUN-04]): triângulos soltos (cada face com a própria normal =
## visual facetado), caixas, cones, materiais e MultiMesh (milhares de cópias num desenho só).
## Usado pelo [MeadowScenery] (escolha de personagem) e pelo [Zone1Scenery] (zona 1).


## Triângulo [param a], [param b], [param c] (sentido horário visto de fora) com cor própria e normal da face.
static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertex)


## Quadrilátero (dois triângulos) [param a] → [param b] → [param c] → [param d].
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(st, a, b, c, color)
	triangle(st, a, c, d, color)


## Caixa centrada em [param center] com meia-medida [param half] (m). [param top_color] pinta só a face de cima.
static func box(st: SurfaceTool, center: Vector3, half: Vector3, color: Color, top_color: Color = Color(0, 0, 0, 0)) -> void:
	var p: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				p.append(center + Vector3(sx * half.x, sy * half.y, sz * half.z))
	# Índices: (x, y, z) → x*4 + y*2 + z.
	quad(st, p[1], p[3], p[7], p[5], color)  # +Z
	quad(st, p[4], p[6], p[2], p[0], color)  # −Z
	quad(st, p[5], p[7], p[6], p[4], color)  # +X
	quad(st, p[0], p[2], p[3], p[1], color)  # −X
	quad(st, p[2], p[6], p[7], p[3], top_color if top_color.a > 0.0 else color)  # +Y
	quad(st, p[0], p[1], p[5], p[4], color)  # −Y


## Cone de [param segments] lados, base em [param base] (raio [param radius], altura [param height]). [param jitter]
## (0..1) entorta base e pico com [param rng] para não ficar perfeito.
static func cone(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, radius: float, height: float, segments: int, color: Color, jitter: float) -> void:
	var tip: Vector3 = base + Vector3(rng.randf_range(-jitter, jitter) * radius * 0.3, height, rng.randf_range(-jitter, jitter) * radius * 0.3)
	var ring: Array[Vector3] = []
	for k: int in range(segments):
		var angle: float = TAU * k / segments
		var r: float = radius * (1.0 + rng.randf_range(-jitter, jitter))
		ring.append(base + Vector3(cos(angle) * r, 0.0, sin(angle) * r))
	for k: int in range(segments):
		var shade: float = 0.85 + 0.15 * cos(TAU * k / segments)
		triangle(st, ring[k], tip, ring[(k + 1) % segments], Color(color.r * shade, color.g * shade, color.b * shade))


## Disco (tampa) de [param segments] lados em [param center], virado para cima.
static func disc(st: SurfaceTool, center: Vector3, radius: float, segments: int, color: Color) -> void:
	for k: int in range(segments):
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		triangle(st, center, center + Vector3(cos(a0), 0.0, sin(a0)) * radius, center + Vector3(cos(a1), 0.0, sin(a1)) * radius, color)


## Material de cores por vértice (fosco, os dois lados).
static func material() -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.roughness = 0.95
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


## Fecha [param st] numa MeshInstance3D com o material de cores por vértice.
static func mesh_instance(st: SurfaceTool) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material()
	return instance


## MultiMesh de [param count] cópias de [param mesh] ([param colored] = cor por cópia).
static func multimesh(mesh: Mesh, count: int, colored: bool) -> MultiMesh:
	var result: MultiMesh = MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.use_colors = colored
	result.mesh = mesh
	result.instance_count = count
	return result


## Nó que desenha [param source] (sem sombra: flores e grama são muitas e pequenas).
static func multimesh_instance(source: MultiMesh) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = source
	instance.material_override = material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Caule de flor: lâmina fina de 0,3 m.
static func stem_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green: Color = Color(0.3, 0.55, 0.22)
	triangle(st, Vector3(-0.012, 0.0, 0.0), Vector3(0.012, 0.0, 0.0), Vector3(0.0, 0.31, 0.0), green)
	triangle(st, Vector3(0.0, 0.0, -0.012), Vector3(0.0, 0.0, 0.012), Vector3(0.0, 0.31, 0.0), green)
	return st.commit()


## Flor: 5 pétalas em leque, brancas (a cor vem de cada cópia do MultiMesh).
static func blossom_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petals: int = 5
	var center: Vector3 = Vector3(0.0, 0.015, 0.0)
	for k: int in range(petals):
		var angle: float = TAU * k / petals
		var tip: Vector3 = Vector3(cos(angle), 0.03, sin(angle)) * 0.11
		var left: Vector3 = Vector3(cos(angle - 0.45), 0.0, sin(angle - 0.45)) * 0.075
		var right: Vector3 = Vector3(cos(angle + 0.45), 0.0, sin(angle + 0.45)) * 0.075
		triangle(st, center, left, tip, Color.WHITE)
		triangle(st, center, tip, right, Color.WHITE)
	return st.commit()


## Tufo de grama: três folhas em pé.
static func tuft_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in range(3):
		var angle: float = TAU * k / 3.0
		var side: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.05
		var lean: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.06
		triangle(st, -side, side, Vector3(0.0, 0.22, 0.0) + lean, Color(0.36, 0.62, 0.25))
	return st.commit()
