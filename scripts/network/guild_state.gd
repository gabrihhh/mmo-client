class_name GuildState
extends RefCounted
## A MINHA guilda como o servidor manda na mensagem [constant Protocol.MSG_GUILD] (mmo-docs [SOC-06]): nome, tag e
## membros (líder, oficiais e membros, cada cargo do mais antigo ao mais novo). Sem guilda, o [Network] guarda null.
## Só exibição/decisão de tela (quem pode convidar/expulsar): quem aplica as regras é o servidor.
##
## ATENÇÃO: espelho de GuildView em mmo-server/src/net/protocol.ts.

## Cargos. ATENÇÃO: GuildRole em mmo-server/src/net/protocol.ts.
const ROLE_LEADER: String = "leader"
const ROLE_OFFICER: String = "officer"
const ROLE_MEMBER: String = "member"
## Máximo de membros. ATENÇÃO: GUILD_MAX_MEMBERS em mmo-server/src/net/protocol.ts.
const MAX_MEMBERS: int = 50
## Nome de cada cargo na tela.
const ROLE_LABELS: Dictionary[String, String] = {ROLE_LEADER: "Líder", ROLE_OFFICER: "Oficial", ROLE_MEMBER: "Membro"}


## Um membro da guilda.
class Member:
	extends RefCounted
	## Id do jogador (playerId).
	var id: String = ""
	## Nome exibido (username como foi cadastrado).
	var name: String = ""
	## [constant GuildState.ROLE_LEADER] / ROLE_OFFICER / ROLE_MEMBER.
	var role: String = ""
	## Está no servidor agora.
	var online: bool = false
	## Nível de quem está numa zona; -1 = offline/desconhecido.
	var level: int = -1


## Id da guilda.
var id: String = ""
## Nome da guilda.
var name: String = ""
## Tag de 3 letras/números (maiúsculas).
var tag: String = ""
## Membros (na ordem do servidor).
var members: Array[Member] = []


## Lê o `guild` do payload (Dictionary) ou null se vier vazio/errado (= sem guilda).
static func from_dict(data: Dictionary) -> GuildState:
	var guild_id: String = Protocol.read_string(data, "id")
	if guild_id.is_empty():
		return null
	var state: GuildState = GuildState.new()
	state.id = guild_id
	state.name = Protocol.read_string(data, "name")
	state.tag = Protocol.read_string(data, "tag")
	for entry: Dictionary in Protocol.read_dict_array(data, "members"):
		var member: Member = Member.new()
		member.id = Protocol.read_string(entry, "id")
		member.name = Protocol.read_string(entry, "name")
		member.role = Protocol.read_string(entry, "role")
		var online_value: Variant = entry.get("online")
		member.online = online_value is bool and online_value == true
		member.level = Protocol.read_int(entry, "level", -1)
		if not member.id.is_empty():
			state.members.append(member)
	return state


## O membro [param player_id], ou null.
func find_member(player_id: String) -> Member:
	for member: Member in members:
		if member.id == player_id:
			return member
	return null


## Cargo de [param player_id] ("" = não é da guilda).
func role_of(player_id: String) -> String:
	var member: Member = find_member(player_id)
	return member.role if member != null else ""


## true se [param player_id] pode convidar (líder ou oficial).
func can_invite(player_id: String) -> bool:
	var role: String = role_of(player_id)
	return role == ROLE_LEADER or role == ROLE_OFFICER


## true se [param by_id] pode expulsar [param target_id]: líder expulsa qualquer outro; oficial, só membro comum.
func can_kick(by_id: String, target_id: String) -> bool:
	if by_id == target_id:
		return false
	var by_role: String = role_of(by_id)
	var target_role: String = role_of(target_id)
	if target_role.is_empty():
		return false
	return by_role == ROLE_LEADER or (by_role == ROLE_OFFICER and target_role == ROLE_MEMBER)


## "[TAG] Nome".
func title() -> String:
	return "[%s] %s" % [tag, name]
