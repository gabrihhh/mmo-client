class_name Protocol
extends RefCounted
## Contrato de rede cliente ↔ servidor (constantes e leitura tipada do JSON).
##
## Transporte: WebSocket, um objeto JSON por mensagem de texto: { "type": String, "data": Dictionary }.
## Posições em metros, rotações em radianos.
## Fluxo: conectar → register/login/resume → auth_ok → join → welcome → input/snapshot.
##
## ATENÇÃO: espelho de mmo-server/src/net/protocol.ts (e das regras de conta em
## mmo-server/src/accounts/credentials.ts). Mudou lá → mude aqui e atualize mmo-docs [INFRA-04], [INFRA-07].

## Versão do protocolo enviada ao autenticar. Precisa ser igual a PROTOCOL_VERSION do servidor.
const VERSION: int = 8

# --- Cliente → servidor ---
## Cria conta. data: { version, username, email, password }.
const MSG_REGISTER: String = "register"
## Entra com username OU e-mail + senha. data: { version, login, password }.
const MSG_LOGIN: String = "login"
## Entra com o token de sessão salvo no aparelho. data: { version, sessionToken }.
const MSG_RESUME: String = "resume"
## Encerra a sessão deste aparelho e fecha a conexão. data: {}.
const MSG_LOGOUT: String = "logout"
## Pede para entrar numa zona (depois de autenticar). data: { zone: String }.
const MSG_JOIN: String = "join"
## Intenção de movimento de UM tick (o servidor simula; o cliente não manda posição).
## data: { seq: int crescente, x, z: direção no mundo, comprimento até 1 }. Ver mmo-docs [INFRA-09].
const MSG_INPUT: String = "input"
## Veste um item da mochila (o do slot volta para a mochila). data: { uid }. Ver mmo-docs [JOGO-04].
const MSG_EQUIP: String = "equip"
## Tira o item do slot para a mochila. data: { slot: "hand" | "head" | "chest" | "feet" }.
const MSG_UNEQUIP: String = "unequip"
## Fixa (ou limpa, com null) o alvo do ataque simples; o servidor bate sozinho quando em alcance.
## data: { targetId: String ou null }. Ver mmo-docs [JOGO-05].
const MSG_ATTACK: String = "attack"
## Lança uma habilidade vestida. data: { abilityId, targetId?, x?, z?, seq? } (x/z = direção ou ponto, conforme a
## mira; seq = só Investida/Disparada, na MESMA sequência dos inputs). Ver mmo-docs [JOGO-06], [JOGO-07].
const MSG_CAST: String = "cast"

# --- Servidor → cliente ---
## Autenticação aceita. data: { playerId, username (como foi cadastrado), sessionToken }.
const MSG_AUTH_OK: String = "auth_ok"
## Entrada na zona aceita. data: { playerId, zone, tick: int, sim: { tickRate, moveSpeed, zoneHalfSize },
## players: Array[PlayerInfo] } (PlayerInfo = PlayerSnapshot + name).
const MSG_WELCOME: String = "welcome"
## Outro jogador entrou. data: { player: PlayerInfo }.
const MSG_PLAYER_JOINED: String = "player_joined"
## Um jogador saiu. data: { id: String }.
const MSG_PLAYER_LEFT: String = "player_left"
## Estado da zona a cada tick (20 Hz). data: { tick: int, ack: int (último input MEU aplicado),
## players: Array[PlayerSnapshot] (com shield), npcs: Array[NpcSnapshot], events: Array[CombatEvent],
## me: { mana, maxMana, respawnIn, target } }. PlayerSnapshot = { id, x, y, z, rotY, hp, maxHp, dead }.
## CombatEvent = { type: "damage", source, target, amount, absorbed, ability } | { type: "heal", source, target,
## amount, ability } | { type: "impact", source, ability, x, z, radius } | { type: "cast_start", source, ability,
## target, duration } | { type: "miss", source, target, ability } | { type: "death", id, killer } | { type: "respawn", id }.
## me.casting = { ability, target, remaining } ou null (golpe em andamento).
const MSG_SNAPSHOT: String = "snapshot"
## Inventário completo. data: { equipped: { hand, head, chest, feet: ItemView ou null }, bag: Array[ItemView],
## bagCapacity, unarmedAttack: AbilityView }. ItemView = { uid, itemId, name, slot, basicAttack, abilities }.
const MSG_INVENTORY: String = "inventory"
## Pedido recusado ou mensagem inválida. data: { code: String, message: String }.
const MSG_ERROR: String = "error"

## Close code enviado pelo servidor ao recusar a entrada (precedido de uma mensagem "error").
const CLOSE_REJECTED: int = 4000
## Close code do servidor quando a conexão não respondeu ao heartbeat.
const CLOSE_TIMEOUT: int = 4001
## Close code quando a mesma conta entrou por outra conexão (outro aparelho/janela).
const CLOSE_REPLACED: int = 4002

## Erro: token de sessão não vale mais (o cliente apaga o token e mostra o formulário).
const ERR_INVALID_SESSION: String = "invalid_session"

# --- Regras de conta (só para avisar na hora; quem decide é o servidor) ---
## Username: 3 a 16 caracteres, letras sem acento, números e _. Único sem diferenciar maiúsculas,
## mas exibido exatamente como foi digitado.
const USERNAME_MIN_LENGTH: int = 3
const USERNAME_MAX_LENGTH: int = 16
## Senha: 8 a 72 caracteres.
const PASSWORD_MIN_LENGTH: int = 8
const PASSWORD_MAX_LENGTH: int = 72


## Mensagem de erro para o username, ou "" se estiver válido.
static func username_problem(username: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^[A-Za-z0-9_]+$")
	if username.length() < USERNAME_MIN_LENGTH or username.length() > USERNAME_MAX_LENGTH or regex.search(username) == null:
		return "Username deve ter de %d a %d caracteres: letras, números ou _." % [USERNAME_MIN_LENGTH, USERNAME_MAX_LENGTH]
	return ""


## Mensagem de erro para o e-mail, ou "" se estiver válido.
static func email_problem(email: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	return "" if regex.search(email) != null else "E-mail inválido."


## Mensagem de erro para a senha, ou "" se estiver válida.
static func password_problem(password: String) -> String:
	if password.length() < PASSWORD_MIN_LENGTH or password.length() > PASSWORD_MAX_LENGTH:
		return "A senha deve ter de %d a %d caracteres." % [PASSWORD_MIN_LENGTH, PASSWORD_MAX_LENGTH]
	return ""


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
