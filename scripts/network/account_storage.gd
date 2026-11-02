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


## Apaga o token (logout ou sessão recusada pelo servidor).
static func clear_session_token() -> void:
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())
