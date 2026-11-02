class_name Protocol
extends RefCounted
## Contrato de rede cliente ↔ servidor (constantes e leitura tipada do JSON).
##
## Transporte: WebSocket, um objeto JSON por mensagem de texto: { "type": String, "data": Dictionary }.
## Posições em metros, rotações em radianos.
##
## ATENÇÃO: espelho de mmo-server/src/net/protocol.ts. Mudou lá → mude aqui e atualize mmo-docs [INFRA-04].

## Versão do protocolo enviada no join. Precisa ser igual a PROTOCOL_VERSION do servidor.
const VERSION: int = 3

# --- Cliente → servidor ---
## Pede para entrar numa zona. data: { zone: String, version: int, guestToken: String ou null }.
const MSG_JOIN: String = "join"
## Intenção de movimento de UM tick (o servidor simula; o cliente não manda posição).
## data: { seq: int crescente, x, z: direção no mundo, comprimento até 1 }. Ver mmo-docs [INFRA-09].
const MSG_INPUT: String = "input"

# --- Servidor → cliente ---
## Entrada aceita. data: { playerId, guestToken, zone, tick: int, sim: { tickRate, moveSpeed, zoneHalfSize },
## players: Array[PlayerSnapshot] }.
const MSG_WELCOME: String = "welcome"
## Outro jogador entrou. data: { player: PlayerSnapshot }.
const MSG_PLAYER_JOINED: String = "player_joined"
## Um jogador saiu. data: { id: String }.
const MSG_PLAYER_LEFT: String = "player_left"
## Estado da zona a cada tick (20 Hz). data: { tick: int, ack: int (último input MEU aplicado),
## players: Array[PlayerSnapshot] }.
const MSG_SNAPSHOT: String = "snapshot"
## Pedido recusado ou mensagem inválida. data: { code: String, message: String }.
const MSG_ERROR: String = "error"

## Close code enviado pelo servidor ao recusar a entrada (precedido de uma mensagem "error").
const CLOSE_REJECTED: int = 4000
## Close code do servidor quando a conexão não respondeu ao heartbeat.
const CLOSE_TIMEOUT: int = 4001
## Close code quando a mesma conta entrou por outra conexão (outro aparelho/janela).
const CLOSE_REPLACED: int = 4002


## Monta o texto de uma mensagem para enviar.
## full_precision: os números vão com todos os dígitos, para o servidor simular com o MESMO
## double que o cliente usou na predição.
static func encode(type: String, data: Dictionary) -> String:
	return JSON.stringify({"type": type, "data": data}, "", true, true)


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


## Lê um inteiro de [param data] (JSON entrega float); retorna [param fallback] se não for número inteiro.
static func read_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = data.get(key)
	if value is int:
		var whole: int = value
		return whole
	if value is float:
		var number: float = value
		if number == floorf(number):
			return int(number)
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
