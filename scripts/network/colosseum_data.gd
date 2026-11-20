class_name ColosseumData
extends RefCounted
## Dados do Coliseu como o servidor manda (mmo-docs [JOGO-28]): a tela do Coliseu ([Info]), o placar da partida
## ([MatchState]) e o fim da partida ([Result]). Só leitura/exibição: quem decide fila, rounds e prêmio é o servidor.
##
## ATENÇÃO: espelho de ColosseumInfoData / ColosseumStateData / ColosseumResultData em mmo-server/src/net/protocol.ts.

## Modos. ATENÇÃO: COLOSSEUM_MODES em mmo-server/src/arena/build.ts.
const MODES: Array[String] = ["1x1", "2x2", "3x3"]
## Conjuntos escolhíveis na build (um por slot). ATENÇÃO: ARENA_SETS em mmo-server/src/arena/build.ts.
const SETS: Array[String] = ["Mago", "Cavaleiro", "Atirador", "Assassino", "Curandeiro"]
## Conjunto cuja arma (mão) faz o jogador ser o healer do time (o 1x1 não aceita).
const HEALER_SET: String = "Curandeiro"
## Slots da build, na ordem da tela.
const SLOTS: Array[String] = ["hand", "head", "chest", "feet"]
## Nome de cada slot na tela.
const SLOT_NAMES: Dictionary[String, String] = {"hand": "Mão", "head": "Cabeça", "chest": "Peito", "feet": "Pés"}
## Fases da partida.
const PHASE_PREP: String = "prep"
const PHASE_ROUND: String = "round"
const PHASE_PAUSE: String = "pause"
const PHASE_OVER: String = "over"


## Tela do Coliseu ([constant Protocol.MSG_COLOSSEUM_INFO]).
class Info:
	extends RefCounted
	## Ranking em cada modo (modo → pontos).
	var rating: Dictionary[String, int] = {}
	## Pontos de Coliseu juntados.
	var points: int = 0
	## Segundos até poder entrar na fila de novo (0 = livre).
	var ban_seconds: int = 0
	## Modo da fila em que está esperando; "" = fora da fila.
	var queued: String = ""
	## Quantos esperam em cada fila (modo → n).
	var waiting: Dictionary[String, int] = {}
	## Partidas premiadas hoje e o teto do dia.
	var rewards_today: int = 0
	var rewards_limit: int = 10

	static func from_dict(data: Dictionary) -> Info:
		var info: Info = Info.new()
		var rating: Dictionary = Protocol.read_dict(data, "rating")
		var waiting: Dictionary = Protocol.read_dict(data, "waiting")
		for mode: String in MODES:
			info.rating[mode] = Protocol.read_int(rating, mode)
			info.waiting[mode] = Protocol.read_int(waiting, mode)
		info.points = Protocol.read_int(data, "points")
		info.ban_seconds = Protocol.read_int(data, "banSeconds")
		info.queued = Protocol.read_string(data, "queued")
		info.rewards_today = Protocol.read_int(data, "rewardsToday")
		info.rewards_limit = Protocol.read_int(data, "rewardsLimit", 10)
		return info


## Um jogador no placar da partida.
class Member:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	## Build: slot → conjunto.
	var build: Dictionary[String, String] = {}
	## Abandonou (fica morto até o fim).
	var abandoned: bool = false


## Uma das minhas 4 peças de arena (tela das 20 escolhas).
class Piece:
	extends RefCounted
	var slot: String = ""
	## Conjunto escolhido na build.
	var set_name: String = ""
	var item_id: String = ""
	## Pontos que a peça já tem (atributo → pontos).
	var attrs: Dictionary[String, int] = {}
	## Atributos que a peça aceita (novo +1, repetido +2).
	var allowed: Array[String] = []

	## Pontos que uma escolha de [param attribute] dá nesta peça (+1 novo, +2 repetido; espelha o servidor).
	func gain(attribute: String) -> int:
		return 2 if attrs.get(attribute, 0) > 0 else 1

	static func from_dict(data: Dictionary) -> Piece:
		var piece: Piece = Piece.new()
		piece.slot = Protocol.read_string(data, "slot")
		piece.set_name = Protocol.read_string(data, "set")
		piece.item_id = Protocol.read_string(data, "itemId")
		var attrs: Dictionary = Protocol.read_dict(data, "attrs")
		for key: Variant in attrs.keys():
			if key is String:
				piece.attrs[key as String] = Protocol.read_int(attrs, key as String)
		var allowed: Variant = data.get("allowed")
		if allowed is Array:
			for id: Variant in allowed as Array:
				if id is String:
					piece.allowed.append(id as String)
		return piece


## Placar da partida ([constant Protocol.MSG_COLOSSEUM_STATE]).
class MatchState:
	extends RefCounted
	var mode: String = ""
	## [constant PHASE_PREP] / [constant PHASE_ROUND] / [constant PHASE_PAUSE] / [constant PHASE_OVER].
	var phase: String = ""
	## Round atual (0 na preparação).
	var round: int = 0
	## Pontos do time 0 e do time 1.
	var score: Array[int] = [0, 0]
	## Segundos até a fase acabar (no instante em que chegou; [member received_ms]).
	var seconds_left: int = 0
	## Minhas escolhas restantes na preparação.
	var choices_left: int = 0
	## Meu time (0 ou 1).
	var team: int = 0
	## Os dois times.
	var teams: Array[Array] = [[], []]
	## Quando chegou (Time.get_ticks_msec), para contar o tempo na tela.
	var received_ms: int = 0
	## Minhas 4 peças de arena, na ordem mão, cabeça, peito, pés.
	var pieces: Array[Piece] = []

	## Barreira do meio e travas ligadas (preparação, pausa, fim): a predição prende no lado do time.
	func barrier_active() -> bool:
		return phase != PHASE_ROUND

	## Segundos que faltam agora (conta o tempo desde que chegou).
	func seconds_now() -> int:
		return maxi(0, seconds_left - int((Time.get_ticks_msec() - received_ms) / 1000.0))

	## Time de [param player_id] (-1 = não está na partida).
	func team_of(player_id: String) -> int:
		for index: int in range(2):
			for member: Member in teams[index]:
				if member.id == player_id:
					return index
		return -1

	## Membros do time [param index].
	func members(index: int) -> Array[Member]:
		var result: Array[Member] = []
		for member: Member in teams[index]:
			result.append(member)
		return result

	static func from_dict(data: Dictionary) -> MatchState:
		var state: MatchState = MatchState.new()
		state.mode = Protocol.read_string(data, "mode")
		state.phase = Protocol.read_string(data, "phase")
		state.round = Protocol.read_int(data, "round")
		var score: Variant = data.get("score")
		if score is Array and (score as Array).size() == 2:
			var pair: Array = score as Array
			state.score = [int(pair[0]) if pair[0] is float or pair[0] is int else 0, int(pair[1]) if pair[1] is float or pair[1] is int else 0]
		state.seconds_left = Protocol.read_int(data, "secondsLeft")
		state.choices_left = Protocol.read_int(data, "choicesLeft")
		state.team = Protocol.read_int(data, "team")
		state.received_ms = Time.get_ticks_msec()
		for piece_data: Dictionary in Protocol.read_dict_array(data, "pieces"):
			state.pieces.append(Piece.from_dict(piece_data))
		var teams: Variant = data.get("teams")
		if teams is Array:
			var list: Array = teams as Array
			for index: int in range(mini(2, list.size())):
				if not (list[index] is Array):
					continue
				for entry: Variant in list[index] as Array:
					if entry is Dictionary:
						state.teams[index].append(_member_from(entry as Dictionary))
		return state

	static func _member_from(data: Dictionary) -> Member:
		var member: Member = Member.new()
		member.id = Protocol.read_string(data, "id")
		member.name = Protocol.read_string(data, "name")
		var build: Dictionary = Protocol.read_dict(data, "build")
		for slot: String in SLOTS:
			member.build[slot] = Protocol.read_string(build, slot)
		var abandoned: Variant = data.get("abandoned")
		member.abandoned = abandoned is bool and abandoned == true
		return member


## Fim da partida para mim ([constant Protocol.MSG_COLOSSEUM_RESULT]).
class Result:
	extends RefCounted
	var mode: String = ""
	## "win" / "loss" / "draw" / "abandon".
	var outcome: String = ""
	## Anulada (abandono antes do fim do round 1): sem prêmio nem ranking.
	var annulled: bool = false
	var score: Array[int] = [0, 0]
	var gold: int = 0
	var xp: float = 0.0
	## Pontos de Coliseu ganhos.
	var points: int = 0
	var rating_delta: int = 0
	var rating: int = 0
	## false = passou das partidas premiadas do dia (só o ranking contou).
	var rewarded: bool = false
	## Meu nível real depois do prêmio.
	var level: int = 0

	static func from_dict(data: Dictionary) -> Result:
		var result: Result = Result.new()
		result.mode = Protocol.read_string(data, "mode")
		result.outcome = Protocol.read_string(data, "outcome")
		var annulled: Variant = data.get("annulled")
		result.annulled = annulled is bool and annulled == true
		var score: Variant = data.get("score")
		if score is Array and (score as Array).size() == 2:
			var pair: Array = score as Array
			result.score = [int(pair[0]) if pair[0] is float or pair[0] is int else 0, int(pair[1]) if pair[1] is float or pair[1] is int else 0]
		result.gold = Protocol.read_int(data, "gold")
		result.xp = Protocol.read_float(data, "xp")
		result.points = Protocol.read_int(data, "points")
		result.rating_delta = Protocol.read_int(data, "ratingDelta")
		result.rating = Protocol.read_int(data, "rating")
		var rewarded: Variant = data.get("rewarded")
		result.rewarded = rewarded is bool and rewarded == true
		result.level = Protocol.read_int(data, "level")
		return result
