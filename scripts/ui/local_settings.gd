class_name LocalSettings
extends RefCounted
## Opções guardadas só NESTE aparelho (não na conta), em `user://settings.cfg` ([CLI-08]). Hoje: mostrar o medidor de
## desempenho (ping, variação da rede, FPS; [PerfOverlay], [INFRA-12]).

const _PATH: String = "user://settings.cfg"
const _SECTION: String = "hud"
const _KEY_PERF: String = "show_perf"


## Mostrar o medidor de desempenho na HUD? (padrão: não)
static func show_perf() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_PATH) != OK:
		return false
	var value: Variant = config.get_value(_SECTION, _KEY_PERF, false)
	return value is bool and value == true


## Grava a opção do medidor de desempenho.
static func set_show_perf(enabled: bool) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(_PATH)
	config.set_value(_SECTION, _KEY_PERF, enabled)
	var error: Error = config.save(_PATH)
	if error != OK:
		push_warning("LocalSettings: não foi possível salvar (%s)" % error_string(error))
