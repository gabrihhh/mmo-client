class_name GroupState
extends RefCounted
## O MEU grupo como o servidor manda na mensagem [constant Protocol.MSG_GROUP] (mmo-docs [SOC-03]): o líder e os
## membros na ordem em que entraram (o líder é o primeiro). Sem grupo, o [Network] guarda null.
## Só exibição/decisão de tela (quem é aliado, quem pode convidar): quem aplica as regras é o servidor.
##
## ATENÇÃO: espelho de GroupView em mmo-server/src/net/protocol.ts.

## Máximo de membros. ATENÇÃO: GROUP_MAX_MEMBERS em mmo-server/src/net/protocol.ts.
const MAX_MEMBERS: int = 5


## Um membro do grupo.
class Member:
	extends RefCounted
	## Id do jogador (playerId).
	var id: String = ""
	## Nome exibido (username como foi cadastrado).
	var name: String = ""
	## Nível ([JOGO-12]); o servidor manda a lista de novo quando alguém sobe.
	var level: int = 0

	## "[nível] nome", como em Jogadores Próximos.
	func title() -> String:
		return LevelText.title(level, name)


## Id do líder.
var leader_id: String = ""
## Membros (líder primeiro).
var members: Array[Member] = []


## Lê o `group` do payload (Dictionary) ou null se vier vazio/errado (= sem grupo).
static func from_dict(data: Dictionary) -> GroupState:
	var leader: String = Protocol.read_string(data, "leaderId")
	if leader.is_empty():
		return null
	var state: GroupState = GroupState.new()
	state.leader_id = leader
	for entry: Dictionary in Protocol.read_dict_array(data, "members"):
		var member: Member = Member.new()
		member.id = Protocol.read_string(entry, "id")
		member.name = Protocol.read_string(entry, "name")
		member.level = Protocol.read_int(entry, "level")
		if not member.id.is_empty():
			state.members.append(member)
	return state


## true se [param player_id] está no grupo.
func has(player_id: String) -> bool:
	for member: Member in members:
		if member.id == player_id:
			return true
	return false


## O membro [param player_id], ou null.
func find_member(player_id: String) -> Member:
	for candidate: Member in members:
		if candidate.id == player_id:
			return candidate
	return null


## true com o grupo cheio ([constant MAX_MEMBERS]).
func is_full() -> bool:
	return members.size() >= MAX_MEMBERS
