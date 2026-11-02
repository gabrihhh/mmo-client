class_name AccountStorage
extends RefCounted
## Guarda no aparelho o token da conta de convidado. Ver mmo-docs [INFRA-07].
##
## O token é o "login" do jogador: quem tiver o token entra na conta. Fica em user://
## (pasta privada do app no Android/iOS). Apagar o app ou os dados = conta nova.
##
## Dev: várias janelas no mesmo PC dividiriam o mesmo arquivo (e a mesma conta, que derruba a
## outra janela). Rode cada uma com um perfil: `godot --path . -- --profile=2`.

const _SECTION: String = "guest"
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


## Token salvo, ou "" se ainda não existe (primeiro acesso).
static func load_guest_token() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_path()) != OK:
		return ""
	var value: Variant = config.get_value(_SECTION, _KEY, "")
	if value is String:
		var token: String = value
		return token
	return ""


## Salva o token recebido do servidor no welcome.
static func save_guest_token(token: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(_SECTION, _KEY, token)
	var error: Error = config.save(_path())
	if error != OK:
		push_warning("AccountStorage: não foi possível salvar o token (%s)" % error_string(error))
