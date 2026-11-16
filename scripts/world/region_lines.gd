class_name RegionLines
extends Node3D
## Linhas no chão marcando as zonas de nível ([JOGO-22]), na mesma cor de cada zona no mapa do Menu ([ZoneMap],
## [JOGO-18]). Cada zona desenha a própria borda [constant INSET] m para DENTRO dela: onde duas zonas se encontram
## aparecem as duas cores lado a lado (dá para ver de que lado é cada uma). Seguem a altura do chão ([ZoneTerrain]).
## Trechos dentro das montanhas (perto da borda do mapa) não são desenhados.
##
## Leve: uma malha por zona, faixas planas sem luz (cor por vértice), cortadas em pedaços de [constant SEGMENT] m.

## Largura (m) da linha, quanto ela entra na zona e a altura acima do chão (m).
const WIDTH: float = 0.35
const INSET: float = 0.6
const LIFT: float = 0.08
## Pedaço (m) da linha que segue o chão (mais curto = acompanha melhor os degraus).
const SEGMENT: float = 2.0
## Trecho com as duas pontas além disto (m do centro, em X ou Z) fica de fora: é dentro das montanhas.
const EDGE_SKIP: float = 140.0


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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


## Faixa ao longo do polígono fechado [param loop] (x, z). Devolve true se desenhou algum trecho.
func _add_loop(st: SurfaceTool, loop: PackedVector2Array, color: Color) -> bool:
	var drew: bool = false
	for i: int in range(loop.size()):
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		if _beyond(a) and _beyond(b):
			continue
		var length: float = a.distance_to(b)
		if length < 0.01:
			continue
		var steps: int = maxi(1, ceili(length / SEGMENT))
		var side: Vector2 = (b - a).normalized().orthogonal() * (WIDTH / 2.0)
		for k: int in range(steps):
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			var q: Vector2 = a.lerp(b, float(k + 1) / float(steps))
			var p1: Vector3 = _ground(p + side)
			var p2: Vector3 = _ground(p - side)
			var q1: Vector3 = _ground(q + side)
			var q2: Vector3 = _ground(q - side)
			for v: Vector3 in [p1, q1, q2, p1, q2, p2]:
				st.set_color(color)
				st.add_vertex(v)
		drew = true
	return drew


func _ground(point: Vector2) -> Vector3:
	return Vector3(point.x, ZoneTerrain.height_at(point.x, point.y) + LIFT, point.y)


static func _beyond(point: Vector2) -> bool:
	return maxf(absf(point.x), absf(point.y)) > EDGE_SKIP
