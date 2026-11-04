class_name BotFight
extends Node
## Ferramenta de desenvolvimento (`-- --bot-fight`): o jogador local veste o kit de treino com o cajado e luta sozinho
## contra o boneco de treino mais perto — ataque simples + uma carta por vez (Bola de fogo, Meteoro, Raio, Cura, Escudo).
## `-- --bot-fight=espada`: kit de treino com a espada, anda até o boneco e usa Golpe forte e Giro.
## `-- --bot-fight=mago` / `=cavaleiro` / `=atirador` / `=assassino` / `=curandeiro`: veste o conjunto inteiro
## ([JOGO-03], [JOGO-09]) e usa as cartas dele.
## A conta nasce pelada ([JOGO-04]): o bot veste da mochila o que faltar antes de lutar.
## Serve para ver animações, projéteis e avisos no chão sem tocar na tela ([JOGO-08]).
##
## Exemplo: `godot --path . -- --dev-user=Bot --bot-fight`. Só pede coisas ao servidor (que decide tudo).

## Argumento de linha de comando que liga o bot.
const ARG: String = "--bot-fight"
## Intervalo (s) entre uma carta e outra.
const CAST_INTERVAL: float = 2.2
## Ordem das cartas (cajado) e (espada).
## Modo → [itens a vestir (o primeiro é a arma), cartas em ordem, anda até o boneco (corpo a corpo)?].
const MODES: Dictionary[String, Array] = {
	"": [["training_staff", "training_hood", "training_vest", "training_boots"], ["fireball", "meteor", "bolt", "heal", "shield"], false],
	"espada": [["training_sword", "training_hood", "training_vest", "training_boots"], ["heavy_strike", "spin"], true],
	"mago": [["arcane_staff", "mage_hat", "mage_tunic", "mage_shoes"], ["ice_lance", "arcane_nova", "starfall", "meditation", "arcane_barrier"], false],
	"cavaleiro": [["knight_sword", "knight_helm", "knight_plate", "knight_greaves"], ["line_cleave", "ground_slam", "rallying_cry", "steel_wall", "iron_stance"], true],
	"atirador": [["ranger_crossbow", "ranger_hood", "ranger_jerkin", "ranger_boots"], ["piercing_bolt", "bolt_rain", "quick_shot", "bandage", "leather_guard"], false],
	"assassino": [["assassin_daggers", "assassin_hood", "assassin_vest", "assassin_boots"], ["backstab", "blade_flurry", "evasion", "smoke_veil"], true],
	# Curandeiro não dá dano ([JOGO-09]): o ataque simples não pega o boneco; as cartas curam/protegem o próprio bot.
	"curandeiro": [["healer_tome", "healer_circlet", "healer_robe", "healer_sandals"], ["greater_heal", "healing_circle", "holy_shield", "grace", "aegis"], false],
}
## Corpo a corpo: chega até esta distância (m) do boneco antes de bater.
const MELEE_DISTANCE: float = 1.8

## Itens a vestir (o primeiro é a arma), cartas e se anda até o boneco.
var _wear: Array[String] = []
var _rotation: Array[String] = []
var _melee: bool = false
## Espera (s) a resposta do último "vestir" antes de pedir outro (senão repete o pedido a cada quadro).
var _equip_wait: float = 0.0

var _player: LocalPlayer = null
var _next_cast: float = 1.5
var _index: int = 0


## Cria o bot em [param parent] se o argumento estiver na linha de comando.
static func attach_if_requested(parent: Node, player: LocalPlayer) -> void:
	var mode: String = ""
	var found: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == ARG or arg.begins_with(ARG + "="):
			mode = arg.trim_prefix(ARG).trim_prefix("=")
			found = MODES.has(mode)
	if not found:
		return
	var bot: BotFight = BotFight.new()
	bot.name = "BotFight"
	bot._player = player
	bot._wear.assign(MODES[mode][0])
	bot._rotation.assign(MODES[mode][1])
	bot._melee = MODES[mode][2]
	parent.add_child(bot)


func _process(delta: float) -> void:
	var network: Network = Network.instance
	if network == null or network.inventory == null or not is_instance_valid(_player):
		return
	# Veste um item por vez (o inventário novo chega antes do próximo).
	_equip_wait -= delta
	if _equip_wait > 0.0:
		return
	for item: InventoryState.Item in network.inventory.bag:
		if item.item_id in _wear:
			var worn: InventoryState.Item = network.inventory.item_in(item.slot)
			if worn == null or worn.item_id != item.item_id:
				network.send_equip(item.uid)
				_next_cast = 1.0
				_equip_wait = 0.5
				return
	var dummy: PlayerState = _nearest_dummy(network)
	if dummy == null:
		return
	# Arma de cura (Livro): o ataque simples só pega aliados, então o bot não fixa o boneco ([JOGO-09]).
	var heals: bool = not _wear.is_empty() and _wear[0] == "healer_tome"
	if not heals and network.attack_target != dummy.id:
		network.send_attack(dummy.id)
	var to_target: Vector3 = dummy.position - _player.global_position
	to_target.y = 0.0
	var walk: bool = _melee and to_target.length() > MELEE_DISTANCE
	_player.bot_direction = Vector2(to_target.x, to_target.z).normalized() if walk else Vector2.ZERO
	_next_cast -= delta
	# Andar cancela o lançamento ([JOGO-06]): só lança parado.
	if _next_cast > 0.0 or walk:
		return
	_next_cast = CAST_INTERVAL
	var ability: String = _rotation[_index % _rotation.size()]
	_index += 1
	var me: Vector3 = _player.global_position
	var to_dummy: Vector3 = dummy.position - me
	match ability:
		"fireball", "ice_lance", "line_cleave":
			network.send_cast(ability, "", to_dummy.x, to_dummy.z)
		"meteor", "starfall":
			network.send_cast(ability, "", dummy.x, dummy.z)
		"bolt":
			network.send_cast(ability, dummy.id)
		_:
			network.send_cast(ability)


func _nearest_dummy(network: Network) -> PlayerState:
	var best: PlayerState = null
	var best_distance: float = INF
	for npc: PlayerState in network.get_npcs():
		if npc.dead:
			continue
		var distance: float = npc.position.distance_to(_player.global_position)
		if distance < best_distance:
			best = npc
			best_distance = distance
	return best
