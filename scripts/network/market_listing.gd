class_name MarketListing
extends RefCounted
## Um anúncio do Mercado ([JOGO-25]), como chega em "market_page"/"market_mine_list".
## ATENÇÃO: espelha MarketListingView em mmo-server/src/net/protocol.ts.

var id: String = ""
## O item à venda (ficha completa, com nível e atributos).
var item: InventoryState.Item = null
var price: int = 0
## Taxa paga ao anunciar (volta ao cancelar/retirar).
var fee: int = 0
var seller_name: String = ""
## "active", "expired" ou "sold".
var status: String = "active"
## Segundos até vencer (0 se vencido/vendido).
var expires_in: int = 0
## Quem comprou (só nos seus vendidos).
var buyer_name: String = ""


## Lê um anúncio; null se o item não veio.
static func from_dict(data: Dictionary) -> MarketListing:
	var item: InventoryState.Item = InventoryState.Item.from_dict(Protocol.read_dict(data, "item"))
	if item == null:
		return null
	var listing: MarketListing = MarketListing.new()
	listing.id = Protocol.read_string(data, "id")
	listing.item = item
	listing.price = Protocol.read_int(data, "price")
	listing.fee = Protocol.read_int(data, "fee")
	listing.seller_name = Protocol.read_string(data, "sellerName")
	listing.status = Protocol.read_string(data, "status")
	listing.expires_in = Protocol.read_int(data, "expiresIn")
	listing.buyer_name = Protocol.read_string(data, "buyerName")
	return listing


## Lê a lista "listings" de [param data].
static func list_from(data: Dictionary) -> Array[MarketListing]:
	var result: Array[MarketListing] = []
	for entry: Dictionary in Protocol.read_dict_array(data, "listings"):
		var listing: MarketListing = MarketListing.from_dict(entry)
		if listing != null:
			result.append(listing)
	return result
