class_name LowPolyBuilder
extends RefCounted
## Monta malhas low poly simples (caixa, prisma, pirâmide, cúpula) para placeholders ([ART-02]).
##
## Cada peça tem uma cor (um material por cor: o .glb sai com poucos materiais) e normais "flat"
## (uma por triângulo), que dão a cara facetada do low poly. Medidas em metros ([MUN-01]);
## Y para cima e frente do modelo em +Z (padrão do glTF e do Godot para modelos).
##
## Uso: crie um, chame os métodos de forma e no fim [method build] devolve a [ArrayMesh].

## Triângulos acumulados por cor: cor → posições (3 por triângulo).
var _by_color: Dictionary[Color, PackedVector3Array] = {}


## Caixa centrada em [param center] com [param size] (m).
func box(center: Vector3, size: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i: int in range(8):
		c.append(center + Vector3(h.x if (i & 1) != 0 else -h.x, h.y if (i & 2) != 0 else -h.y, h.z if (i & 4) != 0 else -h.z))
	# Faces como quadriláteros em sentido anti-horário vistos de fora.
	_quad(c[0], c[4], c[6], c[2], color)  # -X
	_quad(c[1], c[3], c[7], c[5], color)  # +X
	_quad(c[0], c[1], c[5], c[4], color)  # -Y
	_quad(c[2], c[6], c[7], c[3], color)  # +Y
	_quad(c[0], c[2], c[3], c[1], color)  # -Z
	_quad(c[4], c[5], c[7], c[6], color)  # +Z


## Prisma vertical (cilindro low poly) de [param sides] lados, de [param y_bottom] a [param y_top] (m).
## Raios diferentes em cima e embaixo viram tronco de cone; [param top_radius] 0 vira cone.
## [param scale_xz] achata a seção (ex.: Vector2(1, 0.3) = lâmina).
func prism(sides: int, bottom_radius: float, top_radius: float, y_bottom: float, y_top: float, color: Color,
		scale_xz: Vector2 = Vector2.ONE, offset: Vector3 = Vector3.ZERO) -> void:
	var bottom: Array[Vector3] = _ring(sides, bottom_radius, y_bottom, scale_xz, offset)
	var top: Array[Vector3] = _ring(sides, top_radius, y_top, scale_xz, offset)
	var bottom_center: Vector3 = offset + Vector3(0.0, y_bottom, 0.0)
	var top_center: Vector3 = offset + Vector3(0.0, y_top, 0.0)
	for i: int in range(sides):
		var j: int = (i + 1) % sides
		if top_radius > 0.0:
			_quad(bottom[i], bottom[j], top[j], top[i], color)
			_tri(top_center, top[i], top[j], color)
		else:
			_tri(bottom[i], bottom[j], top_center, color)
		if bottom_radius > 0.0:
			_tri(bottom_center, bottom[j], bottom[i], color)


## Losango (duas pirâmides unidas pela base): pomo, cristal, pedra.
func gem(center: Vector3, radius: float, half_height: float, sides: int, color: Color) -> void:
	var mid: Array[Vector3] = _ring(sides, radius, center.y, Vector2.ONE, Vector3(center.x, 0.0, center.z))
	var top: Vector3 = center + Vector3(0.0, half_height, 0.0)
	var bottom: Vector3 = center - Vector3(0.0, half_height, 0.0)
	for i: int in range(sides):
		var j: int = (i + 1) % sides
		_tri(mid[i], mid[j], top, color)
		_tri(mid[i], bottom, mid[j], color)


## Meia esfera low poly (cúpula) com a base em [param base_y]: [param segments] em volta, [param rings] até o topo.
## [param height_scale] achata (1 = meia esfera redonda).
func dome(base_y: float, radius: float, segments: int, rings: int, height_scale: float, color: Color) -> void:
	var previous: Array[Vector3] = _ring(segments, radius, base_y, Vector2.ONE, Vector3.ZERO)
	for r: int in range(1, rings + 1):
		var angle: float = (PI * 0.5) * float(r) / float(rings)
		var y: float = base_y + sin(angle) * radius * height_scale
		var ring_radius: float = cos(angle) * radius
		if r == rings:
			var top: Vector3 = Vector3(0.0, y, 0.0)
			for i: int in range(segments):
				_tri(previous[i], previous[(i + 1) % segments], top, color)
		else:
			var current: Array[Vector3] = _ring(segments, ring_radius, y, Vector2.ONE, Vector3.ZERO)
			for i: int in range(segments):
				var j: int = (i + 1) % segments
				_quad(previous[i], previous[j], current[j], current[i], color)
			previous = current
	# Fundo fechado (o boné não fica oco por baixo).
	var center: Vector3 = Vector3(0.0, base_y, 0.0)
	var base: Array[Vector3] = _ring(segments, radius, base_y, Vector2.ONE, Vector3.ZERO)
	for i: int in range(segments):
		_tri(center, base[(i + 1) % segments], base[i], color)


## Quantos triângulos já foram adicionados (para conferir o orçamento de [ART-02]).
func triangle_count() -> int:
	var total: int = 0
	for positions: PackedVector3Array in _by_color.values():
		total += positions.size() / 3
	return total


## Gera a malha: uma superfície (e um material) por cor.
func build() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for color: Color in _by_color:
		var positions: PackedVector3Array = _by_color[color]
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(0, positions.size(), 3):
			var a: Vector3 = positions[i]
			var b: Vector3 = positions[i + 1]
			var c: Vector3 = positions[i + 2]
			var normal: Vector3 = (b - a).cross(c - a).normalized()
			# Godot usa sentido horário para a face da frente: a, c, b.
			for v: Vector3 in [a, c, b]:
				tool.set_normal(normal)
				tool.add_vertex(v)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		tool.set_material(material)
		tool.commit(mesh)
	return mesh


## Triângulo [a, b, c] em sentido anti-horário visto de fora (regra da mão direita: normal para fora).
func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# Packed arrays são copiados por valor: lê, aumenta e grava de volta.
	var positions: PackedVector3Array = _by_color.get(color, PackedVector3Array())
	positions.append_array(PackedVector3Array([a, b, c]))
	_by_color[color] = positions


## Quadrilátero [a, b, c, d] anti-horário visto de fora = dois triângulos.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(a, b, c, color)
	_tri(a, c, d, color)


## Pontos de um anel no plano XZ, na altura [param y]. Anti-horário visto de cima.
func _ring(sides: int, radius: float, y: float, scale_xz: Vector2, offset: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i: int in range(sides):
		var angle: float = TAU * float(i) / float(sides)
		points.append(offset + Vector3(cos(angle) * radius * scale_xz.x, y, -sin(angle) * radius * scale_xz.y))
	return points
