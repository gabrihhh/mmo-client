class_name CharacterBodies
extends RefCounted
## Corpo do personagem → modelo 3D ([CharacterModel]). O corpo é escolhido uma vez na primeira entrada e vale para
## sempre ([INFRA-07], tela [CharacterSelect]); o servidor manda o de cada jogador no PlayerInfo.
## As cenas de jogador (local_player.tscn, remote_player.tscn) vêm com o masculino; [method swap] troca na entrada.

## Corpo → cena do modelo. ATENÇÃO: corpos = BODY_TYPES em mmo-server/src/net/protocol.ts.
const SCENES: Dictionary[String, String] = {
	Protocol.BODY_MALE: "res://assets/characters/male/male_character.tscn",
	Protocol.BODY_FEMALE: "res://assets/characters/female/female_character.tscn",
}


## Cena do modelo de [param body] (corpo desconhecido = masculino).
static func scene_path(body: String) -> String:
	return SCENES.get(body, SCENES[Protocol.BODY_MALE])


## Cria o modelo de [param body].
static func instantiate(body: String) -> CharacterModel:
	return (load(scene_path(body)) as PackedScene).instantiate() as CharacterModel


## Troca [param current] (já na árvore) pelo modelo de [param body], no mesmo lugar, com o mesmo nome e transform.
## Devolve o modelo que ficou (o próprio [param current] se já for o certo).
static func swap(current: CharacterModel, body: String) -> CharacterModel:
	if current == null or current.scene_file_path == scene_path(body):
		return current
	var parent: Node = current.get_parent()
	var replacement: CharacterModel = instantiate(body)
	replacement.name = current.name
	replacement.transform = current.transform
	var index: int = current.get_index()
	parent.remove_child(current)
	current.queue_free()
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	return replacement
