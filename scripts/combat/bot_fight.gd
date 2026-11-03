class_name BotFight
extends Node
## Ferramenta de desenvolvimento (`-- --bot-fight`): o jogador local veste o cajado e luta sozinho contra o boneco
## de treino mais perto — ataque simples + uma carta por vez (Bola de fogo, Meteoro, Raio, Cura, Escudo).
## Serve para ver animações, projéteis e avisos no chão sem tocar na tela ([JOGO-08]).
##
## Exemplo: `godot --path . -- --dev-user=Bot --bot-fight`. Só pede coisas ao servidor (que decide tudo).

## Argumento de linha de comando que liga o bot.
const ARG: String = "--bot-fight"
## Intervalo (s) entre uma carta e outra.
const CAST_INTERVAL: float = 2.2
## Ordem das cartas.
const ROTATION: Array[String] = ["fireball", "meteor", "bolt", "heal", "shield"]

var _player: LocalPlayer = null
var _next_cast: float = 1.5
var _index: int = 0


## Cria o bot em [param parent] se o argumento estiver na linha de comando.
static func attach_if_requested(parent: Node, player: LocalPlayer) -> void:
	if not ARG in OS.get_cmdline_user_args():
		return
	var bot: BotFight = BotFight.new()
	bot.name = "BotFight"
	bot._player = player
	parent.add_child(bot)


func _process(delta: float) -> void:
	var network: Network = Network.instance
	if network == null or network.inventory == null or not is_instance_valid(_player):
		return
	var weapon: InventoryState.Item = network.inventory.item_in("hand")
	if weapon == null or weapon.item_id != "training_staff":
		for item: InventoryState.Item in network.inventory.bag:
			if item.item_id == "training_staff":
				network.send_equip(item.uid)
				_next_cast = 1.0
				return
	var dummy: PlayerState = _nearest_dummy(network)
	if dummy == null:
		return
	if network.attack_target != dummy.id:
		network.send_attack(dummy.id)
	_next_cast -= delta
	if _next_cast > 0.0:
		return
	_next_cast = CAST_INTERVAL
	var ability: String = ROTATION[_index % ROTATION.size()]
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
