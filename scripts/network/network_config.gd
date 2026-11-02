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

## Nome da room de zona no servidor (mmo-server/src/app.config.ts).
const ZONE_ROOM_NAME: String = "zone"

## Quantas vezes por segundo o jogador local envia a própria posição.
const MOVE_SEND_RATE_HZ: float = 15.0


## Retorna a URL WebSocket do servidor Colyseus.
static func server_url() -> String:
	return str(ProjectSettings.get_setting(SERVER_URL_SETTING, DEFAULT_SERVER_URL))
