class_name DeathScreen
extends Control
## Tela de morte ([JOGO-21]), por cima de tudo, quando o SEU personagem morre (qualquer motivo). O resultado já veio
## do servidor ([DeathReport]); aqui é só a apresentação, em etapas:
##
## 1. **"Você morreu"** ([constant RED_SECONDS]): a tela fica vermelha e o texto aparece grande, com quem matou.
## 2. **Roleta** ([constant ROULETTE_SECONDS]): os ícones das peças vestidas passam por uma faixa, rápido e freando, até
##    parar na peça sorteada (embaixo do marcador). Sem nada vestido: pula para o resumo.
## 3. **Carregamento** igual ao do ferreiro ([UpgradeForge]) com a peça no meio; no fim, "Item preservado" (dourado) ou
##    "Seu item quebrou!" (vermelho; ele sumiu do inventário — chance 0,05%).
## 4. **Resumo**: moedas e XP perdidas, o que aconteceu com a peça e o botão **Renascer** (ou renasce sozinho quando
##    acabar o tempo, [member Network.respawn_in]).
## Segura todos os toques enquanto aparece (o jogo embaixo não recebe nada).

## Apertou "Renascer".
signal respawn_pressed

const RED_SECONDS: float = 1.6
const ROULETTE_SECONDS: float = 3.2
## Lado (px) de cada ícone da roleta e o espaço entre eles.
const ROULETTE_ICON_PX: float = 132.0
const ROULETTE_GAP_PX: float = 20.0
## Voltas da faixa antes de parar (quantas vezes a lista de peças passa).
const ROULETTE_LAPS: int = 7
const RED: Color = Color(0.55, 0.02, 0.02, 0.86)
const BACKDROP: Color = Color(0.05, 0.01, 0.01, 0.9)
const GOLD: Color = Color(1.0, 0.82, 0.3)
const FAIL_RED: Color = Color(1.0, 0.35, 0.3)
const OUTLINE: Color = Color8(24, 16, 12)

enum Phase { HIDDEN, RED_FLASH, ROULETTE, FORGE, SUMMARY }

var _phase: Phase = Phase.HIDDEN
var _time: float = 0.0
var _report: DeathReport = null
## Faixa da roleta: as peças repetidas; [member _target_index] = onde ela para (a sorteada).
var _strip: Array[DeathReport.Piece] = []
var _target_index: int = 0
var _forge: UpgradeForge = null
var _summary: VBoxContainer = null
var _summary_lines: Label = null
var _item_line: Label = null
var _respawn_button: Button = null
var _countdown: Label = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	_build()


## Monta a forja e o resumo já na criação (pode receber [method start] antes de entrar na árvore).
func _build() -> void:
	_forge = UpgradeForge.new()
	_forge.charge_text = "O destino do seu item"
	_forge.finished.connect(_show_summary)
	add_child(_forge)
	_summary = VBoxContainer.new()
	_summary.set_anchors_preset(Control.PRESET_CENTER)
	_summary.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary.custom_minimum_size = Vector2(600.0, 0.0)
	_summary.add_theme_constant_override("separation", 24)
	_summary.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_summary)
	var title: Label = _label("Você morreu", 72, FAIL_RED)
	_summary.add_child(title)
	_summary_lines = _label("", 34, Color(1, 1, 1, 0.9))
	_summary.add_child(_summary_lines)
	_item_line = _label("", 30, GOLD)
	_summary.add_child(_item_line)
	_respawn_button = PixelMenuPanel.make_button("Renascer")
	_respawn_button.custom_minimum_size = Vector2(420.0, 104.0)
	_respawn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_respawn_button.pressed.connect(_on_respawn_pressed)
	_summary.add_child(_respawn_button)
	_countdown = _label("", 24, Color(1, 1, 1, 0.6))
	_summary.add_child(_countdown)
	_summary.visible = false


## Começa a tela com o que veio do servidor.
func start(report: DeathReport) -> void:
	_report = report
	_phase = Phase.RED_FLASH
	_time = 0.0
	visible = true
	_summary.visible = false
	_forge.abort()
	_build_strip()
	queue_redraw()


## Morreu sem o relatório ter chegado (ainda): mostra só "Você morreu" e o botão, sem roleta.
func start_without_report() -> void:
	if visible:
		return
	start(DeathReport.new())


## Renasceu (pelo botão ou sozinho): some.
func finish() -> void:
	_phase = Phase.HIDDEN
	visible = false
	_forge.abort()


## Está aparecendo.
func is_showing() -> bool:
	return visible


## Segundos até renascer sozinho (vem do snapshot): atualiza o texto embaixo do botão.
func set_respawn_in(seconds: float) -> void:
	if _countdown != null:
		_countdown.text = "Renasce sozinho em %d s" % ceili(seconds) if seconds > 0.0 else ""


func _gui_input(event: InputEvent) -> void:
	accept_event()
	# Toque pula a tela vermelha e a roleta (o resultado é o mesmo).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _time > 0.5:
		if _phase == Phase.RED_FLASH:
			_begin_roulette()
		elif _phase == Phase.ROULETTE:
			_begin_forge()


func _process(delta: float) -> void:
	if _phase == Phase.HIDDEN:
		return
	_time += delta
	if _phase == Phase.RED_FLASH and _time >= RED_SECONDS:
		_begin_roulette()
	elif _phase == Phase.ROULETTE and _time >= ROULETTE_SECONDS + 0.6:
		_begin_forge()
	queue_redraw()


func _build_strip() -> void:
	_strip.clear()
	var pieces: Array[DeathReport.Piece] = _report.equipped
	if pieces.is_empty():
		return
	for lap: int in range(ROULETTE_LAPS):
		_strip.append_array(pieces)
	var picked: int = maxi(0, pieces.find(_report.picked()))
	# Para na última volta, na peça sorteada (com algumas peças depois dela na faixa, para não acabar no vazio).
	_target_index = (ROULETTE_LAPS - 2) * pieces.size() + picked


func _begin_roulette() -> void:
	if _strip.is_empty() or _report.picked() == null:
		_show_summary()
		return
	_phase = Phase.ROULETTE
	_time = 0.0


func _begin_forge() -> void:
	var piece: DeathReport.Piece = _report.picked()
	if piece == null:
		_show_summary()
		return
	_phase = Phase.FORGE
	_time = 0.0
	_forge.start(ItemIcons.item(piece.item.item_id), ItemIcons.set_color(piece.item.set_name))
	if _report.broken:
		_forge.set_result(false, "Seu item quebrou!", "%s sumiu do inventário" % piece.item.display_name())
	else:
		_forge.set_result(true, "Item preservado", piece.item.display_name())


func _show_summary() -> void:
	if _phase == Phase.HIDDEN:
		return
	_phase = Phase.SUMMARY
	_time = 0.0
	var lines: Array[String] = []
	if not _report.killer.is_empty():
		lines.append("Derrotado por %s" % _report.killer)
	lines.append("− %s moedas" % InventoryView.format_gold(_report.gold_lost))
	# Morte para jogador ([JOGO-22]): perde nível (e as moedas foram para quem matou); para monstro: XP.
	if _report.levels_lost > 0:
		lines.append("− %d nível" % _report.levels_lost)
	if _report.xp_lost > 0.0:
		lines.append("− %s XP" % ("%d" % roundi(_report.xp_lost) if is_equal_approx(_report.xp_lost, roundf(_report.xp_lost)) else "%.1f" % _report.xp_lost))
	_summary_lines.text = "\n".join(lines)
	var piece: DeathReport.Piece = _report.picked()
	if piece == null:
		_item_line.text = ""
	elif _report.broken:
		_item_line.text = "Seu item quebrou: %s" % piece.item.display_name()
		_item_line.add_theme_color_override("font_color", FAIL_RED)
	else:
		_item_line.text = "Item preservado: %s" % piece.item.display_name()
		_item_line.add_theme_color_override("font_color", GOLD)
	_summary.visible = true


func _on_respawn_pressed() -> void:
	_respawn_button.disabled = true
	respawn_pressed.emit()
	# Reabilita se o servidor demorar (o snapshot "vivo" fecha a tela).
	get_tree().create_timer(2.0).timeout.connect(func() -> void: _respawn_button.disabled = false)


func _draw() -> void:
	if _phase == Phase.HIDDEN:
		return
	var font: Font = get_theme_default_font()
	match _phase:
		Phase.RED_FLASH:
			# Vermelho entrando forte e o texto crescendo.
			var t: float = clampf(_time / 0.35, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(RED.r, RED.g, RED.b, RED.a * t))
			var font_size: int = int(lerpf(56.0, 96.0, t))
			_draw_centered(font, "Você morreu", size.y * 0.42, font_size, Color(1, 0.92, 0.9))
			if _report != null and not _report.killer.is_empty():
				_draw_centered(font, "Derrotado por %s" % _report.killer, size.y * 0.42 + 80.0, 32, Color(1, 1, 1, 0.8 * t))
		Phase.ROULETTE:
			draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
			_draw_centered(font, "Qual item o destino vai testar?", size.y * 0.28, 34, Color(1, 1, 1, 0.85))
			_draw_roulette()
		Phase.FORGE, Phase.SUMMARY:
			draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


## Faixa de ícones passando da direita para a esquerda, freando (cúbica) até a peça sorteada ficar no centro.
func _draw_roulette() -> void:
	var step: float = ROULETTE_ICON_PX + ROULETTE_GAP_PX
	var t: float = clampf(_time / ROULETTE_SECONDS, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var position_px: float = eased * float(_target_index) * step
	var center: Vector2 = Vector2(size.x / 2.0, size.y * 0.42)
	var band: Rect2 = Rect2(Vector2(0.0, center.y - ROULETTE_ICON_PX / 2.0 - 18.0), Vector2(size.x, ROULETTE_ICON_PX + 36.0))
	draw_rect(band, Color(0.11, 0.07, 0.05))
	draw_rect(band, GOLD, false, 4.0)
	for i: int in range(_strip.size()):
		var x: float = center.x + float(i) * step - position_px
		if x < -ROULETTE_ICON_PX or x > size.x + ROULETTE_ICON_PX:
			continue
		var piece: DeathReport.Piece = _strip[i]
		var box: Rect2 = Rect2(Vector2(x - ROULETTE_ICON_PX / 2.0, center.y - ROULETTE_ICON_PX / 2.0), Vector2(ROULETTE_ICON_PX, ROULETTE_ICON_PX))
		var landed: bool = t >= 1.0 and i == _target_index
		draw_rect(box, Color(0.16, 0.11, 0.08))
		draw_rect(box, GOLD if landed else ItemIcons.set_color(piece.item.set_name), false, 6.0 if landed else 4.0)
		var icon: Texture2D = ItemIcons.item(piece.item.item_id)
		if icon != null:
			draw_texture_rect(icon, box.grow(-12.0), false)
	# Marcador no meio (em cima e embaixo da faixa).
	var top: float = band.position.y
	var bottom: float = band.end.y
	draw_colored_polygon(PackedVector2Array([Vector2(center.x - 18.0, top - 22.0), Vector2(center.x + 18.0, top - 22.0), Vector2(center.x, top + 6.0)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(center.x - 18.0, bottom + 22.0), Vector2(center.x + 18.0, bottom + 22.0), Vector2(center.x, bottom - 6.0)]), GOLD)
	if t >= 1.0 and _report.picked() != null:
		_draw_centered(_font(), _report.picked().item.display_name(), bottom + 80.0, 36, GOLD)


func _font() -> Font:
	return get_theme_default_font()


func _draw_centered(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at: Vector2 = Vector2((size.x - width) / 2.0, y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
