class_name Protocol
extends RefCounted
## Contrato de rede cliente ↔ servidor (constantes e leitura tipada do JSON).
##
## Transporte: WebSocket, um objeto JSON por mensagem de texto: { "type": String, "data": Dictionary }.
## Posições em metros, rotações em radianos.
##
## ATENÇÃO: espelho de mmo-server/src/net/protocol.ts. Mudou lá → mude aqui e atualize mmo-docs [INFRA-04].

## Versão do protocolo enviada no join. Precisa ser igual a PROTOCOL_VERSION do servidor.
const VERSION: int = 1

# --- Cliente → servidor ---
## Pede para entrar numa zona. data: { zone: String, version: int }.
const MSG_JOIN: String = "join"
## Posição/rotação do jogador local. data: { x, y, z, rotY }.
const MSG_MOVE: String = "move"

# --- Servidor → cliente ---
## Entrada aceita. data: { sessionId: String, zone: String, players: Array[PlayerSnapshot] }.
const MSG_WELCOME: String = "welcome"
## Outro jogador entrou. data: { player: PlayerSnapshot }.
const MSG_PLAYER_JOINED: String = "player_joined"
## Um jogador saiu. data: { id: String }.
const MSG_PLAYER_LEFT: String = "player_left"
## Lote periódico (20 Hz) com quem se moveu. data: { players: Array[PlayerSnapshot] }.
const MSG_POSITIONS: String = "positions"
## Pedido recusado ou mensagem inválida. data: { code: String, message: String }.
const MSG_ERROR: String = "error"

## Close code enviado pelo servidor ao recusar a entrada (precedido de uma mensagem "error").
const CLOSE_REJECTED: int = 4000
## Close code do servidor quando a conexão não respondeu ao heartbeat.
const CLOSE_TIMEOUT: int = 4001


## Monta o texto de uma mensagem para enviar.
static func encode(type: String, data: Dictionary) -> String:
	return JSON.stringify({"type": type, "data": data})


## Decodifica uma mensagem recebida. Retorna { "type": String, "data": Dictionary },
## ou um Dictionary vazio se o texto não estiver no formato do protocolo.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var message: Dictionary = parsed
	var type: Variant = message.get("type")
	var data: Variant = message.get("data")
	if not type is String or not data is Dictionary:
		return {}
	return message


## Lê um número de [param data]; retorna [param fallback] se faltar ou não for número.
## (JSON no Godot entrega todo número como float.)
static func read_float(data: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value: Variant = data.get(key)
	if value is float or value is int:
		var number: float = value
		return number
	return fallback


## Lê uma String de [param data]; retorna "" se faltar ou tiver outro tipo.
static func read_string(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key)
	if value is String:
		var text: String = value
		return text
	return ""


## Lê um Dictionary de [param data]; retorna {} se faltar ou tiver outro tipo.
static func read_dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	if value is Dictionary:
		var dict: Dictionary = value
		return dict
	return {}


## Lê uma lista de objetos de [param data], descartando o que não for Dictionary.
static func read_dict_array(data: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = data.get(key)
	if not value is Array:
		return result
	var items: Array = value
	for item: Variant in items:
		if item is Dictionary:
			var dict: Dictionary = item
			result.append(dict)
	return result


## true se [param data] é um PlayerSnapshot válido: { id: String, x, y, z, rotY: number }.
static func is_player_snapshot(data: Dictionary) -> bool:
	if read_string(data, "id").is_empty():
		return false
	for key: String in ["x", "y", "z", "rotY"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int):
			return false
	return true
