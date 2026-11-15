class_name UpgradeForge
extends Control
## Animação da melhoria no ferreiro ([JOGO-16]): camada por cima da tela do ferreiro que segura o resultado do
## servidor até o "ápice", para a melhoria não ser instantânea.
##
## 1. **Forjando** ([constant CHARGE_SECONDS]): fundo escuro, o ícone do item no meio, um anel dourado enchendo cada
##    vez mais rápido, faíscas saindo e o item tremendo mais forte perto do fim; "Martelando..." embaixo.
## 2. **Ápice** (anel cheio e o resultado já chegou — se ainda não chegou, o anel pulsa cheio esperando):
##    - deu certo: clarão branco, explosão de faíscas douradas, o ícone "pula" e aparece "+N!" com o atributo;
##    - falhou: clarão vermelho, o ícone treme forte e "Falhou" com as moedas perdidas.
## 3. Fica [constant REVEAL_SECONDS] mostrando (toque pula) e emite [signal finished].
## Enquanto aparece, segura todos os toques (não dá para apertar nada embaixo).

## A animação acabou (depois do resultado): a tela do ferreiro aplica o resultado e o inventário novo.
signal finished

## Duração (s) do anel enchendo até o ápice.
const CHARGE_SECONDS: float = 1.8
## Quanto tempo (s) o resultado fica na tela antes de fechar sozinho.
const REVEAL_SECONDS: float = 1.6
## Sem resposta do servidor depois de tanto tempo (s) no ápice: fecha sem resultado.
const WAIT_TIMEOUT_SECONDS: float = 6.0
## Lado (px) do ícone do item e raio (px) do anel.
const ICON_PX: float = 176.0
const RING_RADIUS_PX: float = 132.0
const RING_WIDTH_PX: float = 12.0
## Tremida máxima (px) do ícone no fim da carga e na falha.
const CHARGE_SHAKE_PX: float = 7.0
const FAIL_SHAKE_PX: float = 16.0
const GOLD: Color = Color(1.0, 0.82, 0.3)
const FAIL_RED: Color = Color(1.0, 0.35, 0.3)
const BACKDROP: Color = Color(0.03, 0.02, 0.01, 0.82)

## Uma faísca (quadradinho pixel art que voa e apaga).
class Spark:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var total: float = 1.0
	var color: Color = Color.WHITE
	var size: float = 4.0

enum Phase { HIDDEN, CHARGING, REVEAL }

var _phase: Phase = Phase.HIDDEN
var _time: float = 0.0
var _icon: Texture2D = null
var _frame_color: Color = GOLD
## Resultado já chegou? (e qual)
var _has_result: bool = false
var _success: bool = false
var _title: String = ""
var _subtitle: String = ""
var _sparks: Array[Spark] = []
var _spark_debt: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


## Começa a forjar o item de ícone [param icon] (moldura na cor [param frame_color]).
func start(icon: Texture2D, frame_color: Color) -> void:
	_icon = icon
	_frame_color = frame_color
	_phase = Phase.CHARGING
	_time = 0.0
	_has_result = false
	_sparks.clear()
	visible = true
	queue_redraw()


## O resultado chegou: aparece no ápice. [param title] grande ("+5!" / "Falhou"), [param subtitle] embaixo.
func set_result(success: bool, title: String, subtitle: String) -> void:
	_has_result = true
	_success = success
	_title = title
	_subtitle = subtitle


## Fecha na hora, sem resultado (recusa do servidor).
func abort() -> void:
	_phase = Phase.HIDDEN
	visible = false


## Está aparecendo (forjando ou mostrando o resultado).
func is_running() -> bool:
	return _phase != Phase.HIDDEN


func _gui_input(event: InputEvent) -> void:
	accept_event()
	# Toque durante o resultado pula a espera.
	if _phase == Phase.REVEAL and _time > 0.4 and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


func _process(delta: float) -> void:
	if _phase == Phase.HIDDEN:
		return
	_time += delta
	var center: Vector2 = _center()
	if _phase == Phase.CHARGING:
		var charge: float = _charge()
		# Faíscas cada vez mais frequentes, saindo da borda do ícone.
		_spark_debt += delta * lerpf(6.0, 60.0, charge * charge)
		while _spark_debt >= 1.0:
			_spark_debt -= 1.0
			var angle: float = randf() * TAU
			_add_spark(center + Vector2.from_angle(angle) * ICON_PX * 0.45, Vector2.from_angle(angle) * randf_range(80.0, 220.0) + Vector2(0, -60), GOLD.lerp(Color.WHITE, randf() * 0.6), randf_range(0.35, 0.7))
		if _time >= CHARGE_SECONDS and _has_result:
			_reveal()
		elif _time >= CHARGE_SECONDS + WAIT_TIMEOUT_SECONDS:
			abort()
			finished.emit()
	elif _phase == Phase.REVEAL and _time >= REVEAL_SECONDS:
		_close()
	for k: int in range(_sparks.size() - 1, -1, -1):
		var spark: Spark = _sparks[k]
		spark.life -= delta
		if spark.life <= 0.0:
			_sparks.remove_at(k)
			continue
		spark.velocity.y += 260.0 * delta
		spark.position += spark.velocity * delta
	queue_redraw()


## Carga de 0 a 1, acelerando (devagar no começo, rápida no fim).
func _charge() -> float:
	var t: float = clampf(_time / CHARGE_SECONDS, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t) * 0.35 + t * t * 0.65


func _reveal() -> void:
	_phase = Phase.REVEAL
	_time = 0.0
	var center: Vector2 = _center()
	var count: int = 70 if _success else 24
	for k: int in range(count):
		var angle: float = randf() * TAU
		var color: Color = GOLD.lerp(Color.WHITE, randf() * 0.5) if _success else Color(0.45, 0.42, 0.4).lerp(FAIL_RED, randf() * 0.5)
		var speed: float = randf_range(180.0, 520.0) if _success else randf_range(60.0, 200.0)
		_add_spark(center, Vector2.from_angle(angle) * speed, color, randf_range(0.6, 1.2))


func _close() -> void:
	_phase = Phase.HIDDEN
	visible = false
	finished.emit()


func _add_spark(at: Vector2, velocity: Vector2, color: Color, life: float) -> void:
	var spark: Spark = Spark.new()
	spark.position = at
	spark.velocity = velocity
	spark.life = life
	spark.total = life
	spark.color = color
	spark.size = randf_range(3.0, 7.0)
	_sparks.append(spark)


func _center() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.42)


func _draw() -> void:
	if _phase == Phase.HIDDEN:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	var center: Vector2 = _center()
	var font: Font = get_theme_default_font()
	var charging: bool = _phase == Phase.CHARGING
	var charge: float = _charge() if charging else 1.0

	# Anel: fundo apagado + parte cheia dourada (pulsa quando cheio esperando o servidor).
	draw_arc(center, RING_RADIUS_PX, 0.0, TAU, 64, Color(1, 1, 1, 0.12), RING_WIDTH_PX)
	var ring_color: Color = GOLD
	if charging and _time >= CHARGE_SECONDS:
		ring_color = GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 12.0))
	elif not charging:
		ring_color = GOLD if _success else FAIL_RED
	draw_arc(center, RING_RADIUS_PX, -PI / 2.0, -PI / 2.0 + TAU * charge, 64, ring_color, RING_WIDTH_PX)

	# Ícone com moldura, tremendo (mais forte perto do fim / na falha) e "pulando" no sucesso.
	var shake: float = 0.0
	var scale_icon: float = 1.0
	if charging:
		shake = CHARGE_SHAKE_PX * charge * charge
	elif _success:
		scale_icon = 1.0 + 0.3 * maxf(0.0, 1.0 - _time / 0.35)
	else:
		shake = FAIL_SHAKE_PX * maxf(0.0, 1.0 - _time / 0.6)
	var offset: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var side: float = ICON_PX * scale_icon
	var box: Rect2 = Rect2(center + offset - Vector2(side, side) / 2.0, Vector2(side, side))
	draw_rect(box.grow(6.0), Color(0.11, 0.08, 0.06))
	draw_rect(box.grow(6.0), _frame_color, false, 5.0)
	if _icon != null:
		draw_texture_rect(_icon, box.grow(-12.0), false)

	for spark: Spark in _sparks:
		var faded: Color = spark.color
		faded.a = clampf(spark.life / spark.total, 0.0, 1.0)
		draw_rect(Rect2(spark.position - Vector2(spark.size, spark.size) / 2.0, Vector2(spark.size, spark.size)), faded)

	var text_y: float = center.y + RING_RADIUS_PX + 90.0
	if charging:
		var dots: String = ".".repeat(1 + int(_time * 3.0) % 3)
		_draw_centered(font, "Martelando" + dots, text_y, 34, Color(1, 1, 1, 0.85))
	else:
		_draw_centered(font, _title, text_y, 64, GOLD if _success else FAIL_RED)
		_draw_centered(font, _subtitle, text_y + 56.0, 28, Color(1, 1, 1, 0.85))
		# Clarão: branco no sucesso, vermelho na falha, apagando rápido.
		var flash: float = maxf(0.0, 1.0 - _time / 0.35)
		if flash > 0.0:
			var flash_color: Color = Color(1, 1, 1, 0.75 * flash) if _success else Color(1, 0.15, 0.1, 0.5 * flash)
			draw_rect(Rect2(Vector2.ZERO, size), flash_color)


func _draw_centered(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at: Vector2 = Vector2((size.x - width) / 2.0, y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color8(24, 16, 12))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
