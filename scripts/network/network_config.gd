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

## Quantas vezes por segundo o jogador local envia a própria posição.
const MOVE_SEND_RATE_HZ: float = 15.0


## Retorna a URL WebSocket do servidor do jogo.
static func server_url() -> String:
	# get_setting_with_override aplica a variação por plataforma (ex.: server_url.android, o IP do PC
	# na rede local). get_setting ignoraria e devolveria o localhost.
	var setting: Variant = ProjectSettings.get_setting_with_override(SERVER_URL_SETTING)
	return str(setting) if setting != null else DEFAULT_SERVER_URL
