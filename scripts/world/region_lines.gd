class_name RegionLines
extends Node3D
## Linhas no chão marcando as zonas de nível ([JOGO-22]), na mesma cor de cada zona no mapa do Menu ([ZoneMap],
## [JOGO-18]). Cada zona desenha **meia linha**: uma faixa de [constant WIDTH] m que começa EM CIMA da divisa (o miolo
## brilhante) e se espalha só para dentro dela (a auréola). Onde duas zonas se encontram as metades se encostam: uma
## linha só, com as duas cores, cada lado brilhando na cor da sua zona. Seguem a altura do chão ([ZoneTerrain]).
## Trechos dentro das montanhas (perto da borda do mapa) não são desenhados.
##
## **Neon** (pedido do dono em 2026-11-17): shader [constant NEON_SHADER] — miolo fino quase branco + auréola na cor
## da zona espalhada pelo chão, somada à luz da cena (aditivo, sem glow de tela) e uma pulsação leve correndo pela linha.
##
## Leve: uma malha por zona, faixas planas (cor por vértice; UV.x = 0 na divisa → 1 dentro da zona, UV.y = metros ao
## longo da linha),
## cortadas em pedaços de [constant SEGMENT] m.

## Shader da linha neon.
const NEON_SHADER: Shader = preload("res://assets/shaders/neon_line.gdshader")
## Largura (m) da meia linha (miolo na divisa + auréola para dentro) e a altura acima do chão (m). O meio da faixa fica
## [constant INSET] m para dentro da zona, então a borda dela cai exatamente na divisa.
const WIDTH: float = 0.9
const INSET: float = WIDTH / 2.0
const LIFT: float = 0.08
## Pedaço (m) da linha que segue o chão (mais curto = acompanha melhor os degraus).
const SEGMENT: float = 2.0
## Trecho com as duas pontas além disto (m do centro, em X ou Z) fica de fora: é dentro das montanhas.
const EDGE_SKIP: float = 140.0


func _ready() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = NEON_SHADER
	for region: ZoneInfo.Region in ZoneInfo.regions():
		var color: Color = ZoneMap.REGION_COLORS[ZoneMap.region_band(region.min_level)]
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any: bool = false
		# Contorno de fora encolhido para dentro; buracos (a praça no meio da Campina) crescidos (dentro da zona = fora do buraco).
		for loop: PackedVector2Array in Geometry2D.offset_polygon(region.outer, -INSET):
			any = _add_loop(st, loop, color, region) or any
		for hole: PackedVector2Array in region.holes:
			for loop: PackedVector2Array in Geometry2D.offset_polygon(hole, INSET):
				any = _add_loop(st, loop, color, region) or any
		if not any:
			continue
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Linha_%s" % region.name
		instance.mesh = st.commit()
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## Faixa ao longo do polígono fechado [param loop] (x, z, o meio da faixa, já [constant INSET] m para dentro de
## [param region]). Devolve true se desenhou algum trecho.
func _add_loop(st: SurfaceTool, loop: PackedVector2Array, color: Color, region: ZoneInfo.Region) -> bool:
	var drew: bool = false
	# Metros já percorridos no contorno (UV.y: a pulsação corre contínua de um trecho para o outro).
	var along: float = 0.0
	for i: int in range(loop.size()):
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var length: float = a.distance_to(b)
		if _beyond(a) and _beyond(b):
			along += length
			continue
		if length < 0.01:
			continue
		var steps: int = maxi(1, ceili(length / SEGMENT))
		var side: Vector2 = (b - a).normalized().orthogonal() * (WIDTH / 2.0)
		# Qual lado da faixa é a divisa (UV.x = 0) e qual é dentro da zona (UV.x = 1): o sentido do contorno varia.
		var mid: Vector2 = (a + b) / 2.0
		var plus_inside: bool = _inside(region, mid + side * 2.0)
		var uv_plus: float = 1.0 if plus_inside else 0.0
		for k: int in range(steps):
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			var q: Vector2 = a.lerp(b, float(k + 1) / float(steps))
			var pv: float = along + length * float(k) / float(steps)
			var qv: float = along + length * float(k + 1) / float(steps)
			var p1: Vector3 = _ground(p + side)
			var p2: Vector3 = _ground(p - side)
			var q1: Vector3 = _ground(q + side)
			var q2: Vector3 = _ground(q - side)
			# (vértice, UV): UV.x = 0 no lado da divisa, 1 no lado de dentro da zona.
			var corners: Array[Array] = [[p1, Vector2(uv_plus, pv)], [q1, Vector2(uv_plus, qv)], [q2, Vector2(1.0 - uv_plus, qv)],
				[p1, Vector2(uv_plus, pv)], [q2, Vector2(1.0 - uv_plus, qv)], [p2, Vector2(1.0 - uv_plus, pv)]]
			for corner: Array in corners:
				var vertex: Vector3 = corner[0]
				var uv: Vector2 = corner[1]
				st.set_color(color)
				st.set_uv(uv)
				st.add_vertex(vertex)
		along += length
		drew = true
	return drew


## Ponto (x, z) dentro de [param region]: no contorno de fora e fora dos buracos (a praça no meio da Campina).
static func _inside(region: ZoneInfo.Region, point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, region.outer):
		return false
	for hole: PackedVector2Array in region.holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	return true


func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, ZoneTerrain.height_at(point.x, point.y) + LIFT, point.y)


static func _beyond(point: Vector2) -> bool:
	return maxf(absf(point.x), absf(point.y)) > EDGE_SKIP
