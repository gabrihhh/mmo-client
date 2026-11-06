class_name NetworkConfig
extends RefCounted
## Configurações de rede do cliente.
##
## O endereço do servidor fica em Project Settings > mmo/network/server_url,
## assim dá para trocar sem mexer em código (ex.: IP do PC ao testar no celular).

## Chave da configuração no project.godot.
const SERVER_URL_SETTING: String = "mmo/network/server_url"

## Valor usado se a configuração não existir.
const DEFAULT_SERVER_URL: String = "ws://localhost:2567"

## Id da zona enviado no join. ATENÇÃO: precisa existir em mmo-server/src/zones/zones.ts.
const ZONE_ID: String = "zone_1"



## Endereço achado na rede local pelo atualizador ([INFRA-10]), só em memória; vazio = não procurou.
## ATENÇÃO: mesma chave de DISCOVERED_URL_SETTING em scripts/boot/updater.gd.
const DISCOVERED_URL_SETTING: String = "mmo/network/discovered_url"


## Retorna a URL WebSocket do servidor do jogo: a achada na rede local, se houver; senão a configurada.
static func server_url() -> String:
	if ProjectSettings.has_setting(DISCOVERED_URL_SETTING):
		var discovered: String = str(ProjectSettings.get_setting(DISCOVERED_URL_SETTING))
		if not discovered.is_empty():
			return discovered
	# get_setting_with_override aplica a variação por plataforma (ex.: server_url.android, o IP do PC
	# na rede local). get_setting ignoraria e devolveria o localhost.
	var setting: Variant = ProjectSettings.get_setting_with_override(SERVER_URL_SETTING)
	return str(setting) if setting != null else DEFAULT_SERVER_URL
