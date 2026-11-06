class_name ZoneMap
extends Control
## Mapa da zona no Menu ([CLI-11]): a zona inteira em pixel art, gerada por código a partir do próprio terreno
## ([ZoneTerrain], bosques de [Zone1Scenery]) e **girada como a câmera** ([CLI-02], 45°): o que está para cima/direita
## no mapa está para cima/direita no joystick. Por cima, ao vivo: você (seta azul virada para onde você olha), monstros
## (vermelho), bonecos de treino e NPCs de teste (amarelo) e outros jogadores (verde). Mortos não aparecem.
##
## Só desenha: lê as posições do [Network] (último snapshot) a cada quadro enquanto está visível.

## Metros por pixel da imagem do mapa.
const METERS_PER_PIXEL: float = 2.0
## Metade do lado mostrado (m): a área andável (±150) e um pouco das montanhas.
const SHOW_HALF: float = 160.0
## Giro do mapa, igual ao da câmera em Y (rad). ATENÇÃO: IsometricCamera (45°, [CLI-02]).
const MAP_YAW: float = PI / 4.0
## Altura (px) reservada embaixo para a legenda.
const LEGEND_HEIGHT: float = 56.0

## Cores dos marcadores e do contorno deles.
const COLOR_SELF: Color = Color(0.35, 0.65, 1.0)
const COLOR_MONSTER: Color = Color(0.92, 0.25, 0.2)
const COLOR_NPC: Color = Color(0.98, 0.82, 0.3)
const COLOR_PLAYER: Color = Color(0.4, 0.9, 0.4)
const OUTLINE: Color = Color8(24, 16, 12)
## Lado (px) do marcador quadrado e da seta (você).
const MARKER_PX: float = 14.0
const ARROW_PX: float = 18.0

var _texture: ImageTexture = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = ImageTexture.create_from_image(build_image())


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Imagem pixel art da zona: 1 pixel = [constant METERS_PER_PIXEL] m, de −[constant SHOW_HALF] a +; pixel (i, j)
## é o ponto x = −SHOW_HALF + (i + 0,5) × m, z = idem com j (sem girar: o giro é no desenho).
static func build_image() -> Image:
	var side: int = int(SHOW_HALF * 2.0 / METERS_PER_PIXEL)
	var image: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for j: int in range(side):
		for i: int in range(side):
			var x: float = -SHOW_HALF + (i + 0.5) * METERS_PER_PIXEL
			var z: float = -SHOW_HALF + (j + 0.5) * METERS_PER_PIXEL
			image.set_pixel(i, j, _ground_color(x, z, rng.randf()))
	# Bosques: copas em pixels soltos em volta de cada centro (mais densas no meio).
	for grove: Vector2 in Zone1Scenery.GROVES:
		for k: int in range(26):
			var offset: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Zone1Scenery.GROVE_SPREAD
			var p: Vector2i = _pixel_of(grove + offset, side)
			var dark: Color = Color(0.13, 0.33, 0.16)
			image.set_pixelv(p, dark)
			if p.x + 1 < side:
				image.set_pixel(p.x + 1, p.y, Color(0.2, 0.44, 0.22))
	return image


## Cor do chão em (x, z): montanhas fora da área andável, praça de pedra (com o círculo de nascer e as escadas) e
## campo verde mais escuro nos morros e no pé da montanha. [param noise] (0..1) varia um pouco cada pixel.
static func _ground_color(x: float, z: float, noise: float) -> Color:
	var outside: float = maxf(absf(x), absf(z)) - ZoneTerrain.WALK_HALF
	if outside > 0.0:
		if outside > 7.0:
			return Color(0.86, 0.88, 0.92) if noise > 0.35 else Color(0.62, 0.66, 0.74)
		return Color(0.42, 0.46, 0.5).lerp(Color(0.3, 0.42, 0.3), noise * 0.5)
	if ZoneTerrain.is_plaza(x, z):
		var r: float = Vector2(x, z).length()
		if r <= ZoneTerrain.SPAWN_CIRCLE_RADIUS and r >= ZoneTerrain.SPAWN_CIRCLE_RADIUS - 2.0:
			return Color(0.33, 0.31, 0.3)
		var checker: bool = (int(floorf(x / 2.0)) + int(floorf(z / 2.0))) % 2 == 0
		return Color(0.62, 0.59, 0.55) if checker else Color(0.55, 0.52, 0.48)
	if ZoneTerrain.height_at(x, z) > 0.01 and Vector2(absf(x), absf(z)).length() < ZoneTerrain.PLAZA_HALF + 3.0:
		return Color(0.5, 0.48, 0.45)  # escadas
	var height: float = ZoneTerrain.field_height(x, z)
	var grass: Color = Color(0.42, 0.66, 0.34).lerp(Color(0.3, 0.5, 0.26), clampf(height / 3.0, 0.0, 1.0))
	if height > 3.0:
		grass = grass.lerp(Color(0.5, 0.46, 0.34), clampf((height - 3.0) / 5.0, 0.0, 0.8))
	if noise > 0.985:
		return Color(0.95, 0.85, 0.5)  # flores
	return grass.lightened(0.04) if noise > 0.6 else grass


static func _pixel_of(world: Vector2, side: int) -> Vector2i:
	var i: int = clampi(int((world.x + SHOW_HALF) / METERS_PER_PIXEL), 0, side - 1)
	var j: int = clampi(int((world.y + SHOW_HALF) / METERS_PER_PIXEL), 0, side - 1)
	return Vector2i(i, j)


## Ponto da tela (local deste Control) para o ponto (x, z) do mundo, com o giro da câmera.
func world_to_map(x: float, z: float) -> Vector2:
	return _map_center() + Vector2(x, z).rotated(MAP_YAW) * _pixels_per_meter()


## Px por metro: o losango da zona (lado 2 × SHOW_HALF girado 45°) cabe na área do mapa.
func _pixels_per_meter() -> float:
	var area: Vector2 = Vector2(size.x, size.y - LEGEND_HEIGHT)
	return minf(area.x, area.y) / (SHOW_HALF * 2.0 * sqrt(2.0))


func _map_center() -> Vector2:
	return Vector2(size.x / 2.0, (size.y - LEGEND_HEIGHT) / 2.0)


func _draw() -> void:
	if _texture == null:
		return
	var scale_px: float = _pixels_per_meter() * METERS_PER_PIXEL
	var half_px: float = _texture.get_width() / 2.0
	# Contorno escuro (2 px de tela) e a imagem, girados como a câmera.
	draw_set_transform(_map_center(), MAP_YAW, Vector2(scale_px, scale_px))
	var outline: float = 2.0 / scale_px
	draw_rect(Rect2(-half_px - outline, -half_px - outline, half_px * 2.0 + outline * 2.0, half_px * 2.0 + outline * 2.0), OUTLINE)
	draw_texture(_texture, Vector2(-half_px, -half_px))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_markers()
	_draw_legend()


func _draw_markers() -> void:
	var network: Network = Network.instance
	if network == null:
		return
	for npc: PlayerState in network.get_npcs():
		if not npc.dead:
			_draw_square(world_to_map(npc.x, npc.z), COLOR_MONSTER if npc.monster else COLOR_NPC)
	var me: PlayerState = null
	for player: PlayerState in network.get_players():
		if player.id == network.player_id:
			me = player
		elif not player.dead:
			_draw_square(world_to_map(player.x, player.z), COLOR_PLAYER)
	# Você por cima de todos.
	if me != null:
		_draw_arrow(world_to_map(me.x, me.z), me.rot_y)


func _draw_square(at: Vector2, color: Color) -> void:
	var half: float = MARKER_PX / 2.0
	draw_rect(Rect2(at - Vector2(half + 3.0, half + 3.0), Vector2(MARKER_PX + 6.0, MARKER_PX + 6.0)), OUTLINE)
	draw_rect(Rect2(at - Vector2(half, half), Vector2(MARKER_PX, MARKER_PX)), color)


## Seta apontando para onde [param rot_y] olha (rotY = 0 olha para −Z), girada como o mapa.
func _draw_arrow(at: Vector2, rot_y: float) -> void:
	var facing: Vector2 = Vector2(-sin(rot_y), -cos(rot_y)).rotated(MAP_YAW)
	var side: Vector2 = Vector2(-facing.y, facing.x)
	var tip: Vector2 = at + facing * ARROW_PX
	var back: Vector2 = at - facing * ARROW_PX * 0.6
	var outer: PackedVector2Array = PackedVector2Array([tip + facing * 4.0, back + side * (ARROW_PX * 0.8 + 4.0) - facing * 3.0, back - side * (ARROW_PX * 0.8 + 4.0) - facing * 3.0])
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(PackedVector2Array([tip, back + side * ARROW_PX * 0.8, back - side * ARROW_PX * 0.8]), COLOR_SELF)


## Legenda embaixo: quadradinho colorido + texto de cada tipo de marcador.
func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = 24
	var entries: Array[Array] = [["Você", COLOR_SELF], ["Monstros", COLOR_MONSTER], ["Treino/NPCs", COLOR_NPC], ["Jogadores", COLOR_PLAYER]]
	var widths: Array[float] = []
	var total: float = 0.0
	for entry: Array in entries:
		var label: String = entry[0]
		var width: float = MARKER_PX + 10.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(width)
		total += width
	var gap: float = maxf(12.0, (size.x - total) / float(entries.size() + 1))
	var x: float = gap
	var y: float = size.y - LEGEND_HEIGHT / 2.0
	for k: int in range(entries.size()):
		var label: String = entries[k][0]
		var color: Color = entries[k][1]
		_draw_square(Vector2(x + MARKER_PX / 2.0, y), color)
		draw_string(font, Vector2(x + MARKER_PX + 10.0, y + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		x += widths[k] + gap
