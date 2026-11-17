class_name TradeState
extends RefCounted
## Estado da MINHA troca aberta ([SOC-05]), como o servidor mandou em [constant Protocol.MSG_TRADE_STATE]. Só leitura:
## para mudar a oferta, confirmar ou cancelar, o cliente pede ao [Network] e o servidor responde com o estado novo.
## ATENÇÃO: espelho de TradeStateData em mmo-server/src/net/protocol.ts.

## Com quem estou trocando.
var partner_id: String = ""
var partner_name: String = ""
## O que eu ofereço / o que o outro oferece (itens com a ficha completa, para mostrar ícone e nível).
var my_items: Array[InventoryState.Item] = []
var my_gold: int = 0
var their_items: Array[InventoryState.Item] = []
var their_gold: int = 0
var my_confirmed: bool = false
var their_confirmed: bool = false
## Segundos até "Confirmar" valer quando chegou (0 = já vale); a janela conta sozinha a partir daqui.
var confirm_in: float = 0.0
## Segundos que faltavam na contagem final quando chegou; −1 = sem contagem.
var countdown: float = -1.0
## Por que não dá para confirmar agora (ex.: mochila sem espaço); vazio = nada.
var problem: String = ""


## Cria a partir do payload de [constant Protocol.MSG_TRADE_STATE].
static func from_dict(data: Dictionary) -> TradeState:
	var state: TradeState = TradeState.new()
	state.partner_id = Protocol.read_string(data, "partnerId")
	state.partner_name = Protocol.read_string(data, "partnerName")
	var mine: Dictionary = Protocol.read_dict(data, "mine")
	var theirs: Dictionary = Protocol.read_dict(data, "theirs")
	for item_data: Dictionary in Protocol.read_dict_array(mine, "items"):
		state.my_items.append(InventoryState.Item.from_dict(item_data))
	for item_data: Dictionary in Protocol.read_dict_array(theirs, "items"):
		state.their_items.append(InventoryState.Item.from_dict(item_data))
	state.my_gold = Protocol.read_int(mine, "gold")
	state.their_gold = Protocol.read_int(theirs, "gold")
	state.my_confirmed = data.get("myConfirmed") == true
	state.their_confirmed = data.get("theirConfirmed") == true
	state.confirm_in = Protocol.read_float(data, "confirmIn")
	var count: Variant = data.get("countdown")
	state.countdown = float(count) if (count is float or count is int) else -1.0
	state.problem = Protocol.read_string(data, "problem")
	return state


## [code]uid[/code] dos itens que eu ofereço, na ordem.
func my_uids() -> Array[String]:
	var uids: Array[String] = []
	for item: InventoryState.Item in my_items:
		uids.append(item.uid)
	return uids
