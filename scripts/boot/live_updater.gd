class_name LiveUpdater
extends Control
## Atualização com o jogo aberto ("Atualização nova — atualizando..."). Ver mmo-docs [INFRA-08].
##
## Aberto pelo [Network] quando o servidor manda [code]update_required[/code] (versão nova publicada enquanto joga, ou
## pacote velho ao entrar) ou recusa por [code]version_mismatch[/code]. Faz o mesmo que o atualizador do APK, mas DENTRO
## do processo, porque no Android não dá para reiniciar o app (OS.set_restart_on_exit só funciona no desktop):
## 1. tira o [Network] velho da árvore; 2. baixa o manifesto e o pacote novo (barra de progresso), confere o SHA-256 e
## grava em user://update como o atualizador do APK (na próxima abertura ele já acha o pacote e não baixa de novo);
## 3. [code]ProjectSettings.load_resource_pack(pacote, true)[/code] (os arquivos do pacote novo substituem os do
## velho); 4. espera os scripts velhos saírem da memória e reabre [constant GAME_BOOT_SCENE], já com o código novo, que
## entra direto com a sessão salva.
##
## ATENÇÃO (por que este script não usa NENHUMA classe do jogo — Network, NetworkConfig, PackInfo, GameBoot...):
## script que outro script vivo referencia continua em cache, e o jogo novo acabaria usando o código VELHO dele. Este
## script vive até o jogo novo começar a carregar, então só usa nós, caminhos e constantes próprias. Constantes
## repetidas daqui: iguais a scripts/boot/updater.gd (APK), scripts/boot/pack_info.gd e network_config.gd.
## Não há laço de atualização: se o manifesto não tiver versão maior que a instalada, mostra o aviso e "Tentar de novo".

## Esta cena. ATENÇÃO: igual a Network.LIVE_UPDATER_SCENE (scripts/network/network.gd).
const SCENE: String = "res://scenes/boot/live_updater.tscn"
## Primeira cena do jogo (dentro do pacote). ATENÇÃO: igual a GameBoot.SCENE e ao GAME_BOOT_SCENE do updater.gd.
const GAME_BOOT_SCENE: String = "res://scenes/boot/game_boot.tscn"
## Atualizador do APK: lido só para saber o LAUNCHER_VERSION do instalador deste aparelho.
const LAUNCHER_SCRIPT: String = "res://scripts/boot/updater.gd"
## Rota do manifesto no servidor (mmo-server/src/http/updates.ts); %s = plataforma.
const MANIFEST_PATH: String = "/updates/%s/manifest.json"
## Pasta dos pacotes e arquivo com a versão instalada. ATENÇÃO: iguais a updater.gd e PackInfo.
const UPDATE_DIR: String = "user://update"
const INSTALLED_FILE: String = "user://update/installed.cfg"
## Endereço do servidor: o achado na rede local pelo atualizador (só em memória) ou o configurado.
## ATENÇÃO: mesmas chaves e padrão de scripts/network/network_config.gd.
const DISCOVERED_URL_SETTING: String = "mmo/network/discovered_url"
const SERVER_URL_SETTING: String = "mmo/network/server_url"
const DEFAULT_SERVER_URL: String = "ws://localhost:2567"
## Nome do nó do Network na raiz (criado pelo GameBoot com esse nome).
const NETWORK_NODE: String = "Network"
## Tempo máximo (s) para o manifesto responder.
const MANIFEST_TIMEOUT_S: float = 10.0
## Quadros esperados entre soltar o jogo velho e carregar o novo: os nós liberados com queue_free e os scripts sem
## referência saem da memória nesse meio tempo.
const FRAMES_TO_RELEASE: int = 3
## Passadas de recompilação dos scripts em cache (ver [method _restart_game]).
const SCRIPT_RELOAD_PASSES: int = 2

@onready var _status_label: Label = %StatusLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _retry_button: Button = %RetryButton

var _http: HTTPRequest = null
## Download do .pck em andamento (atualiza a barra de progresso).
var _downloading: bool = false
## Manifesto validado em uso.
var _manifest: Dictionary = {}


func _ready() -> void:
	_retry_button.pressed.connect(_start)
	_http = HTTPRequest.new()
	add_child(_http)
	# O Network velho sai da árvore já: nada mais do jogo velho fica rodando (nem reconecta).
	var network: Node = get_tree().root.get_node_or_null(NETWORK_NODE)
	if network != null:
		network.queue_free()
	_start()


func _process(_delta: float) -> void:
	if not _downloading:
		return
	var total: int = _http.get_body_size()
	if total > 0:
		_progress_bar.value = 100.0 * float(_http.get_downloaded_bytes()) / float(total)


## (Re)começa: pede o manifesto da plataforma.
func _start() -> void:
	_retry_button.visible = false
	_progress_bar.visible = false
	_set_status("Atualização nova — atualizando...")
	_http.cancel_request()
	_http.timeout = MANIFEST_TIMEOUT_S
	_http.download_file = ""
	_connect_once(_on_manifest_received)
	var url: String = _http_base_url() + MANIFEST_PATH % _platform()
	print("LiveUpdater: manifesto em ", url)
	if _http.request(url) != OK:
		_on_manifest_received(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _on_manifest_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Sem conexão com o servidor para atualizar.\n(erro %d/%d)" % [result, code])
		return
	var manifest: Dictionary = _parse_manifest(body.get_string_from_utf8())
	if manifest.is_empty():
		_fail("Resposta inválida do servidor de atualização.")
		return
	var min_launcher: int = manifest["minLauncherVersion"]
	if min_launcher > _launcher_version():
		_set_status("Há um instalador novo. Baixe e instale o APK mais recente para continuar.")
		return
	var version: int = manifest["version"]
	if version <= _installed_version():
		# Recusado por protocolo diferente mas sem pacote novo (servidor à frente da publicação): sem laço.
		_fail("O servidor está numa versão diferente do jogo, mas ainda não há atualização publicada.\nTente de novo em instantes.")
		return
	_manifest = manifest
	_download_pack()


func _download_pack() -> void:
	var version: int = _manifest["version"]
	var url: String = _manifest["url"]
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_set_status("Atualização nova — baixando a versão %d..." % version)
	_progress_bar.value = 0.0
	_progress_bar.visible = true
	_http.timeout = 0.0
	_http.download_file = _pack_path(version) + ".part"
	_downloading = true
	_connect_once(_on_pack_downloaded)
	var full_url: String = url if url.begins_with("http") else _http_base_url() + url
	var error: Error = _http.request(full_url)
	if error != OK:
		_downloading = false
		_fail("Não foi possível baixar a atualização (%s)." % error_string(error))


func _on_pack_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	_http.download_file = ""
	var version: int = _manifest["version"]
	var final_path: String = _pack_path(version)
	var part: String = final_path + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		_fail("O download da atualização falhou. Tente de novo.")
		return
	var expected_sha: String = _manifest["sha256"]
	if FileAccess.get_sha256(part) != expected_sha:
		DirAccess.remove_absolute(part)
		_fail("A atualização chegou corrompida. Tente de novo.")
		return
	DirAccess.remove_absolute(final_path)
	DirAccess.rename_absolute(part, final_path)
	_progress_bar.visible = false
	_set_status("Carregando a versão %d..." % version)
	if not ProjectSettings.load_resource_pack(final_path, true):
		DirAccess.remove_absolute(final_path)
		_fail("Não foi possível abrir a atualização. Tente de novo.")
		return
	# Só depois de carregar: o atualizador do APK passa a abrir esta versão nas próximas vezes.
	var config: ConfigFile = ConfigFile.new()
	config.set_value("pack", "version", version)
	config.save(INSTALLED_FILE)
	_delete_old_packs(version)
	_restart_game()


## Reabre o jogo com o código do pacote novo. O que o jogo velho deixou no cache (scripts e recursos: quase tudo,
## porque scripts com [code]static var[/code] e as referências entre eles nunca saem da memória) é relido do pacote
## novo antes, senão o jogo reaberto continuaria com o código e as cenas velhas (testado em 2026-11-14).
func _restart_game() -> void:
	for i: int in FRAMES_TO_RELEASE:
		await get_tree().process_frame
	var started_ms: int = Time.get_ticks_msec()
	var resources: Array[String] = []
	var scripts: Array[String] = []
	_collect_files("res://", resources, scripts)
	var own_script: String = get_script().resource_path
	var refreshed: int = 0
	# Cenas, materiais, malhas, texturas...: CACHE_MODE_REPLACE relê do pacote novo para DENTRO das instâncias em cache.
	for path: String in resources:
		if ResourceLoader.has_cached(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			refreshed += 1
	# Scripts: CACHE_MODE_IGNORE faz o GDScript reler o arquivo e recompilar o MESMO objeto (como o hot reload do
	# editor). Duas passadas: na primeira, um script pode compilar contra um vizinho ainda velho (constante/método novo).
	# Este script fica de fora: recompilar o script que está rodando quebra a execução.
	for pass_index: int in SCRIPT_RELOAD_PASSES:
		for path: String in scripts:
			if path != own_script and ResourceLoader.has_cached(path):
				ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
				if pass_index == 0:
					refreshed += 1
	print("LiveUpdater: %d recursos relidos em %d ms" % [refreshed, Time.get_ticks_msec() - started_ms])
	get_tree().change_scene_to_file(GAME_BOOT_SCENE)


## Junta os caminhos (como o jogo os carrega) de todos os arquivos de [param dir] para baixo: scripts em
## [param scripts], o resto em [param resources]. No pacote exportado os nomes mudam ("x.png.import", "x.tscn.remap",
## "x.gdc"): volta ao caminho original. Pula pastas ocultas (.godot: os importados são lidos pelo caminho original).
func _collect_files(dir: String, resources: Array[String], scripts: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect_files(dir.path_join(sub), resources, scripts)
	for file: String in DirAccess.get_files_at(dir):
		var name: String = file.trim_suffix(".remap").trim_suffix(".import")
		if name.ends_with(".gdc"):
			name = name.trim_suffix(".gdc") + ".gd"
		if name.ends_with(".uid") or name.ends_with(".cfg") or name.ends_with(".binary"):
			continue
		var path: String = dir.path_join(name)
		var target: Array[String] = scripts if name.ends_with(".gd") else resources
		if not target.has(path):
			target.append(path)


func _set_status(message: String) -> void:
	_status_label.text = message
	print("LiveUpdater: ", message)


func _fail(message: String) -> void:
	_progress_bar.visible = false
	_set_status(message)
	_retry_button.visible = true


## Conecta o callback ao request_completed só para a próxima resposta.
func _connect_once(callback: Callable) -> void:
	for connection: Dictionary in _http.request_completed.get_connections():
		var old: Callable = connection["callable"]
		_http.request_completed.disconnect(old)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)


## LAUNCHER_VERSION do atualizador que está no APK deste aparelho (1 se não der para ler).
func _launcher_version() -> int:
	var launcher: Script = load(LAUNCHER_SCRIPT) as Script
	if launcher == null:
		return 1
	var value: Variant = launcher.get_script_constant_map().get("LAUNCHER_VERSION", 1)
	return value if value is int else 1


## Versão gravada em [constant INSTALLED_FILE] (0 se não houver). ATENÇÃO: mesma leitura de PackInfo.installed_version.
func _installed_version() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(INSTALLED_FILE) != OK:
		return 0
	var value: Variant = config.get_value("pack", "version", 0)
	return value if value is int else 0


## ATENÇÃO: mesmos nomes de PackInfo.platform, updater.gd e tools/publish_update.sh.
func _platform() -> String:
	return "android" if OS.has_feature("android") else "desktop"


## Endereço HTTP do servidor, derivado do WebSocket (ws:// → http://, wss:// → https://), como no updater.gd.
func _http_base_url() -> String:
	var ws_url: String = ""
	if ProjectSettings.has_setting(DISCOVERED_URL_SETTING):
		ws_url = str(ProjectSettings.get_setting(DISCOVERED_URL_SETTING))
	if ws_url.is_empty():
		var setting: Variant = ProjectSettings.get_setting_with_override(SERVER_URL_SETTING)
		ws_url = str(setting) if setting != null else DEFAULT_SERVER_URL
	ws_url = ws_url.trim_suffix("/")
	if ws_url.begins_with("wss://"):
		return "https://" + ws_url.trim_prefix("wss://")
	return "http://" + ws_url.trim_prefix("ws://")


func _pack_path(version: int) -> String:
	return "%s/game-%d.pck" % [UPDATE_DIR, version]


## Apaga pacotes de outras versões e downloads incompletos (o velho já carregado continua aberto até o app fechar).
func _delete_old_packs(keep_version: int) -> void:
	var keep: String = "game-%d.pck" % keep_version
	for file: String in DirAccess.get_files_at(UPDATE_DIR):
		if file != keep and file.begins_with("game-"):
			DirAccess.remove_absolute("%s/%s" % [UPDATE_DIR, file])


## Valida o manifesto. {} se faltar campo ou o tipo estiver errado. ATENÇÃO: mesmo formato e regras do updater.gd.
## { version: int, url: String, sha256: String (64 hex), size: int, minLauncherVersion: int }.
func _parse_manifest(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	var result: Dictionary = {}
	for key: String in ["version", "size", "minLauncherVersion"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int):
			return {}
		var number: float = value
		if number < 0.0 or number != floorf(number):
			return {}
		result[key] = int(number)
	for key: String in ["url", "sha256"]:
		var value: Variant = data.get(key)
		if not value is String:
			return {}
		var text_value: String = value
		result[key] = text_value
	var sha: String = result["sha256"]
	if sha.length() != 64 or not sha.is_valid_hex_number():
		return {}
	result["sha256"] = sha.to_lower()
	return result
