class_name PlayerState
extends RefCounted
## Estado de um jogador na zona, como recebido do servidor (PlayerSnapshot em [Protocol]).
##
## O [Network] mantém um objeto por jogador e o atualiza a cada mensagem "positions";
## quem guarda a referência (ex.: [RemotePlayer]) sempre lê o valor mais recente.

## Id público do jogador (estável entre sessões; conta de convidado).
var id: String = ""
## Última posição recebida, em metros.
var position: Vector3 = Vector3.ZERO
## Última rotação no eixo Y recebida, em radianos.
var rot_y: float = 0.0


## Cria a partir de um PlayerSnapshot. Retorna null se o formato for inválido.
static func from_snapshot(data: Dictionary) -> PlayerState:
	if not Protocol.is_player_snapshot(data):
		return null
	var state: PlayerState = PlayerState.new()
	state.id = Protocol.read_string(data, "id")
	state.apply_snapshot(data)
	return state


## Atualiza posição e rotação a partir de um PlayerSnapshot (já validado).
func apply_snapshot(data: Dictionary) -> void:
	position = Vector3(
		Protocol.read_float(data, "x"),
		Protocol.read_float(data, "y"),
		Protocol.read_float(data, "z"),
	)
	rot_y = Protocol.read_float(data, "rotY")
