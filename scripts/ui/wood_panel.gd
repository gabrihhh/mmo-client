class_name WoodPanel
extends PanelContainer
## Moldura de madeira da HUD ([CLI-08]): tábuas horizontais com veios, emendas, uma borda escura de
## madeira mais grossa e um prego em cada canto. Segura vida/mana (topo) e cartas/controles (embaixo).
##
## Desenhada em [method _draw] (sem texturas: leve no mobile e escala com qualquer tamanho). O espaço
## interno vem da variação de tema `WoodFrame` ([CLI-07]); os filhos são desenhados por cima da madeira.
## Os veios usam uma semente fixa ([member grain_seed]): a madeira fica sempre igual, sem "tremer".

## Altura de cada tábua, em px (a última é cortada para caber).
@export var plank_height: float = 38.0
## Cor base das tábuas (cada tábua varia um pouco o tom).
@export var wood_color: Color = Color(0.5, 0.32, 0.17, 0.96)
## Cor da borda (madeira escura em volta).
@export var frame_color: Color = Color(0.26, 0.15, 0.07, 1.0)
## Espessura da borda, em px. Cantos externos arredondados com este mesmo raio (o interno fica reto).
@export var frame_width: float = 8.0
## Semente dos veios/emendas: painéis com sementes diferentes não ficam idênticos.
@export var grain_seed: int = 7


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	var inner: Rect2 = outer.grow(-frame_width)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = grain_seed
	var grain_color: Color = wood_color.darkened(0.32)
	grain_color.a = 0.55
	var seam_dark: Color = Color(0.16, 0.09, 0.04, 0.9)
	var seam_light: Color = wood_color.lightened(0.22)

	var y: float = inner.position.y
	var index: int = 0
	while y < inner.end.y - 1.0:
		var height: float = minf(plank_height, inner.end.y - y)
		var plank: Rect2 = Rect2(inner.position.x, y, inner.size.x, height)
		var shade: float = rng.randf_range(-0.07, 0.07)
		draw_rect(plank, wood_color.lightened(shade) if shade > 0.0 else wood_color.darkened(-shade))
		_draw_grain(plank, rng, grain_color)
		# Emenda de cima (sombra escura + brilho logo abaixo), menos na primeira tábua.
		if index > 0:
			draw_line(Vector2(plank.position.x, y), Vector2(plank.end.x, y), seam_dark, 2.0)
			draw_line(Vector2(plank.position.x, y + 2.0), Vector2(plank.end.x, y + 2.0), seam_light, 1.0)
		# Emenda vertical (ponta de uma tábua encostando na outra), em lugar diferente a cada tábua.
		var joint_x: float = plank.position.x + plank.size.x * rng.randf_range(0.2, 0.8)
		draw_line(Vector2(joint_x, y), Vector2(joint_x, plank.end.y), seam_dark, 2.0)
		y += height
		index += 1

	# Sombra interna junto à borda: dá a impressão de a tábua estar "dentro" da moldura.
	draw_rect(inner.grow(-1.0), Color(0.0, 0.0, 0.0, 0.35), false, 3.0)
	var border: StyleBoxFlat = StyleBoxFlat.new()
	border.draw_center = false
	border.border_color = frame_color
	border.set_border_width_all(int(frame_width))
	border.set_corner_radius_all(int(frame_width))
	draw_style_box(border, outer)
	# Filete claro no topo da borda (luz vindo de cima).
	var bevel: Color = frame_color.lightened(0.3)
	draw_line(Vector2(frame_width, 2.0), Vector2(size.x - frame_width, 2.0), bevel, 2.0)

	for corner: Vector2 in [
		inner.position + Vector2(9, 9), Vector2(inner.end.x - 9, inner.position.y + 9),
		Vector2(inner.position.x + 9, inner.end.y - 9), inner.end - Vector2(9, 9),
	]:
		_draw_nail(corner)


## Três veios ondulados por tábua (linhas finas mais escuras).
func _draw_grain(plank: Rect2, rng: RandomNumberGenerator, color: Color) -> void:
	if plank.size.y < 10.0:
		return
	for i: int in range(3):
		var base_y: float = plank.position.y + rng.randf_range(4.0, plank.size.y - 4.0)
		var amplitude: float = rng.randf_range(0.6, 2.0)
		var frequency: float = rng.randf_range(0.008, 0.03)
		var phase: float = rng.randf() * TAU
		var points: PackedVector2Array = []
		var x: float = plank.position.x
		while x <= plank.end.x:
			points.append(Vector2(x, base_y + sin(x * frequency + phase) * amplitude))
			x += 12.0
		points.append(Vector2(plank.end.x, base_y + sin(plank.end.x * frequency + phase) * amplitude))
		draw_polyline(points, color, 1.5, true)


## Prego: cabeça escura com um brilho.
func _draw_nail(center: Vector2) -> void:
	draw_circle(center, 4.5, Color(0.14, 0.13, 0.13, 1.0))
	draw_circle(center - Vector2(1.2, 1.2), 1.8, Color(0.72, 0.7, 0.66, 1.0))
