class_name RegionLines
extends Node3D
## Linhas no chão marcando as zonas de nível ([JOGO-22]), na mesma cor de cada zona no mapa do Menu ([ZoneMap],
## [JOGO-18]). Cada zona desenha a própria linha, de [constant WIDTH] m, começando EXATAMENTE na divisa e entrando nela:
## onde duas zonas se encontram as duas linhas ficam **lado a lado, encostadas** (sem vão), cada uma na cor da sua
## zona (dá para ver de que lado é cada uma). Seguem a altura do chão ([ZoneTerrain]).
## Trechos dentro das montanhas (perto da borda do mapa) não são desenhados.
##
## **Neon** (pedido do dono em 2026-11-17): shader [constant NEON_SHADER] — miolo claro no meio + auréola na cor da
## zona até a borda da linha, somada à luz da cena (aditivo, sem glow de tela) e uma pulsação leve correndo pela linha.
##
## Leve: uma malha por zona, faixas planas (cor por vértice; UV.x atravessa a faixa de 0 a 1, UV.y = metros ao longo
## da linha),
## cortadas em pedaços de [constant SEGMENT] m.

## Shader da linha neon.
const NEON_SHADER: Shader = preload("res://assets/shaders/neon_line.gdshader")
## Largura (m) da linha e a altura acima do chão (m). O meio da faixa fica [constant INSET] m para dentro da zona, então
## a borda dela cai exatamente na divisa e encosta na linha da zona vizinha.
const WIDTH: float = 0.5
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
			any = _add_loop(st, loop, color) or any
		for hole: PackedVector2Array in region.holes:
			for loop: PackedVector2Array in Geometry2D.offset_polygon(hole, INSET):
				any = _add_loop(st, loop, color) or any
		if not any:
			continue
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Linha_%s" % region.name
		instance.mesh = st.commit()
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## Faixa ao longo do polígono fechado [param loop] (x, z; o meio da faixa, já [constant INSET] m para dentro da zona).
## Devolve true se desenhou algum trecho.
func _add_loop(st: SurfaceTool, loop: PackedVector2Array, color: Color) -> bool:
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
		for k: int in range(steps):
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			var q: Vector2 = a.lerp(b, float(k + 1) / float(steps))
			var pv: float = along + length * float(k) / float(steps)
			var qv: float = along + length * float(k + 1) / float(steps)
			var p1: Vector3 = _ground(p + side)
			var p2: Vector3 = _ground(p - side)
			var q1: Vector3 = _ground(q + side)
			var q2: Vector3 = _ground(q - side)
			# (vértice, UV): UV.x = 0 de um lado da faixa, 1 do outro.
			var corners: Array[Array] = [[p1, Vector2(0.0, pv)], [q1, Vector2(0.0, qv)], [q2, Vector2(1.0, qv)],
				[p1, Vector2(0.0, pv)], [q2, Vector2(1.0, qv)], [p2, Vector2(1.0, pv)]]
			for corner: Array in corners:
				var vertex: Vector3 = corner[0]
				var uv: Vector2 = corner[1]
				st.set_color(color)
				st.set_uv(uv)
				st.add_vertex(vertex)
		along += length
		drew = true
	return drew


func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, ZoneTerrain.height_at(point.x, point.y) + LIFT, point.y)


static func _beyond(point: Vector2) -> bool:
	return maxf(absf(point.x), absf(point.y)) > EDGE_SKIP
