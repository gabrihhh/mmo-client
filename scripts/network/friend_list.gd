class_name FriendList
extends RefCounted
## Minha lista de amigos como o servidor manda na mensagem [constant Protocol.MSG_FRIENDS] (mmo-docs [SOC-04]):
## cada amigo com nome e se está online (conectado no servidor, qualquer zona; fake de teste = sempre online), online
## primeiro. Só exibição/decisão de tela (mostrar "Solicitar amizade" ou não): quem guarda a amizade é o servidor.
##
## ATENÇÃO: espelho de FriendView em mmo-server/src/net/protocol.ts.


## Um amigo.
class Friend:
	extends RefCounted
	## Id do jogador (playerId).
	var id: String = ""
	## Nome exibido (username como foi cadastrado).
	var name: String = ""
	## Conectado no servidor agora.
	var online: bool = false


## Amigos na ordem do servidor (online primeiro, depois por nome).
var friends: Array[Friend] = []


## Lê o payload de [constant Protocol.MSG_FRIENDS] (entradas sem id/nome são descartadas).
static func from_dict(data: Dictionary) -> FriendList:
	var list: FriendList = FriendList.new()
	for entry: Dictionary in Protocol.read_dict_array(data, "friends"):
		var friend: Friend = Friend.new()
		friend.id = Protocol.read_string(entry, "id")
		friend.name = Protocol.read_string(entry, "name")
		var online: Variant = entry.get("online")
		friend.online = online is bool and online == true
		if not friend.id.is_empty() and not friend.name.is_empty():
			list.friends.append(friend)
	return list


## true se [param id] é meu amigo.
func has(id: String) -> bool:
	return find(id) != null


## O amigo [param id], ou null.
func find(id: String) -> Friend:
	for friend: Friend in friends:
		if friend.id == id:
			return friend
	return null
