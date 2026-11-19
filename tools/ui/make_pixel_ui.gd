extends SceneTree
## Gera as peças pixel art da HUD ([CLI-08]) em `assets/ui/pixel/`: moldura das barras/controles (e a versão opaca
## dos painéis do Menu), fundo das cartas
## e do Menu (normal e apertado), botão redondo
## (ataque e "Desfocar"), espada, espada riscada, os ícones do menu (☰, mochila, mapa, engrenagem, sair), os ícones do
## chat (balões, grupo, guilda, envelope, globo), do Mercado/Armazém (moeda, baú, elmo, peitoral, bota, lista, setas;
## diamante da Loja premium;
## a fonte pixel art não tem emoji), o **X vermelho**
## dos botões de fechar ([method PixelMenuPanel.make_close_button]) e as peças da
## tela de login ([CLI-05]): campo de texto (normal e selecionado) e o piso de pedra do fundo.
##
## Tudo é desenhado pixel a pixel aqui (sem Meshy, sem imagem de fora): mudar uma cor ou um desenho e rodar de novo.
## Os mapas de pixels usam uma letra por cor ([constant PALETTE]); "." = transparente. Depois de pintar, cada
## figura ganha um **contorno escuro automático** (todo pixel vazio encostado num cheio vira contorno).
##
## Rodar: `godot --headless --path . --script res://tools/ui/make_pixel_ui.gd` (depois abrir o editor ou rodar
## `godot --path . --headless --editor --quit` para importar). Os PNGs são pequenos (16/32 px) e a HUD os desenha
## ampliados com filtro NEAREST; só a moldura sai já ampliada ([constant FRAME_SCALE]x), porque o 9-slice do
## [StyleBoxTexture] desenha as bordas em tamanho real.

## Pasta de saída.
const OUT_DIR: String = "res://assets/ui/pixel/"
## Ampliação da moldura (cada pixel do desenho vira um bloco FRAME_SCALE×FRAME_SCALE).
const FRAME_SCALE: int = 4
## Lado da moldura antes de ampliar, em pixels do desenho. As bordas ocupam [constant FRAME_MARGIN] de cada lado.
const FRAME_SIZE: int = 16
## Margem do 9-slice, em pixels do desenho (o tema usa FRAME_MARGIN * FRAME_SCALE).
const FRAME_MARGIN: int = 6

## Ampliação do fundo das cartas/Menu (9-slice: as bordas são desenhadas em tamanho real, por isso já sai ampliado).
const CARD_SCALE: int = 3
## Lado do fundo da carta antes de ampliar; a margem do 9-slice é [constant CARD_MARGIN] (o tema/botão usa ×CARD_SCALE).
const CARD_SIZE: int = 12
const CARD_MARGIN: int = 4

## Lado do piso de pedra do fundo do login (repetido na tela, ampliado pela cena).
const TILE_SIZE: int = 16

## Cores por letra. Contorno = "k".
const PALETTE: Dictionary[String, Color] = {
	"k": Color8(24, 16, 12),
	"w": Color8(240, 242, 247),
	"s": Color8(150, 160, 180),
	"S": Color8(96, 104, 124),
	"g": Color8(246, 196, 82),
	"G": Color8(170, 110, 34),
	"b": Color8(120, 72, 36),
	"B": Color8(74, 42, 18),
	"r": Color8(200, 56, 48),
	"R": Color8(130, 30, 30),
	"x": Color8(240, 236, 226),
	"o": Color8(255, 128, 104),
	# Chat ([SOC-09]): verde do Grupo, azul da Guilda, rosa do Privado (claro/escuro).
	"e": Color8(110, 210, 100),
	"E": Color8(54, 140, 60),
	"u": Color8(110, 160, 240),
	"U": Color8(50, 90, 180),
	"p": Color8(250, 170, 215),
	"P": Color8(200, 80, 150),
	# Diamante da Loja premium ([JOGO-27]): ciano claro/escuro.
	"c": Color8(120, 230, 250),
	"C": Color8(40, 140, 200),
}

## Espada na diagonal, ponta para cima/direita (16×16). w/s = lâmina clara/sombra, g/G = guarda e pomo, b/B = cabo.
const SWORD: Array[String] = [
	"................",
	"..............w.",
	".............ws.",
	"............ws..",
	"...........ws...",
	"..........ws....",
	".........ws.....",
	"........ws......",
	"...g...ws.......",
	"....g.ws........",
	".....Gs.........",
	"....bGg.........",
	"...bB..g........",
	"..bB............",
	".gG.............",
	"................",
]
## Traço vermelho da espada riscada ("Desfocar"): diagonal de cima/esquerda para baixo/direita, por cima da espada.
const CROSS: Array[String] = [
	"................",
	"................",
	"..rr............",
	"...rr...........",
	"....rr..........",
	".....rr.........",
	"......rr........",
	".......rr.......",
	"........rr......",
	".........rr.....",
	"..........rr....",
	"...........rr...",
	"............rr..",
	".............rr.",
	"................",
	"................",
]
## X vermelho dos botões de fechar (12×12): o = brilho em cima/esquerda, r = vermelho, R = sombra embaixo/direita.
const ICON_CLOSE: Array[String] = [
	"............",
	".oo......oo.",
	".orr....orR.",
	"..orr..orR..",
	"...orrorR...",
	"....orrR....",
	"....orrR....",
	"...orRRrR...",
	"..orR..rrR..",
	".orR....rrR.",
	".RR......RR.",
	"............",
]
## ☰ do botão Menu.
const ICON_MENU: Array[String] = [
	"................",
	"................",
	"................",
	"..wwwwwwwwwwww..",
	"..wwwwwwwwwwww..",
	"................",
	"................",
	"..wwwwwwwwwwww..",
	"..wwwwwwwwwwww..",
	"................",
	"................",
	"..wwwwwwwwwwww..",
	"..wwwwwwwwwwww..",
	"................",
	"................",
	"................",
]
## Mochila (Inventário).
const ICON_BAG: Array[String] = [
	"................",
	"......BBBB......",
	".....B....B.....",
	"....bbbbbbbb....",
	"...bbbbbbbbbb...",
	"...bbbbbbbbbb...",
	"...BBBBBBBBBB...",
	"...bbbbggbbbb...",
	"...bbbbGGbbbb...",
	"...bbbbbbbbbb...",
	"...bBBBBBBBBb...",
	"...bB......Bb...",
	"...bB......Bb...",
	"...bBBBBBBBBb...",
	"....bbbbbbbb....",
	"................",
]
## Mapa dobrado (Mapa): papel em três dobras (x = papel, s = sombra da dobra), caminho tracejado vermelho até um X.
const ICON_MAP: Array[String] = [
	"................",
	"................",
	"..xxxxsxxxxsxx..",
	"..xxxxsxxxxsxx..",
	"..xrxxsxxxxsxx..",
	"..xxrxsxxxxsxx..",
	"..xxxxsrxxxsxx..",
	"..xxxxsxrxxsxx..",
	"..xxxxsxxxxsrx..",
	"..xxxxsxxxrsxx..",
	"..xxxxsxxxxsxx..",
	"..xxxxsxxxrsrx..",
	"..xxxxsxxxxsrx..",
	"..xxxxsxxxrsxr..",
	"..xxxxsxxxxsxx..",
	"................",
]
## Engrenagem (Configuração).
const ICON_GEAR: Array[String] = [
	"................",
	"......ssss......",
	"..ss..ssss..ss..",
	"..ssssssssssss..",
	"...ssssssssss...",
	"...sssSSSSsss...",
	".ssssS....Sssss.",
	".ssssS....Sssss.",
	".ssssS....Sssss.",
	".ssssS....Sssss.",
	"...sssSSSSsss...",
	"...ssssssssss...",
	"..ssssssssssss..",
	"..ss..ssss..ss..",
	"......ssss......",
	"................",
]
## Porta com seta para fora (Sair da conta).
const ICON_EXIT: Array[String] = [
	"................",
	"..bbbbbbb.......",
	"..bBBBBBb.......",
	"..bBBBBBb.......",
	"..bBBBBBb...r...",
	"..bBBBBBb...rr..",
	"..bBBBgBrrrrrrr.",
	"..bBBBBBrrrrrrr.",
	"..bBBBBBb...rr..",
	"..bBBBBBb...r...",
	"..bBBBBBb.......",
	"..bBBBBBb.......",
	"..bBBBBBb.......",
	"..bbbbbbb.......",
	"................",
	"................",
]


## Duas pessoas (Jogadores Próximos, [SOC-02]): a da frente de túnica vermelha, a de trás de cinza (x = pele).
const ICON_PLAYERS: Array[String] = [
	"................",
	"................",
	"..........xxx...",
	"....xxx..xxxxx..",
	"...xxxxx.xxxxx..",
	"...xxxxx.xxxxx..",
	"...xxxxx..xxx...",
	"....xxx.........",
	"...rrrrr..SSSS..",
	"..rrrrrrr.SSSSS.",
	"..rrrrrrr.SSSSS.",
	"..rrrrrrr.SSSSS.",
	"..rrrrrrr.SSSSS.",
	"..rrrrrrr.......",
	"................",
	"................",
]

## Chat (botão 💬 e aba Tudo): dois balões, um dourado atrás e um branco na frente.
const ICON_CHAT: Array[String] = [
	"................",
	".gggggggg.......",
	".gggggggg.......",
	".gggggggg.......",
	".gggwwwwwwwwww..",
	".gg.wwwwwwwwww..",
	".g..wwSwSwSwww..",
	"....wwwwwwwwww..",
	"....wwwwwwwwww..",
	"...........ww...",
	"............w...",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Chat Geral: um balão branco com reticências.
const ICON_ZONE: Array[String] = [
	"................",
	"................",
	"...wwwwwwwwww...",
	"..wwwwwwwwwwww..",
	"..wwwwwwwwwwww..",
	"..wwSwwSwwSwww..",
	"..wwwwwwwwwwww..",
	"..wwwwwwwwwwww..",
	"...wwwwwwwwww...",
	"....www.........",
	"...ww...........",
	"..w.............",
	"................",
	"................",
	"................",
	"................",
]
## Botão do chat na HUD: só um balão de fala branco com as reticências (três pontos 2×2) no meio e o rabinho embaixo
## à esquerda.
const ICON_SPEECH: Array[String] = [
	"................",
	"................",
	"...wwwwwwwwww...",
	"..wwwwwwwwwwww..",
	".wwwwwwwwwwwwww.",
	".wwwwwwwwwwwwww.",
	".wwSSwwSSwwSSww.",
	".wwSSwwSSwwSSww.",
	".wwwwwwwwwwwwww.",
	"..wwwwwwwwwwww..",
	"...wwwwwwwwww...",
	"....www.........",
	"....ww..........",
	"....w...........",
	"................",
	"................",
]
## Chat do Grupo: três cabeças verdes (a do meio na frente).
const ICON_GROUP: Array[String] = [
	"................",
	"................",
	"..EE...ee...EE..",
	".EEEE.eeee.EEEE.",
	".EEEE.eeee.EEEE.",
	"..EE...ee...EE..",
	"......eeee......",
	".EEE.eeeeee.EEE.",
	"EEEEEeeeeeeEEEEE",
	"EEEEEeeeeeeEEEEE",
	"EEEEEeeeeeeEEEEE",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Chat da Guilda: escudo azul com um emblema dourado.
const ICON_GUILD: Array[String] = [
	"................",
	"..uuuuuuuuuuuu..",
	"..uUUUUUUUUUUu..",
	"..uUUUUggUUUUu..",
	"..uUUUggggUUUu..",
	"..uUUUUggUUUUu..",
	"..uUUUUggUUUUu..",
	"..uUUUUUUUUUUu..",
	"...uUUUUUUUUu...",
	"...uUUUUUUUUu...",
	"....uUUUUUUu....",
	".....uUUUUu.....",
	"......uUUu......",
	".......uu.......",
	"................",
	"................",
]
## Chat Privado: envelope rosa fechado.
const ICON_PRIVATE: Array[String] = [
	"................",
	"................",
	"................",
	".PPPPPPPPPPPPPP.",
	".PpPPPPPPPPPPpP.",
	".PppPPPPPPPPppP.",
	".PpppPPPPPPpppP.",
	".PppppPPPPppppP.",
	".PpppppPPpppppP.",
	".PppppppppppppP.",
	".PppppppppppppP.",
	".PppppppppppppP.",
	".PPPPPPPPPPPPPP.",
	"................",
	"................",
	"................",
]
## Chat Global: globo azul com terras verdes.
const ICON_GLOBAL: Array[String] = [
	"................",
	".....uuuuuu.....",
	"...uueeuuuuuu...",
	"..uueeeeuuuuuu..",
	"..ueeeeeuuueeu..",
	".uuueeeuuueeeeu.",
	".uuuueeuuueeeeu.",
	".uuuuuuuuuueeuu.",
	".uuuuueeuuuuuuu.",
	".uuuueeeeuuuuuu.",
	"..uuueeeeeuuuu..",
	"..uuuueeeuuuuu..",
	"...uuuueuuuuu...",
	".....uuuuuu.....",
	"................",
	"................",
]
## Moeda de ouro (Mercado, preços).
const ICON_COIN: Array[String] = [
	"................",
	"................",
	".....GGGGGG.....",
	"....GggggggG....",
	"...GggwwgggGG...",
	"...GgwgggggGG...",
	"...GgwgggggGG...",
	"...GggggggggG...",
	"...GggggggggG...",
	"...GGgggggGGG...",
	"....GGGGGGGG....",
	".....GGGGGG.....",
	"................",
	"................",
	"................",
	"................",
]
## Diamante (moeda premium da Loja, [JOGO-27]): lapidado, topo largo e ponta embaixo, com brilho branco.
const ICON_DIAMOND: Array[String] = [
	"................",
	"................",
	"................",
	"....CCCCCCCC....",
	"...CcwcccCccC...",
	"..CcwcccCcccCC..",
	"..CCCCCCCCCCCC..",
	"...CcccCcccCC...",
	"....CccCccCC....",
	".....CcCcCC.....",
	"......CcCC......",
	".......CC.......",
	"................",
	"................",
	"................",
	"................",
]
## Baú (Armazém): madeira com faixas e fechadura douradas.
const ICON_CHEST: Array[String] = [
	"................",
	"................",
	"................",
	"..bbbbbbbbbbbb..",
	".bBBBBBBBBBBBBb.",
	".bbbbbbbbbbbbbb.",
	".BBBBBBggBBBBBB.",
	".bbbgbbGGbbgbbb.",
	".bbbgbbbbbbgbbb.",
	".bbbgbbbbbbgbbb.",
	".bbbgbbbbbbgbbb.",
	".BBBBBBBBBBBBBB.",
	"................",
	"................",
	"................",
	"................",
]
## Elmo (filtro Cabeça).
const ICON_HELM: Array[String] = [
	"................",
	"................",
	".....ssssss.....",
	"....swwssssS....",
	"...swsssssssS...",
	"...swsssssssS...",
	"...ssssssssss...",
	"...SSSSSSSSSS...",
	"...SS.SSSS.SS...",
	"...SS.SSSS.SS...",
	"...SSSSSSSSSS...",
	"....SSS..SSS....",
	"................",
	"................",
	"................",
	"................",
]
## Peitoral (filtro Peito).
const ICON_ARMOR: Array[String] = [
	"................",
	"...ss......ss...",
	"..ssss....ssss..",
	"..sssssssssssS..",
	"...swsssssssS...",
	"...swssssssSS...",
	"...sssssssssS...",
	"...sssssssssS...",
	"....ssssssSS....",
	"....ssssssSS....",
	"....SSSSSSSS....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Bota (filtro Pés).
const ICON_BOOT: Array[String] = [
	"................",
	"................",
	"....bbbbb.......",
	"....bbbbb.......",
	"....bBbbb.......",
	"....bbbbb.......",
	"....bbbbb.......",
	"....bbbbb.......",
	"....bbbbbbbb....",
	"....bbbbbbbbbb..",
	"....BBBBBBBBBB..",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Lista (Meus anúncios): papel com linhas.
const ICON_LIST: Array[String] = [
	"................",
	"...xxxxxxxxxx...",
	"...xxxxxxxxxx...",
	"...xSSSSSSSxx...",
	"...xxxxxxxxxx...",
	"...xSSSSSSxxx...",
	"...xxxxxxxxxx...",
	"...xSSSSSSSxx...",
	"...xxxxxxxxxx...",
	"...xSSSSSxxxx...",
	"...xxxxxxxxxx...",
	"...xxxxxxxxxx...",
	"................",
	"................",
	"................",
	"................",
]
## Seta para a direita (páginas; a da esquerda é ela espelhada).
const ICON_ARROW: Array[String] = [
	"................",
	"................",
	"................",
	"....w...........",
	"....ww..........",
	"....www.........",
	"....wwww........",
	"....wwwww.......",
	"....wwww........",
	"....www.........",
	"....ww..........",
	"....w...........",
	"................",
	"................",
	"................",
	"................",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_outlined(_from_map(SWORD)), "sword")
	var crossed: Image = _from_map(SWORD)
	_stamp(crossed, _from_map(CROSS))
	_save(_outlined(crossed), "sword_crossed")
	_save(_outlined(_from_map(ICON_MENU)), "icon_menu")
	_save(_outlined(_from_map(ICON_BAG)), "icon_bag")
	_save(_outlined(_from_map(ICON_MAP)), "icon_map")
	_save(_outlined(_from_map(ICON_GEAR)), "icon_gear")
	_save(_outlined(_from_map(ICON_EXIT)), "icon_exit")
	_save(_outlined(_from_map(ICON_PLAYERS)), "icon_players")
	_save(_outlined(_from_map(ICON_CLOSE)), "icon_close")
	# Chat ([SOC-09]), Mercado ([JOGO-25]) e Armazém ([JOGO-26]).
	_save(_outlined(_from_map(ICON_CHAT)), "icon_chat")
	_save(_outlined(_from_map(ICON_ZONE)), "icon_zone")
	_save(_outlined(_from_map(ICON_SPEECH)), "icon_speech")
	_save(_outlined(_from_map(ICON_GROUP)), "icon_group")
	_save(_outlined(_from_map(ICON_GUILD)), "icon_guild")
	_save(_outlined(_from_map(ICON_PRIVATE)), "icon_private")
	_save(_outlined(_from_map(ICON_GLOBAL)), "icon_global")
	_save(_outlined(_from_map(ICON_COIN)), "icon_coin")
	_save(_outlined(_from_map(ICON_DIAMOND)), "icon_diamond")
	_save(_outlined(_from_map(ICON_CHEST)), "icon_chest")
	_save(_outlined(_from_map(ICON_HELM)), "icon_helm")
	_save(_outlined(_from_map(ICON_ARMOR)), "icon_armor")
	_save(_outlined(_from_map(ICON_BOOT)), "icon_boot")
	_save(_outlined(_from_map(ICON_LIST)), "icon_list")
	var arrow: Image = _outlined(_from_map(ICON_ARROW))
	_save(arrow, "icon_arrow_right")
	var left: Image = arrow.duplicate() as Image
	left.flip_x()
	_save(left, "icon_arrow_left")
	_save(_round_button(32, false), "round_button")
	_save(_round_button(32, true), "round_button_pressed")
	for pressed: bool in [false, true]:
		var card: Image = _card(pressed)
		card.resize(CARD_SIZE * CARD_SCALE, CARD_SIZE * CARD_SCALE, Image.INTERPOLATE_NEAREST)
		_save(card, "card_pressed" if pressed else "card")
	for opaque: bool in [false, true]:
		var frame: Image = _frame(opaque)
		frame.resize(FRAME_SIZE * FRAME_SCALE, FRAME_SIZE * FRAME_SCALE, Image.INTERPOLATE_NEAREST)
		_save(frame, "panel" if opaque else "frame")
	for focused: bool in [false, true]:
		var field: Image = _input(focused)
		field.resize(CARD_SIZE * CARD_SCALE, CARD_SIZE * CARD_SCALE, Image.INTERPOLATE_NEAREST)
		_save(field, "input_focus" if focused else "input")
	_save(_stone_tile(), "bg_tile")
	print("pixel ui: ok -> ", OUT_DIR)
	quit()


## Imagem do mapa de letras [param rows] (uma letra por pixel, ver [constant PALETTE]).
func _from_map(rows: Array[String]) -> Image:
	var image: Image = Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			var key: String = rows[y][x]
			if PALETTE.has(key):
				image.set_pixel(x, y, PALETTE[key])
	return image


## Copia os pixels cheios de [param top] por cima de [param base].
func _stamp(base: Image, top: Image) -> void:
	for y: int in range(top.get_height()):
		for x: int in range(top.get_width()):
			if top.get_pixel(x, y).a > 0.0:
				base.set_pixel(x, y, top.get_pixel(x, y))


## Contorno escuro automático: pixel vazio com vizinho cheio (4 direções) vira "k".
func _outlined(image: Image) -> Image:
	var out: Image = image.duplicate() as Image
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + step
				if n.x >= 0 and n.y >= 0 and n.x < image.get_width() and n.y < image.get_height() and image.get_pixelv(n).a > 0.0:
					out.set_pixel(x, y, PALETTE["k"])
					break
	return out


## Botão redondo [param side]×[param side]: contorno, aro dourado (claro em cima/esquerda, escuro embaixo/direita),
## anel escuro e miolo vermelho com brilho em cima. O miolo tem raio ~0,72 do botão (o relógio de recarga cobre só ele).
func _round_button(side: int, pressed: bool) -> Image:
	var image: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(side, side) / 2.0
	var half: float = float(side) / 2.0
	var red: Color = PALETTE["r"].lightened(0.15) if pressed else PALETTE["r"]
	var red_dark: Color = PALETTE["R"].lightened(0.1) if pressed else PALETTE["R"]
	for y: int in range(side):
		for x: int in range(side):
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var d: float = offset.length() / half  # 0 no centro, 1 na borda
			var light: float = offset.normalized().dot(Vector2(-1, -1).normalized())  # 1 = canto de cima/esquerda
			var color: Color = Color(0, 0, 0, 0)
			if d > 1.0:
				continue
			elif d > 0.9:
				color = PALETTE["k"]
			elif d > 0.78:
				color = PALETTE["g"] if light > 0.0 else PALETTE["G"]
				if pressed:
					color = color.lightened(0.2)
			elif d > 0.72:
				color = PALETTE["k"]
			else:
				color = red
				if offset.y > half * 0.25 or (light < -0.3 and d > 0.5):
					color = red_dark
				elif offset.y < -half * 0.3 and d < 0.62:
					color = red.lightened(0.18)
			image.set_pixel(x, y, color)
	# Brilho em pixels soltos no alto/esquerda do miolo.
	var spark: Color = Color(1, 1, 1, 0.85)
	for p: Vector2i in [Vector2i(10, 9), Vector2i(11, 9), Vector2i(9, 10)]:
		image.set_pixelv(p * side / 32, spark)
	return image


## Moldura 9-slice ([constant FRAME_SIZE] px antes de ampliar): contorno, filete dourado com luz em cima/esquerda,
## dourado médio, contorno interno, fundo escuro translúcido e uma placa dourada em cada canto.
## [param opaque] = fundo opaco (`panel.png`, painéis do Menu: nada do jogo aparece por trás); senão `frame.png` (HUD).
func _frame(opaque: bool) -> Image:
	var n: int = FRAME_SIZE
	var image: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var fill: Color = Color8(34, 24, 18, 255 if opaque else 225)
	var fill_shadow: Color = Color8(22, 15, 11, 255 if opaque else 230)
	for y: int in range(n):
		for x: int in range(n):
			var edge: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var color: Color = fill
			match edge:
				0:
					color = PALETTE["k"]
				1:
					color = PALETTE["g"] if (y == 1 and x < n - 2) or (x == 1 and y < n - 2) else PALETTE["G"]
				2:
					color = PALETTE["G"].lerp(PALETTE["g"], 0.5)
				3:
					color = PALETTE["k"]
				4:
					color = fill_shadow if (y == 4 or x == 4) else fill
			image.set_pixel(x, y, color)
	# Cantos externos arredondados (1 pixel transparente em cada canto).
	for c: Vector2i in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		image.set_pixelv(c, Color(0, 0, 0, 0))
	# Placa 4×4 em cada canto (contorno + dourado + brilho), avançando 1 pixel para dentro do fundo.
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(n - 5, 1), Vector2i(1, n - 5), Vector2i(n - 5, n - 5)]:
		for py: int in range(4):
			for px: int in range(4):
				var border: bool = px == 0 or py == 0 or px == 3 or py == 3
				image.set_pixel(corner.x + px, corner.y + py, PALETTE["k"] if border else PALETTE["g"])
		image.set_pixel(corner.x + 2, corner.y + 2, PALETTE["G"])
	return image


## Fundo das cartas e do botão Menu ([constant CARD_SIZE] px antes de ampliar): contorno, filete de metal (prata;
## apertado = dourado) claro em cima/esquerda e escuro embaixo/direita, contorno interno e fundo azul-escuro com
## sombra na primeira linha. Cantos externos com 1 pixel transparente (arredondado em pixel).
func _card(pressed: bool) -> Image:
	var n: int = CARD_SIZE
	var image: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var light: Color = PALETTE["g"] if pressed else Color8(200, 208, 224)
	var dark: Color = PALETTE["G"] if pressed else Color8(104, 114, 138)
	var fill: Color = Color8(52, 66, 92, 235) if pressed else Color8(36, 46, 66, 235)
	for y: int in range(n):
		for x: int in range(n):
			var edge: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var color: Color = fill
			match edge:
				0, 2:
					color = PALETTE["k"]
				1:
					color = light if (y == 1 and x < n - 2) or (x == 1 and y < n - 2) else dark
				3:
					color = fill.darkened(0.3) if (y == 3 or x == 3) else fill
			image.set_pixel(x, y, color)
	for c: Vector2i in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		image.set_pixelv(c, Color(0, 0, 0, 0))
	return image


## Campo de texto ([constant CARD_SIZE] px antes de ampliar, mesma margem das cartas): contorno, aro de pedra cinza
## (selecionado = dourado) claro embaixo/direita e escuro em cima/esquerda (parece afundado), contorno interno e fundo
## quase preto com sombra na primeira linha. Selecionado (`input_focus.png`) é só o aro dourado, com o meio
## transparente: o LineEdit desenha o estilo "focus" POR CIMA do normal.
func _input(focused: bool) -> Image:
	var n: int = CARD_SIZE
	var image: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var light: Color = PALETTE["g"] if focused else PALETTE["s"]
	var dark: Color = PALETTE["G"] if focused else PALETTE["S"]
	var fill: Color = Color8(16, 14, 18)
	for y: int in range(n):
		for x: int in range(n):
			var edge: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var color: Color = fill
			match edge:
				0, 2:
					color = PALETTE["k"]
				1:
					# Afundado: luz embaixo/direita, sombra em cima/esquerda.
					color = dark if (y == 1 and x < n - 2) or (x == 1 and y < n - 2) else light
				3:
					color = Color8(8, 7, 10) if (y == 3 or x == 3) else fill
			if focused and edge >= 3:
				color = Color(0, 0, 0, 0)
			image.set_pixel(x, y, color)
	for c: Vector2i in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		image.set_pixelv(c, Color(0, 0, 0, 0))
	return image


## Piso de pedra escura ([constant TILE_SIZE] px, repete sem emenda): 4 lajotas com rejunte escuro, luz em cima e
## sombra embaixo de cada uma e alguns pixels de musgo. Semente fixa: sai sempre igual.
func _stone_tile() -> Image:
	var n: int = TILE_SIZE
	var image: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var stone: Color = Color8(38, 42, 54)
	var light: Color = Color8(52, 57, 72)
	var shadow: Color = Color8(28, 31, 41)
	var grout: Color = Color8(18, 19, 26)
	var half: int = n / 2
	for y: int in range(n):
		for x: int in range(n):
			# Fileira de baixo deslocada meia lajota (como tijolos).
			var lx: int = (x + (half / 2 if y >= half else 0)) % half
			var ly: int = y % half
			var color: Color = stone
			if lx == 0 or ly == 0:
				color = grout
			elif ly == 1:
				color = light
			elif ly == half - 1 or lx == half - 1:
				color = shadow
			image.set_pixel(x, y, color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(6):
		var p: Vector2i = Vector2i(rng.randi_range(1, n - 2), rng.randi_range(1, n - 2))
		if image.get_pixelv(p) != grout:
			image.set_pixelv(p, Color8(44, 62, 50) if i % 2 == 0 else Color8(56, 60, 76))
	return image


func _save(image: Image, file_name: String) -> void:
	var path: String = OUT_DIR + file_name + ".png"
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("falhou salvar %s: %s" % [path, error_string(error)])
