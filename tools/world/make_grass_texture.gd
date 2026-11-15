extends SceneTree
## Gera a textura de grama do chão ([MUN-04], [GroundMaterial]): `assets/textures/grass.png`, 256 × 256 px, que se
## repete sem emenda (as duas bordas casam). É um "detalhe" colorido em volta do cinza médio: o shader do chão
## multiplica pela cor pintada no Blender (× 2), então a média não muda a cor da zona, só dá textura.
##
## Como é feita (semente fixa: sai igual sempre):
## 1. ruído suave sem emenda (manchas de grama mais clara/escura);
## 2. milhares de folhinhas: traços curtos e finos inclinados, claros e escuros, com um pouco de amarelo/azulado;
## 3. tudo dobrado nas bordas (o que sai de um lado entra do outro).
##
## Uso (da pasta mmo-client): godot --headless --path . --script res://tools/world/make_grass_texture.gd

const OUT: String = "res://assets/textures/grass.png"
const SIZE: int = 256
const BLADES: int = 9000
const SEED: int = 11


func _init() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var patches: Image = noise.get_seamless_image(SIZE, SIZE)
	# Base: cinza médio com as manchas (±8%).
	var lum: PackedFloat32Array = PackedFloat32Array()
	var hue: PackedFloat32Array = PackedFloat32Array()  # >0 amarelado, <0 azulado
	lum.resize(SIZE * SIZE)
	hue.resize(SIZE * SIZE)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			lum[y * SIZE + x] = 0.5 + (patches.get_pixel(x, y).r - 0.5) * 0.16
	# Folhinhas.
	for i: int in range(BLADES):
		var x0: float = rng.randf() * SIZE
		var y0: float = rng.randf() * SIZE
		var angle: float = -PI / 2.0 + rng.randf_range(-0.6, 0.6)
		var length: float = rng.randf_range(3.0, 8.0)
		var shade: float = rng.randf_range(-0.16, 0.18)
		var tint: float = rng.randf_range(-1.0, 1.0)
		var steps: int = int(length * 2.0)
		for s: int in range(steps):
			var t: float = float(s) / float(steps)
			var px: int = posmod(int(x0 + cos(angle) * length * t), SIZE)
			var py: int = posmod(int(y0 + sin(angle) * length * t), SIZE)
			var k: int = py * SIZE + px
			# Ponta da folha mais clara que a base.
			lum[k] = lerpf(lum[k], 0.5 + shade + 0.06 * t, 0.55)
			hue[k] = lerpf(hue[k], tint, 0.4)
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var k: int = y * SIZE + x
			var l: float = clampf(lum[k], 0.0, 1.0)
			var h: float = hue[k] * 0.05
			image.set_pixel(x, y, Color(clampf(l + h, 0.0, 1.0), l, clampf(l - h * 1.4, 0.0, 1.0)))
	image.save_png(OUT)
	print("grama: %s (%d px)" % [OUT, SIZE])
	quit()
