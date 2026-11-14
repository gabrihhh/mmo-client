class_name PackInfo
extends RefCounted
## Qual pacote do jogo (.pck) está rodando: plataforma e versão. Vai na autenticação ([code]client[/code], v16) para o
## servidor mandar atualizar quem está numa versão velha. Ver mmo-docs [INFRA-08].
##
## A versão é a gravada em [constant INSTALLED_FILE] por quem instalou o pacote (o atualizador do APK, ou o
## [LiveUpdater] com o jogo aberto): os dois só carregam o pacote cuja versão está gravada lá.
## Dev = rodando o projeto do código-fonte (existe [code]res://project.godot[/code]; num pacote exportado ele vira
## [code]project.binary[/code]): manda [constant DEV_PACK] e o servidor nunca manda atualizar.
##
## ATENÇÃO: pasta, arquivo e nomes de plataforma iguais aos de scripts/boot/updater.gd (que fica no APK) e de
## tools/publish_update.sh; o servidor lê em mmo-server/src/net/protocol.ts (ClientBuild).

## Pasta dos pacotes baixados e o arquivo que diz qual versão está instalada.
const UPDATE_DIR: String = "user://update"
const INSTALLED_FILE: String = "user://update/installed.cfg"
## Versão mandada no dev (sem pacote): "nunca atualizar".
const DEV_PACK: int = 0


## Plataforma do pacote (pasta de updates no servidor): o pacote muda com o formato de textura.
static func platform() -> String:
	return "android" if OS.has_feature("android") else "desktop"


## true rodando do código-fonte (editor/terminal com --path), sem pacote exportado.
static func is_dev() -> bool:
	return FileAccess.file_exists("res://project.godot")


## Versão gravada em [constant INSTALLED_FILE]; 0 se não houver.
static func installed_version() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(INSTALLED_FILE) != OK:
		return 0
	var value: Variant = config.get_value("pack", "version", 0)
	return value if value is int else 0


## Versão do pacote em uso para mandar ao servidor: [constant DEV_PACK] no dev.
static func current_pack() -> int:
	return DEV_PACK if is_dev() else installed_version()


## O [code]client[/code] das mensagens de autenticação: { platform, pack }.
static func client_build() -> Dictionary:
	return {"platform": platform(), "pack": current_pack()}
