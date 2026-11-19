class_name PremiumState
extends RefCounted
## Loja premium do Menu ([JOGO-27]): o que a conta tem (Diamantes, VIP, poção de XP, pedras, proteções) e o que a Loja
## vende (produtos e pacotes de Diamantes). Chega pronto do servidor (mensagem `premium`); o cliente só mostra — o
## servidor decide toda compra.
## ATENÇÃO: PremiumData em mmo-server/src/net/protocol.ts (catálogo em mmo-server/src/premium/premium.ts).

## Abas da Loja (ids de [member Product.category]).
const CATEGORY_VIP: String = "vip"
const CATEGORY_CONVENIENCE: String = "convenience"
const CATEGORY_POWER: String = "power"


## Um produto à venda por Diamantes.
class Product:
	extends RefCounted
	var id: String = ""
	## Aba: [constant CATEGORY_VIP], [constant CATEGORY_CONVENIENCE] ou [constant CATEGORY_POWER].
	var category: String = ""
	var name: String = ""
	var description: String = ""
	## Preço em Diamantes.
	var price: int = 0
	## Compra única que a conta já tem (botão "Comprado").
	var owned: bool = false


## Um pacote de Diamantes (comprado com dinheiro real; hoje só a compra de teste do PC).
class Pack:
	extends RefCounted
	var id: String = ""
	var diamonds: int = 0
	## Preço exibido ("R$ 4,90").
	var price_label: String = ""
	## Nunca comprou este pacote: a 1ª compra vem em dobro.
	var doubled: bool = false


## Uma linha do histórico de compras (Menu → Loja → Histórico).
class HistoryEntry:
	extends RefCounted
	## Quando (segundos desde 1970, UTC).
	var at_unix: int = 0
	## "pack" (comprou Diamantes) ou "product" (gastou).
	var kind: String = ""
	var name: String = ""
	## Diamantes que entraram (+) ou saíram (−).
	var diamonds: int = 0
	## Compra de teste (sem dinheiro).
	var test: bool = false

	## Lê a lista do `premium_history_list`.
	static func list_from(data: Dictionary) -> Array[HistoryEntry]:
		var entries: Array[HistoryEntry] = []
		for raw: Dictionary in Protocol.read_dict_array(data, "entries"):
			var entry: HistoryEntry = HistoryEntry.new()
			entry.at_unix = floori(Protocol.read_float(raw, "at") / 1000.0)
			entry.kind = Protocol.read_string(raw, "kind")
			entry.name = Protocol.read_string(raw, "name")
			entry.diamonds = Protocol.read_int(raw, "diamonds")
			var test_value: Variant = raw.get("test")
			entry.test = test_value is bool and test_value == true
			entries.append(entry)
		return entries


## Saldo de Diamantes.
var diamonds: int = 0
## Segundos que faltam de VIP / poção de XP quando chegou (0 = inativo). Ver [method vip_seconds_left].
var vip_seconds: int = 0
var xp_boost_seconds: int = 0
## Pedras de melhoria garantida e proteções da roleta guardadas.
var upgrade_stones: int = 0
var death_protections: int = 0
## Vagas de anúncio a mais no Mercado agora (permanentes + VIP).
var market_slots: int = 0
var products: Array[Product] = []
var packs: Array[Pack] = []
## Este servidor aceita a compra de teste dos pacotes (PC de desenvolvimento).
var test_purchases: bool = false
## Quando chegou (ms de [method Time.get_ticks_msec]): os tempos que faltam descontam o que passou desde então.
var received_at_ms: int = 0


## Segundos de VIP que faltam agora (0 = sem VIP).
func vip_seconds_left() -> int:
	return maxi(0, vip_seconds - (Time.get_ticks_msec() - received_at_ms) / 1000)


## Segundos de poção de XP que faltam agora (0 = sem poção).
func xp_boost_seconds_left() -> int:
	return maxi(0, xp_boost_seconds - (Time.get_ticks_msec() - received_at_ms) / 1000)


## Produtos da aba [param category], na ordem do servidor.
func products_in(category: String) -> Array[Product]:
	var found: Array[Product] = []
	for product: Product in products:
		if product.category == category:
			found.append(product)
	return found


## Lê o dicionário do `premium`.
static func from_dict(data: Dictionary) -> PremiumState:
	var state: PremiumState = PremiumState.new()
	state.diamonds = Protocol.read_int(data, "diamonds")
	state.vip_seconds = Protocol.read_int(data, "vipSeconds")
	state.xp_boost_seconds = Protocol.read_int(data, "xpBoostSeconds")
	state.upgrade_stones = Protocol.read_int(data, "upgradeStones")
	state.death_protections = Protocol.read_int(data, "deathProtections")
	state.market_slots = Protocol.read_int(data, "marketSlots")
	var test_value: Variant = data.get("testPurchases")
	state.test_purchases = test_value is bool and test_value == true
	state.received_at_ms = Time.get_ticks_msec()
	for raw: Dictionary in Protocol.read_dict_array(data, "products"):
		var product: Product = Product.new()
		product.id = Protocol.read_string(raw, "id")
		product.category = Protocol.read_string(raw, "category")
		product.name = Protocol.read_string(raw, "name")
		product.description = Protocol.read_string(raw, "description")
		product.price = Protocol.read_int(raw, "price")
		var owned_value: Variant = raw.get("owned")
		product.owned = owned_value is bool and owned_value == true
		if not product.id.is_empty():
			state.products.append(product)
	for raw: Dictionary in Protocol.read_dict_array(data, "packs"):
		var pack: Pack = Pack.new()
		pack.id = Protocol.read_string(raw, "id")
		pack.diamonds = Protocol.read_int(raw, "diamonds")
		pack.price_label = Protocol.read_string(raw, "priceLabel")
		var doubled_value: Variant = raw.get("doubled")
		pack.doubled = doubled_value is bool and doubled_value == true
		if not pack.id.is_empty():
			state.packs.append(pack)
	return state


## "29 d 23 h", "5 h 12 min", "12 min" (mínimo 1 min) para [param seconds] que faltam.
static func duration_text(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours >= 24:
		return "%d d %d h" % [hours / 24, hours % 24]
	if hours > 0:
		return "%d h %d min" % [hours, minutes]
	return "%d min" % maxi(1, minutes)
