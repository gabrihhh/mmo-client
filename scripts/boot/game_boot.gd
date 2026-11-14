class_name GameBoot
extends Node
## Ponto de entrada do JOGO (a primeira cena que vem dentro do pacote .pck). Ver mmo-docs [INFRA-08].
##
## O atualizador (no APK) só conhece o caminho [constant SCENE]: carrega o pacote e abre esta cena.
## Daqui em diante tudo é código do pacote, que pode ser atualizado: cria o [Network] (que antes era
## autoload) na raiz da árvore, para sobreviver às trocas de cena, e abre a tela de login.

## Caminho desta cena. ATENÇÃO: o atualizador (scripts/boot/updater.gd) usa este caminho fixo.
const SCENE: String = "res://scenes/boot/game_boot.tscn"
## Primeira tela do jogo.
const LOGIN_SCENE: String = "res://scenes/ui/login.tscn"
## Script do [LiveUpdater] (atualização com o jogo aberto, [INFRA-08]).
const LIVE_UPDATER_SCRIPT: String = "res://scripts/boot/live_updater.gd"


func _ready() -> void:
	# Depois de uma atualização com o jogo aberto, o LiveUpdater relê todo o código do pacote novo, menos ele mesmo
	# (não dá para recompilar o script que está rodando): faz isso agora, para a próxima atualização usar o novo.
	if ResourceLoader.has_cached(LIVE_UPDATER_SCRIPT):
		ResourceLoader.load(LIVE_UPDATER_SCRIPT, "", ResourceLoader.CACHE_MODE_IGNORE)
	if Network.instance == null:
		var network: Network = Network.new()
		network.name = "Network"
		get_tree().root.add_child.call_deferred(network)
	get_tree().change_scene_to_file.call_deferred(LOGIN_SCENE)
