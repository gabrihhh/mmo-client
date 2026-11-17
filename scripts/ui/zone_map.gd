class_name ZoneMap
extends Control
## Mapa da zona no Menu ([CLI-11]): a zona inteira em pixel art, vista de cima do mapa feito no Blender
## ([ART-10], imagem gerada pelo exportador) e **girada como a câmera** ([CLI-02], 45°): o que está para cima/direita
## no mapa está para cima/direita no joystick. Por cima, ao vivo: você (seta azul virada para onde você olha), monstros
## (vermelho), bonecos de treino e NPCs de teste (amarelo) e outros jogadores (verde). Mortos não aparecem, nem quem
## está fora da área de interesse (o servidor só manda quem está perto, [INFRA-04]). **Chefes** ([JOGO-18]) = quadrado
## maior vermelho-escuro com borda dourada.
## **Zonas de nível** ([JOGO-18], [ZoneInfo]): cada uma pintada por cima do mapa numa cor translúcida pela faixa de
## nível (verde = fácil … roxo = difícil), com contorno e o nome + "nv a-b" (a letra cresce com o zoom).
## **Grupo** ([SOC-03]): os membros do meu grupo aparecem em rosa com o nome ao lado (o líder com uma coroa) MESMO
## LONGE: perto, a posição vem do snapshot; longe, de [constant Protocol.MSG_GROUP_POSITIONS] (2 Hz). Membro aparece
## também morto (é o lugar onde ele caiu).
##
## **Mexer no mapa** (toque): **pinça** com dois dedos = zoom (de 1× a [constant MAX_ZOOM]×, no ponto entre os dedos);
## **girar** os dois dedos = gira o mapa; **um dedo** arrastando = move o mapa. No PC: roda do mouse = zoom, arrastar
## = mover. O botão **Redefinir** (canto de cima) volta ao inicial (girado como a câmera, inteiro, centrado). A vista
## fica como estava ao fechar e abrir o mapa de novo.
##
## **Acampamentos** ([JOGO-19]): com o relógio da volta correndo, o tempo que falta ("0:45") no lugar do baú —
## dourado com o baú aberto (some ao acabar: o acampamento volta inteiro), claro com o acampamento pela metade e parado
## (sem combate, volta todo junto quando zerar). Lutando, não há relógio.
##
## Só desenha: lê as posições do [Network] (último snapshot) a cada quadro enquanto está visível.

## Imagem do mapa (importada como Image, sem compressão).
const MAP_IMAGE: String = "res://assets/zones/zone_1/zone_1_map.png"
## Metros por pixel da imagem do mapa. ATENÇÃO: = MAP_STEP em tools/blender/blender_export_zone.py.
const METERS_PER_PIXEL: float = 2.0
## Metade do lado mostrado (m): a área andável (±150) e um pouco das montanhas. ATENÇÃO: = MAP_HALF do exportador.
const SHOW_HALF: float = 160.0
## Giro do mapa, igual ao da câmera em Y (rad). ATENÇÃO: IsometricCamera (45°, [CLI-02]).
const MAP_YAW: float = PI / 4.0
## Altura (px) reservada embaixo para a legenda.
const LEGEND_HEIGHT: float = 56.0
## Zoom máximo (vezes o mapa inteiro) e quanto cada passo da roda do mouse aproxima.
const MAX_ZOOM: float = 8.0
const WHEEL_ZOOM_STEP: float = 1.15
## Quanto do mapa pode sair da área (px de folga): o centro do mapa não vai além da borda da área.
const PAN_MARGIN_PX: float = 0.0

## Cor de cada faixa de nível das zonas ([JOGO-18]); a faixa sai do nível mínimo da zona ([method region_band]).
## ATENÇÃO: mesmas cores dos estandartes dos acampamentos (PALETTE "faixa_N" em workspace-blender/scripts/criar_acampamentos.py).
const REGION_COLORS: Array[Color] = [
	Color(0.45, 0.85, 0.35), Color(0.95, 0.85, 0.3), Color(0.95, 0.55, 0.2), Color(0.9, 0.25, 0.2), Color(0.7, 0.3, 0.9),
]
## Nível mínimo de cada faixa (a partir do 2º): menor que 5 = faixa 0, menor que 10 = 1, ...
const REGION_BAND_LEVELS: Array[int] = [5, 10, 16, 26]
## Transparência da cor da zona por cima do mapa e da linha de contorno.
const REGION_FILL_ALPHA: float = 0.28
const REGION_LINE_ALPHA: float = 0.9
## Nome de zona maior que isto (letras) vai em duas linhas no mapa.
const NAME_WRAP: int = 12
## Chefe ([JOGO-18]): marcador maior, vermelho-escuro com borda dourada.
const COLOR_BOSS: Color = Color(0.6, 0.08, 0.1)
const BOSS_MARKER_SCALE: float = 1.6

## Cores dos marcadores e do contorno deles.
const COLOR_SELF: Color = Color(0.35, 0.65, 1.0)
const COLOR_MONSTER: Color = Color(0.92, 0.25, 0.2)
const COLOR_NPC: Color = Color(0.98, 0.82, 0.3)
const COLOR_PLAYER: Color = Color(0.4, 0.9, 0.4)
## Membros do meu grupo ([SOC-03]): rosa, diferente de todas as outras cores da legenda (no mundo o aliado é verde, mas
## no mapa o verde já é "jogadores").
const COLOR_GROUP: Color = Color(1.0, 0.42, 0.85)
## Coroa em cima do marcador do líder do grupo.
const COLOR_CROWN: Color = Color(1.0, 0.86, 0.35)
## Relógio do acampamento pela metade e parado ([JOGO-19]); o do baú aberto usa [constant COLOR_CROWN] (dourado).
const COLOR_CAMP_IDLE: Color = Color(0.9, 0.92, 0.95)
## Tamanho da fonte (px) do nome dos membros do grupo no mapa.
const GROUP_NAME_FONT: int = 22
const OUTLINE: Color = Color8(24, 16, 12)
## Lado (px) do marcador quadrado e da seta (você).
const MARKER_PX: float = 14.0
const ARROW_PX: float = 18.0

var _texture: ImageTexture = null
## Camada das zonas de nível (mesmo tamanho e posição da imagem do mapa; transparente fora das zonas).
var _regions_texture: ImageTexture = null
## Vista atual: zoom (1 = mapa inteiro), giro somado ao da câmera (rad) e deslocamento do centro (px).
var _zoom: float = 1.0
var _turn: float = 0.0
var _pan: Vector2 = Vector2.ZERO
## Dedos em cima do mapa agora: índice do toque → posição (global, px).
var _touches: Dictionary[int, Vector2] = {}
var _reset_button: Button = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	var image: Image = build_image()
	_texture = ImageTexture.create_from_image(image)
	_regions_texture = ImageTexture.create_from_image(build_regions_image(image.get_width()))
	_reset_button = Button.new()
	_reset_button.text = "Redefinir"
	_reset_button.theme_type_variation = &"PixelButton"
	_reset_button.add_theme_font_size_override("font_size", 24)
	_reset_button.custom_minimum_size = Vector2(170.0, 64.0)
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.pressed.connect(reset_view)
	add_child(_reset_button)
	resized.connect(_place_reset_button)
	_place_reset_button()


## Volta a vista inicial: sem zoom, girado só como a câmera, centrado.
func reset_view() -> void:
	_zoom = 1.0
	_turn = 0.0
	_pan = Vector2.ZERO
	queue_redraw()


func _place_reset_button() -> void:
	_reset_button.position = Vector2(size.x - _reset_button.size.x - 8.0, 8.0)


## Toques (multitoque; no PC o mouse vira toque, `emulate_touch_from_mouse`) e roda do mouse. Usa [method _input] (e não [method _gui_input]) para receber o segundo dedo:
## só conta toque que começou dentro do mapa (fora do botão Redefinir).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_touches.clear()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _accepts_point(touch.position):
				_touches[touch.index] = touch.position
				get_viewport().set_input_as_handled()
		elif _touches.has(touch.index):
			_touches.erase(touch.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _touches.has(drag.index):
			_on_finger_moved(drag.index, drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		# Clique emulado de um toque: já tratado acima como toque.
		if button.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed and _accepts_point(button.position):
				var factor: float = WHEEL_ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_ZOOM_STEP
				_apply_gesture(button.position, button.position, factor, 0.0)
				get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		if _accepts_point(magnify.position):
			_apply_gesture(magnify.position, magnify.position, magnify.factor, 0.0)


## Ponto (tela) dentro da área do mapa e fora do botão Redefinir.
func _accepts_point(point: Vector2) -> bool:
	var area: Rect2 = get_global_rect()
	area.size.y -= LEGEND_HEIGHT
	return area.has_point(point) and not _reset_button.get_global_rect().has_point(point)


## Um dedo andou: com um dedo só, move o mapa; com dois, pinça (zoom) + giro + mover pelo meio dos dois.
func _on_finger_moved(index: int, point: Vector2) -> void:
	var before: Dictionary[int, Vector2] = _touches.duplicate()
	_touches[index] = point
	var keys: Array[int] = _touches.keys()
	if keys.size() == 1:
		_apply_gesture(before[index], point, 1.0, 0.0)
		return
	# Dois dedos: o que andou e o outro (o primeiro que não é ele).
	var other: int = keys[0] if keys[0] != index else keys[1]
	var old_a: Vector2 = before[index]
	var old_b: Vector2 = before[other]
	var new_b: Vector2 = _touches[other]
	var old_span: Vector2 = old_a - old_b
	var new_span: Vector2 = point - new_b
	if old_span.length() < 1.0 or new_span.length() < 1.0:
		return
	_apply_gesture((old_a + old_b) / 2.0, (point + new_b) / 2.0, new_span.length() / old_span.length(),
		old_span.angle_to(new_span))


## Aplica um gesto: o ponto [param from] da tela vai para [param to], com zoom × [param factor] e giro [param angle]
## (rad) em volta dele. Assim o lugar entre os dedos fica embaixo dos dedos. Pontos em coordenadas globais.
func _apply_gesture(from: Vector2, to: Vector2, factor: float, angle: float) -> void:
	var new_zoom: float = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	var applied: float = new_zoom / _zoom
	var base: Vector2 = _base_center()
	var from_local: Vector2 = from - global_position
	var to_local: Vector2 = to - global_position
	# Centro do mapa na tela = base + pan; transformado pelo gesto em volta de "from".
	var center: Vector2 = to_local + (base + _pan - from_local).rotated(angle) * applied
	_zoom = new_zoom
	_turn = wrapf(_turn + angle, -PI, PI)
	_pan = center - base
	_clamp_pan()
	queue_redraw()


## O centro do mapa não sai da área visível (não dá para "perder" o mapa).
func _clamp_pan() -> void:
	var half: Vector2 = Vector2(size.x, size.y - LEGEND_HEIGHT) / 2.0 + Vector2(PAN_MARGIN_PX, PAN_MARGIN_PX)
	_pan = _pan.clamp(-half, half)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Imagem pixel art da zona, exportada do Blender junto com o mapa ([ART-10], `zone_1_map.png`): 1 pixel =
## [constant METERS_PER_PIXEL] m, de −[constant SHOW_HALF] a +; pixel (i, j) é o ponto x = −SHOW_HALF + (i + 0,5) × m,
## z = idem com j (sem girar: o giro é no desenho). Cor = a da face mais alta vista de cima naquele ponto.
static func build_image() -> Image:
	var image: Image = load(MAP_IMAGE) as Image
	if image == null:
		push_error("ZoneMap: não li %s (rodar tools/blender/export_zone.py)" % MAP_IMAGE)
		var side: int = int(SHOW_HALF * 2.0 / METERS_PER_PIXEL)
		return Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	return image


## Faixa de cor (índice em [constant REGION_COLORS]) de uma zona que começa no nível [param min_level].
static func region_band(min_level: int) -> int:
	var band: int = 0
	for threshold: int in REGION_BAND_LEVELS:
		if min_level >= threshold:
			band += 1
	return band


## Camada das zonas de nível ([JOGO-18]): imagem [param side] × [param side] na mesma grade do mapa (pixel (i, j) =
## ponto x = −SHOW_HALF + (i + 0,5) × m, z = idem com j), com a cor translúcida da zona de cada ponto.
static func build_regions_image(side: int) -> Image:
	var image: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var regions: Array[ZoneInfo.Region] = ZoneInfo.regions()
	if regions.is_empty():
		return image
	var step: float = SHOW_HALF * 2.0 / float(side)
	for j: int in range(side):
		var z: float = -SHOW_HALF + (float(j) + 0.5) * step
		for i: int in range(side):
			var x: float = -SHOW_HALF + (float(i) + 0.5) * step
			var region: ZoneInfo.Region = ZoneInfo.region_at(x, z)
			if region != null:
				var color: Color = REGION_COLORS[region_band(region.min_level)]
				color.a = REGION_FILL_ALPHA
				image.set_pixel(i, j, color)
	return image


## Ponto da tela (local deste Control) para o ponto (x, z) do mundo, com o giro da câmera e a vista atual.
func world_to_map(x: float, z: float) -> Vector2:
	return _map_center() + Vector2(x, z).rotated(_yaw()) * _pixels_per_meter()


## Giro total do desenho: o da câmera + o que o jogador girou.
func _yaw() -> float:
	return MAP_YAW + _turn


## Px por metro: no zoom 1 o losango da zona (lado 2 × SHOW_HALF girado 45°) cabe na área do mapa.
func _pixels_per_meter() -> float:
	var area: Vector2 = Vector2(size.x, size.y - LEGEND_HEIGHT)
	return minf(area.x, area.y) / (SHOW_HALF * 2.0 * sqrt(2.0)) * _zoom


## Centro da área do mapa sem deslocamento.
func _base_center() -> Vector2:
	return Vector2(size.x / 2.0, (size.y - LEGEND_HEIGHT) / 2.0)


func _map_center() -> Vector2:
	return _base_center() + _pan


func _draw() -> void:
	if _texture == null:
		return
	var scale_px: float = _pixels_per_meter() * METERS_PER_PIXEL
	var half_px: float = _texture.get_width() / 2.0
	# Contorno escuro (2 px de tela) e a imagem, girados como a câmera.
	draw_set_transform(_map_center(), _yaw(), Vector2(scale_px, scale_px))
	var outline: float = 2.0 / scale_px
	draw_rect(Rect2(-half_px - outline, -half_px - outline, half_px * 2.0 + outline * 2.0, half_px * 2.0 + outline * 2.0), OUTLINE)
	draw_texture(_texture, Vector2(-half_px, -half_px))
	if _regions_texture != null:
		draw_texture(_regions_texture, Vector2(-half_px, -half_px))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_regions()
	_draw_markers()
	# Faixa da legenda por cima do mapa (com zoom o mapa passa por baixo dela).
	draw_rect(Rect2(0.0, size.y - LEGEND_HEIGHT, size.x, LEGEND_HEIGHT), Color(0.09, 0.06, 0.04))
	_draw_legend()


## Contorno e nome + "nv a-b" de cada zona de nível ([JOGO-18]). A letra cresce com o zoom.
func _draw_regions() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = clampi(int(13.0 + 3.0 * _zoom), 14, 30)
	for region: ZoneInfo.Region in ZoneInfo.regions():
		var color: Color = REGION_COLORS[region_band(region.min_level)]
		var line: Color = color
		line.a = REGION_LINE_ALPHA
		var loops: Array[PackedVector2Array] = [region.outer]
		loops.append_array(region.holes)
		for loop: PackedVector2Array in loops:
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in loop:
				points.append(world_to_map(point.x, point.y))
			points.append(points[0])
			draw_polyline(points, line, 2.0)
	# Praça: área segura (sem PvP, [JOGO-22]).
	_draw_centered(font, world_to_map(0.0, 0.0) + Vector2(0.0, font_size * 1.4), "Área segura", font_size, Color(0.75, 0.9, 1.0))
	# Nomes depois de todas as linhas (por cima delas).
	for region: ZoneInfo.Region in ZoneInfo.regions():
		var color: Color = REGION_COLORS[region_band(region.min_level)]
		var at: Vector2 = world_to_map(region.label.x, region.label.y)
		var lines: PackedStringArray = _wrap_name(region.name)
		lines.append("nv %d-%d" % [region.min_level, region.max_level])
		# Bloco centrado no ponto do nome; a última linha (nível) na cor da faixa.
		var top: Vector2 = at - Vector2(0.0, font_size * 1.05 * (lines.size() - 1) / 2.0)
		for k: int in range(lines.size()):
			_draw_centered(font, top + Vector2(0.0, font_size * 1.05 * k), lines[k], font_size,
				color if k == lines.size() - 1 else Color(1, 1, 1))


## Nome comprido (mais de [constant NAME_WRAP] letras) em duas linhas, quebrando no espaço mais perto do meio: os nomes
## das zonas vizinhas não se encostam no mapa inteiro.
static func _wrap_name(name: String) -> PackedStringArray:
	if name.length() <= NAME_WRAP or name.find(" ") < 0:
		return PackedStringArray([name])
	var best: int = -1
	for i: int in range(name.length()):
		if name[i] == " " and (best < 0 or absi(i - name.length() / 2) < absi(best - name.length() / 2)):
			best = i
	return PackedStringArray([name.substr(0, best), name.substr(best + 1)])


## Texto centrado em [param at] com contorno escuro.
func _draw_centered(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos: Vector2 = at - Vector2(width / 2.0, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_markers() -> void:
	var network: Network = Network.instance
	if network == null:
		return
	for npc: PlayerState in network.get_npcs():
		if not npc.dead and npc.in_view:
			if npc.boss:
				_draw_boss(world_to_map(npc.x, npc.z))
			else:
				_draw_square(world_to_map(npc.x, npc.z), COLOR_MONSTER if npc.monster else COLOR_NPC)
	_draw_camp_timers(network)
	var me: PlayerState = null
	for player: PlayerState in network.get_players():
		if player.id == network.player_id:
			me = player
		elif not player.dead and player.in_view and not network.is_group_member(player.id):
			_draw_square(world_to_map(player.x, player.z), COLOR_PLAYER)
	_draw_group(network)
	# Você por cima de todos.
	if me != null:
		_draw_arrow(world_to_map(me.x, me.z), me.rot_y)


## Relógio de cada acampamento com volta marcada ([JOGO-19]): baú aberto = baú dourado + tempo dourado; pela metade e
## parado = só o tempo, claro. Contado no aparelho a partir do [member ChestInfo.reset_at_msec].
func _draw_camp_timers(network: Network) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = clampi(int(14.0 + 3.0 * _zoom), 16, 30)
	for chest: ChestInfo in network.chests.values():
		var left: float = chest.reset_in_seconds()
		if left < 0.0:
			continue
		var at: Vector2 = world_to_map(chest.x, chest.z)
		if chest.open:
			_draw_square(at, COLOR_CROWN)
		var seconds: int = ceili(left)
		_draw_centered(font, at + Vector2(0.0, MARKER_PX + font_size * 0.9), "%d:%02d" % [floori(seconds / 60.0), seconds % 60],
			font_size, COLOR_CROWN if chest.open else COLOR_CAMP_IDLE)


## Membros do meu grupo (menos eu): quadrado rosa + nome; o líder com coroa. Posição: snapshot se está perto
## ([member PlayerState.in_view]), senão a de [method Network.group_far_position] (recente), senão a última conhecida.
func _draw_group(network: Network) -> void:
	var group: GroupState = network.group
	if group == null:
		return
	var font: Font = get_theme_default_font()
	for member: GroupState.Member in group.members:
		if member.id == network.player_id:
			continue
		var state: PlayerState = network.get_player(member.id)
		var at: Vector2
		if state != null and state.in_view:
			at = Vector2(state.x, state.z)
		elif network.has_group_far_position(member.id):
			at = network.group_far_position(member.id)
		elif state != null:
			at = Vector2(state.x, state.z)
		else:
			continue
		var point: Vector2 = world_to_map(at.x, at.y)
		_draw_square(point, COLOR_GROUP)
		if member.id == group.leader_id:
			_draw_crown(point + Vector2(0.0, -MARKER_PX / 2.0 - 5.0))
		var text_at: Vector2 = point + Vector2(MARKER_PX / 2.0 + 8.0, GROUP_NAME_FONT * 0.35)
		draw_string_outline(font, text_at, member.name, HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_NAME_FONT, 6, OUTLINE)
		draw_string(font, text_at, member.name, HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_NAME_FONT, COLOR_GROUP)


## Coroa pixel art (3 pontas) com a base em [param base], centrada: marca o líder do grupo.
func _draw_crown(base: Vector2) -> void:
	var w: float = MARKER_PX * 0.75
	var h: float = MARKER_PX * 0.7
	var points: PackedVector2Array = PackedVector2Array([
		base + Vector2(-w, 0.0), base + Vector2(-w, -h), base + Vector2(-w * 0.5, -h * 0.45), base + Vector2(0.0, -h * 1.15),
		base + Vector2(w * 0.5, -h * 0.45), base + Vector2(w, -h), base + Vector2(w, 0.0),
	])
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, COLOR_CROWN)
	draw_polyline(outline, OUTLINE, 3.0)


func _draw_square(at: Vector2, color: Color) -> void:
	var half: float = MARKER_PX / 2.0
	draw_rect(Rect2(at - Vector2(half + 3.0, half + 3.0), Vector2(MARKER_PX + 6.0, MARKER_PX + 6.0)), OUTLINE)
	draw_rect(Rect2(at - Vector2(half, half), Vector2(MARKER_PX, MARKER_PX)), color)


## Chefe ([JOGO-18]): quadrado maior vermelho-escuro com borda dourada.
func _draw_boss(at: Vector2) -> void:
	var half: float = MARKER_PX * BOSS_MARKER_SCALE / 2.0
	draw_rect(Rect2(at - Vector2(half + 3.0, half + 3.0), Vector2(half * 2.0 + 6.0, half * 2.0 + 6.0)), OUTLINE)
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), COLOR_CROWN)
	draw_rect(Rect2(at - Vector2(half - 3.0, half - 3.0), Vector2(half * 2.0 - 6.0, half * 2.0 - 6.0)), COLOR_BOSS)


## Seta apontando para onde [param rot_y] olha (rotY = 0 olha para −Z), girada como o mapa.
func _draw_arrow(at: Vector2, rot_y: float) -> void:
	var facing: Vector2 = Vector2(-sin(rot_y), -cos(rot_y)).rotated(_yaw())
	var side: Vector2 = Vector2(-facing.y, facing.x)
	var tip: Vector2 = at + facing * ARROW_PX
	var back: Vector2 = at - facing * ARROW_PX * 0.6
	var outer: PackedVector2Array = PackedVector2Array([tip + facing * 4.0, back + side * (ARROW_PX * 0.8 + 4.0) - facing * 3.0, back - side * (ARROW_PX * 0.8 + 4.0) - facing * 3.0])
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(PackedVector2Array([tip, back + side * ARROW_PX * 0.8, back - side * ARROW_PX * 0.8]), COLOR_SELF)


## Legenda embaixo: quadradinho colorido + texto de cada tipo de marcador.
func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var entries: Array[Array] = [["Você", COLOR_SELF], ["Monstros", COLOR_MONSTER], ["Chefe", COLOR_BOSS], ["Treino/NPCs", COLOR_NPC], ["Jogadores", COLOR_PLAYER]]
	# "Grupo" só quando estou num grupo ([SOC-03]).
	if Network.instance != null and Network.instance.group != null:
		entries.append(["Grupo", COLOR_GROUP])
	# Fonte de 24 px, diminuindo (até 16) se a legenda não couber na largura (celular em retrato).
	var font_size: int = 24
	var widths: Array[float] = []
	var total: float = 0.0
	while true:
		widths.clear()
		total = 0.0
		for entry: Array in entries:
			var label: String = entry[0]
			var width: float = MARKER_PX + 10.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			widths.append(width)
			total += width
		if font_size <= 16 or total + 12.0 * float(entries.size() + 1) <= size.x:
			break
		font_size -= 2
	var gap: float = maxf(12.0, (size.x - total) / float(entries.size() + 1))
	var x: float = gap
	var y: float = size.y - LEGEND_HEIGHT / 2.0
	for k: int in range(entries.size()):
		var label: String = entries[k][0]
		var color: Color = entries[k][1]
		_draw_square(Vector2(x + MARKER_PX / 2.0, y), color)
		draw_string(font, Vector2(x + MARKER_PX + 10.0, y + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		x += widths[k] + gap
