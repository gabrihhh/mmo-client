class_name AccountStorage
extends RefCounted
## Guarda no aparelho o token de SESSÃO da conta (para entrar direto, sem digitar a senha de novo).
## Ver mmo-docs [INFRA-07].
##
## O token é recebido no auth_ok depois do cadastro/login. Fica em user:// (pasta privada do app no
## Android/iOS). A senha NUNCA é salva. "Sair" apaga o token (e o servidor o invalida).
##
## Dev: várias janelas no mesmo PC dividiriam o mesmo arquivo (e a mesma conta, que derruba a
## outra janela). Rode cada uma com um perfil: `godot --path . -- --profile=2`.

const _SECTION: String = "session"
const _KEY: String = "token"
## Prefixo do argumento de linha de comando que escolhe o perfil (depois do `--`).
const _PROFILE_ARG: String = "--profile="


## Arquivo do perfil atual: user://account.cfg, ou user://account_<perfil>.cfg com --profile.
static func _path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(_PROFILE_ARG):
			var profile: String = arg.trim_prefix(_PROFILE_ARG).validate_filename()
			if not profile.is_empty():
				return "user://account_%s.cfg" % profile
	return "user://account.cfg"


## Token de sessão salvo, ou "" se não houver (nunca entrou, ou saiu).
static func load_session_token() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_path()) != OK:
		return ""
	var value: Variant = config.get_value(_SECTION, _KEY, "")
	if value is String:
		var token: String = value
		return token
	return ""


## Salva o token recebido no auth_ok.
static func save_session_token(token: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(_SECTION, _KEY, token)
	var error: Error = config.save(_path())
	if error != OK:
		push_warning("AccountStorage: não foi possível salvar a sessão (%s)" % error_string(error))


## Credenciais da conta de convidado deste aparelho/perfil: { "username", "password" } ou {} se ainda
## não existe. Conveniência de TESTE ([CLI-05]): é uma conta normal com dados gerados pelo cliente.
static func load_guest_credentials() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_guest_path()) != OK:
		return {}
	var username: Variant = config.get_value("guest", "username", "")
	var password: Variant = config.get_value("guest", "password", "")
	if not (username is String and password is String):
		return {}
	var name_text: String = username
	var password_text: String = password
	if name_text.is_empty() or password_text.is_empty():
		return {}
	return {"username": name_text, "password": password_text}


## Guarda as credenciais do convidado (só depois que o servidor aceitou o cadastro).
static func save_guest_credentials(username: String, password: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("guest", "username", username)
	config.set_value("guest", "password", password)
	config.save(_guest_path())


## Arquivo do convidado (separado da sessão: "Sair" apaga a sessão, mas o convidado continua o mesmo).
static func _guest_path() -> String:
	return _path().replace("account", "guest")


## Apaga o token (logout ou sessão recusada pelo servidor).
static func clear_session_token() -> void:
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())
