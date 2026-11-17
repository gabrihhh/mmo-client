class_name ChatMessage
extends RefCounted
## Uma mensagem do chat ([SOC-09]), como chega na mensagem "chat" do servidor.
## ATENÇÃO: espelha ChatData em mmo-server/src/net/protocol.ts.

## Canal: "zone" (Geral), "group", "guild", "private" ou "global".
var channel: String = ""
## Id e nome de quem falou, nível e tag da guilda ("" = sem guilda).
var from_id: String = ""
var from: String = ""
var level: int = 0
var guild_tag: String = ""
var text: String = ""
## Privado: nome de quem recebe ("" nos outros canais).
var to: String = ""


## Lê o payload de "chat".
static func from_dict(data: Dictionary) -> ChatMessage:
	var message: ChatMessage = ChatMessage.new()
	message.channel = Protocol.read_string(data, "channel")
	message.from_id = Protocol.read_string(data, "fromId")
	message.from = Protocol.read_string(data, "from")
	message.level = Protocol.read_int(data, "level")
	message.guild_tag = Protocol.read_string(data, "guildTag")
	message.text = Protocol.read_string(data, "text")
	message.to = Protocol.read_string(data, "to")
	return message
