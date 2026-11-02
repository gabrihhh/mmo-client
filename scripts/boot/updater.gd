extends Control
## Atualizador: a ÚNICA cena que vai dentro do APK. Ver mmo-docs [INFRA-08].
##
## Ao abrir: baixa o manifesto do servidor, baixa o pacote do jogo (.pck) se houver versão nova,
## confere o SHA-256, carrega o pacote e abre o [code]GameBoot[/code] (que vem dentro do pacote).
## A atualização é OBRIGATÓRIA: sem conseguir falar com o servidor, o jogo não abre (ele também
## não funcionaria sem servidor).
##
## ATENÇÃO: este script fica no APK e não pode usar nenhuma classe do jogo (Network, Protocol...):
## elas só existem depois de carregar o pacote. Mudou algo aqui → é preciso um APK novo e subir
## [constant LAUNCHER_VERSION].
##
## Dev: se os arquivos do jogo já existem localmente (rodando o projeto pelo editor/terminal), pula a
## atualização e usa esses arquivos (a não ser com `-- --update`). No APK eles não existem.

## Versão deste instalador. O manifesto pode exigir uma mínima (minLauncherVersion).
const LAUNCHER_VERSION: int = 1
## Rota do manifesto no servidor (mmo-server/src/http/updates.ts); %s = plataforma (ver [method _platform]).
const MANIFEST_PATH: String = "/updates/%s/manifest.json"
## Primeira cena do jogo, dentro do pacote. ATENÇÃO: igual a GameBoot.SCENE (scripts/boot/game_boot.gd).
const GAME_BOOT_SCENE: String = "res://scenes/boot/game_boot.tscn"
## Mesma configuração usada pelo jogo para o endereço do servidor (ws://...). Fica no APK.
const SERVER_URL_SETTING: String = "mmo/network/server_url"
## Pasta dos pacotes baixados e o arquivo que diz qual versão está instalada.
const UPDATE_DIR: String = "user://update"
const INSTALLED_FILE: String = "user://update/installed.cfg"
## Força o fluxo de atualização mesmo com os arquivos do jogo presentes localmente.
const FORCE_UPDATE_ARG: String = "--update"
## Tempo máximo (s) para baixar o manifesto. O .pck não tem limite (pode ser grande em rede lenta).
const MANIFEST_TIMEOUT_S: float = 10.0

@onready var _status_label: Label = %StatusLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _retry_button: Button = %RetryButton

var _http: HTTPRequest = null
## Download do .pck em andamento (para atualizar a barra de progresso).
var _downloading: bool = false
## Manifesto em processamento (já validado).
var _manifest: Dictionary = {}


func _ready() -> void:
	_retry_button.pressed.connect(_start)
	_http = HTTPRequest.new()
	add_child(_http)
	var game_is_local: bool = ResourceLoader.exists(GAME_BOOT_SCENE)
	if game_is_local and not FORCE_UPDATE_ARG in OS.get_cmdline_user_args():
		_open_game.call_deferred()
		return
	_start()


func _process(_delta: float) -> void:
	if not _downloading:
		return
	var total: int = _http.get_body_size()
	if total > 0:
		_progress_bar.value = 100.0 * float(_http.get_downloaded_bytes()) / float(total)


## (Re)começa: baixa o manifesto.
func _start() -> void:
	_retry_button.visible = false
	_progress_bar.visible = false
	_set_status("Procurando atualizações...")
	_http.timeout = MANIFEST_TIMEOUT_S
	_http.download_file = ""
	_connect_once(_on_manifest_received)
	print("Updater: manifesto em ", _manifest_url())
	var error: Error = _http.request(_manifest_url())
	if error != OK:
		_fail("Endereço do servidor inválido (%s)." % error_string(error))


func _on_manifest_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("Updater: manifesto falhou: url=%s result=%d http=%d" % [_manifest_url(), result, code])
		_fail("Sem conexão com o servidor. Verifique a internet.\n(erro %d/%d)" % [result, code])
		return
	var manifest: Dictionary = _parse_manifest(body.get_string_from_utf8())
	if manifest.is_empty():
		_fail("Resposta inválida do servidor de atualização.")
		return
	var min_launcher: int = manifest["minLauncherVersion"]
	if min_launcher > LAUNCHER_VERSION:
		_set_status("Há um instalador novo. Baixe e instale o APK mais recente para continuar.")
		return
	_manifest = manifest

	var version: int = manifest["version"]
	var installed_path: String = _installed_pack_path(version)
	var expected_sha: String = manifest["sha256"]
	if not installed_path.is_empty() and FileAccess.get_sha256(installed_path) == expected_sha:
		_load_and_open(installed_path)
		return
	_download_pack()


func _download_pack() -> void:
	var version: int = _manifest["version"]
	var url: String = _manifest["url"]
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_set_status("Baixando atualização (versão %d)..." % version)
	_progress_bar.value = 0.0
	_progress_bar.visible = true
	_http.timeout = 0.0
	_http.download_file = _part_path(version)
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
	var part: String = _part_path(version)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		_fail("O download da atualização falhou. Tente de novo.")
		return
	var expected_sha: String = _manifest["sha256"]
	if FileAccess.get_sha256(part) != expected_sha:
		DirAccess.remove_absolute(part)
		_fail("A atualização chegou corrompida. Tente de novo.")
		return

	# Só agora troca: até aqui o pacote antigo continua intacto.
	var final_path: String = _pack_path(version)
	DirAccess.remove_absolute(final_path)
	DirAccess.rename_absolute(part, final_path)
	_save_installed(version)
	_delete_old_packs(version)
	_load_and_open(final_path)


func _load_and_open(path: String) -> void:
	_progress_bar.visible = false
	_set_status("Carregando...")
	if not ProjectSettings.load_resource_pack(path):
		DirAccess.remove_absolute(path)
		_fail("Não foi possível abrir a atualização. Tente de novo.")
		return
	_open_game()


func _open_game() -> void:
	get_tree().change_scene_to_file(GAME_BOOT_SCENE)


## Mostra o status na tela e no log (no Android aparece no logcat).
func _set_status(message: String) -> void:
	_status_label.text = message
	print("Updater: ", message)


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


## Valida o manifesto. Retorna {} se faltar campo ou o tipo estiver errado.
## Formato: { version: int, url: String, sha256: String (64 hex), size: int, minLauncherVersion: int }.
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


func _manifest_url() -> String:
	return _http_base_url() + MANIFEST_PATH % _platform()


## Pasta de atualizações desta plataforma no servidor. O pacote muda com o formato de textura:
## celular (ETC2/ASTC) é diferente de PC. ATENÇÃO: mesmos nomes do tools/publish_update.sh.
func _platform() -> String:
	return "android" if OS.has_feature("android") else "desktop"


## Endereço HTTP do servidor, derivado do endereço WebSocket (ws:// → http://, wss:// → https://).
func _http_base_url() -> String:
	# get_setting_with_override aplica a variação por plataforma (server_url.android); get_setting não.
	var setting: Variant = ProjectSettings.get_setting_with_override(SERVER_URL_SETTING)
	var ws_url: String = (str(setting) if setting != null else "ws://localhost:2567").trim_suffix("/")
	if ws_url.begins_with("wss://"):
		return "https://" + ws_url.trim_prefix("wss://")
	return "http://" + ws_url.trim_prefix("ws://")


func _pack_path(version: int) -> String:
	return "%s/game-%d.pck" % [UPDATE_DIR, version]


func _part_path(version: int) -> String:
	return _pack_path(version) + ".part"


## Caminho do pacote instalado, se for da [param version] pedida e existir; senão "".
func _installed_pack_path(version: int) -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(INSTALLED_FILE) != OK:
		return ""
	var value: Variant = config.get_value("pack", "version", -1)
	if not value is int:
		return ""
	var installed: int = value
	var path: String = _pack_path(version)
	return path if installed == version and FileAccess.file_exists(path) else ""


func _save_installed(version: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("pack", "version", version)
	config.save(INSTALLED_FILE)


## Apaga pacotes de outras versões (e downloads incompletos) para não lotar o celular.
func _delete_old_packs(keep_version: int) -> void:
	var keep: String = "game-%d.pck" % keep_version
	for file: String in DirAccess.get_files_at(UPDATE_DIR):
		if file != keep and file.begins_with("game-"):
			DirAccess.remove_absolute("%s/%s" % [UPDATE_DIR, file])
