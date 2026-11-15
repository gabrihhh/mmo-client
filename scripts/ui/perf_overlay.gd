class_name PerfOverlay
extends Label
## Medidor de desempenho na HUD ([INFRA-12], ligado em Configuração → "Medidor de desempenho"): uma linha pequena com
## o ping (de mandar um passo até o servidor confirmar), a variação da rede, a margem de interpolação dos outros e o
## FPS com o pior quadro dos últimos 10 s. Cor do ping: verde até 80 ms, amarelo até 150, vermelho acima.
## Só lê o [Network]; atualiza 4 vezes por segundo.

const REFRESH_SECONDS: float = 0.25
const COLOR_GOOD: Color = Color(0.5, 1.0, 0.5)
const COLOR_MID: Color = Color(1.0, 0.85, 0.35)
const COLOR_BAD: Color = Color(1.0, 0.45, 0.4)

var _left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_theme_constant_override("outline_size", 6)


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or Network.instance == null:
		return
	_left = REFRESH_SECONDS
	var network: Network = Network.instance
	var ping: String = "—" if network.ping_ms < 0.0 else "%d ms" % int(network.ping_ms)
	var delay_ms: int = int(network.interpolation_delay_ticks * 1000.0 / network.tick_rate)
	text = "Ping %s · Rede ±%d ms · Margem %d ms · %d FPS (pior %d ms)" % [
		ping, int(network.jitter_ms), delay_ms, Engine.get_frames_per_second(), network.worst_frame_window_ms]
	var color: Color = COLOR_GOOD
	if network.ping_ms > 150.0:
		color = COLOR_BAD
	elif network.ping_ms > 80.0:
		color = COLOR_MID
	add_theme_color_override("font_color", color)
