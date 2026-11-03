class_name BotFight
extends Node
## Ferramenta de desenvolvimento (`-- --bot-fight`): o jogador local veste o cajado e luta sozinho contra o boneco
## de treino mais perto — ataque simples + uma carta por vez (Bola de fogo, Meteoro, Raio, Cura, Escudo).
## `-- --bot-fight=espada`: veste a espada, anda até o boneco e usa Golpe forte e Giro.
## Serve para ver animações, projéteis e avisos no chão sem tocar na tela ([JOGO-08]).
##
## Exemplo: `godot --path . -- --dev-user=Bot --bot-fight`. Só pede coisas ao servidor (que decide tudo).

## Argumento de linha de comando que liga o bot.
const ARG: String = "--bot-fight"
## Intervalo (s) entre uma carta e outra.
const CAST_INTERVAL: float = 2.2
## Ordem das cartas (cajado) e (espada).
const STAFF_ROTATION: Array[String] = ["fireball", "meteor", "bolt", "heal", "shield"]
const SWORD_ROTATION: Array[String] = ["heavy_strike", "spin"]
## Com a espada, chega até esta distância (m) do boneco antes de bater.
const MELEE_DISTANCE: float = 1.8

var _weapon: String = "training_staff"
var _rotation: Array[String] = STAFF_ROTATION

var _player: LocalPlayer = null
var _next_cast: float = 1.5
var _index: int = 0


## Cria o bot em [param parent] se o argumento estiver na linha de comando.
static func attach_if_requested(parent: Node, player: LocalPlayer) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sword: bool = (ARG + "=espada") in args
	if not ARG in args and not sword:
		return
	var bot: BotFight = BotFight.new()
	bot.name = "BotFight"
	bot._player = player
	if sword:
		bot._weapon = "training_sword"
		bot._rotation = SWORD_ROTATION
	parent.add_child(bot)


func _process(delta: float) -> void:
	var network: Network = Network.instance
	if network == null or network.inventory == null or not is_instance_valid(_player):
		return
	var weapon: InventoryState.Item = network.inventory.item_in("hand")
	if weapon == null or weapon.item_id != _weapon:
		for item: InventoryState.Item in network.inventory.bag:
			if item.item_id == _weapon:
				network.send_equip(item.uid)
				_next_cast = 1.0
				return
	var dummy: PlayerState = _nearest_dummy(network)
	if dummy == null:
		return
	if network.attack_target != dummy.id:
		network.send_attack(dummy.id)
	var to_target: Vector3 = dummy.position - _player.global_position
	to_target.y = 0.0
	var walk: bool = _weapon == "training_sword" and to_target.length() > MELEE_DISTANCE
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
		"fireball":
			network.send_cast(ability, "", to_dummy.x, to_dummy.z)
		"meteor":
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
