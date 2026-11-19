class_name DeathReport
extends RefCounted
## O que veio do servidor quando você morreu ([JOGO-21]): quem matou, moedas e XP perdidas, as peças vestidas (a
## roleta), qual foi sorteada e se quebrou (sumiu), e em quantos segundos renasce sozinho.
## ATENÇÃO: DeathReportData em mmo-server/src/net/protocol.ts.

## Uma peça vestida na hora da morte.
class Piece:
	extends RefCounted
	var slot: String = ""
	var item: InventoryState.Item = null

var killer: String = ""
var gold_lost: int = 0
var xp_lost: float = 0.0
## Níveis perdidos (morte para jogador, [JOGO-22]).
var levels_lost: int = 0
## Peças vestidas, na ordem dos slots (vazio = nada vestido: sem roleta).
var equipped: Array[Piece] = []
## Slot sorteado ("" = nenhum) e se a peça quebrou.
var picked_slot: String = ""
var broken: bool = false
## Uma proteção da roleta da Loja premium ([JOGO-27]) foi gasta: a peça sorteada não quebrou.
var protected_item: bool = false
var auto_respawn_seconds: float = 60.0


## Peça sorteada (null = nenhuma).
func picked() -> Piece:
	for piece: Piece in equipped:
		if piece.slot == picked_slot:
			return piece
	return null


## Lê do dicionário do `death_report`.
static func from_dict(data: Dictionary) -> DeathReport:
	var report: DeathReport = DeathReport.new()
	report.killer = Protocol.read_string(data, "killer")
	report.gold_lost = Protocol.read_int(data, "goldLost")
	report.xp_lost = Protocol.read_float(data, "xpLost")
	report.levels_lost = Protocol.read_int(data, "levelsLost")
	for entry: Dictionary in Protocol.read_dict_array(data, "equipped"):
		var piece: Piece = Piece.new()
		piece.slot = Protocol.read_string(entry, "slot")
		piece.item = InventoryState.Item.from_dict(Protocol.read_dict(entry, "item"))
		if piece.item != null and not piece.slot.is_empty():
			report.equipped.append(piece)
	report.picked_slot = Protocol.read_string(data, "pickedSlot")
	var broken_value: Variant = data.get("broken")
	report.broken = broken_value is bool and broken_value == true
	var protected_value: Variant = data.get("protected")
	report.protected_item = protected_value is bool and protected_value == true
	report.auto_respawn_seconds = Protocol.read_float(data, "autoRespawnSeconds", 60.0)
	return report
