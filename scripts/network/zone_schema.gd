class_name ZoneSchema
extends RefCounted
## Espelho em GDScript do estado da ZoneRoom do servidor.
##
## ATENÇÃO: precisa bater campo a campo com mmo-server/src/rooms/schema/ZoneState.ts.
## Mudou lá → mude aqui e atualize mmo-docs [INFRA-04].


## Um jogador na zona. Posição em metros, rot_y em radianos.
class PlayerState extends Colyseus.Schema:
	static func definition() -> Array:
		return [
			Colyseus.Schema.Field.new("x", Colyseus.Schema.NUMBER),
			Colyseus.Schema.Field.new("y", Colyseus.Schema.NUMBER),
			Colyseus.Schema.Field.new("z", Colyseus.Schema.NUMBER),
			Colyseus.Schema.Field.new("rotY", Colyseus.Schema.NUMBER),
		]

	## Posição atual (sempre atualizada pelo SDK a cada patch do servidor).
	func get_world_position() -> Vector3:
		return Vector3(_number(&"x"), _number(&"y"), _number(&"z"))

	## Rotação atual no eixo Y, em radianos.
	func get_rot_y() -> float:
		return _number(&"rotY")

	## Lê um campo numérico do schema (os campos são dinâmicos, via _get).
	func _number(field: StringName) -> float:
		var value: Variant = get(field)
		if not (value is float or value is int):
			return 0.0
		# Atribuir o Variant já checado a uma var tipada converte int -> float sem warning de cast.
		var number: float = value
		return number


## Estado raiz da room: jogadores indexados pelo session id.
class State extends Colyseus.Schema:
	static func definition() -> Array:
		return [
			Colyseus.Schema.Field.new("players", Colyseus.Schema.MAP, PlayerState),
		]
