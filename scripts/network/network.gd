class_name Network
extends Node
## Única porta de entrada para o servidor do jogo. Acesso: [member Network.instance].
##
## Não é autoload: é criado pelo [GameBoot] depois que o atualizador carrega o pacote do jogo,
## porque autoloads ficam presos no APK e não poderiam ser atualizados (mmo-docs [INFRA-08]).
## Usa o [WebSocketPeer] nativo do Godot (sem SDK de terceiros). O resto do jogo não
## fala com o socket: usa os sinais e métodos daqui.
##
## Fluxo: [method login] / [method register] / [method resume_session] abrem a conexão e autenticam
## ([signal authenticated]); em seguida o Network entra sozinho na zona ([signal joined_zone]).
## Contas: mmo-docs [INFRA-07]. Protocolo: [INFRA-04]. Modelo autoritativo: [INFRA-09].
## Pacote do jogo velho ([constant Protocol.MSG_UPDATE_REQUIRED], ou version_mismatch fora do dev): quando a conexão
## fecha, abre o [LiveUpdater] (baixa a versão nova e reabre o jogo no mesmo processo), [INFRA-08].

## Autenticação aceita. [member username] é o nome exatamente como foi cadastrado.
signal authenticated(username: String)
## Cadastro/login/sessão recusado (ex.: "username_taken", "invalid_credentials"). [param message] já vem
## em português do servidor. A conexão continua aberta para tentar de novo (salvo "too_many_attempts").
signal auth_failed(code: String, message: String)
## Entrou na zona. A partir daqui [member player_id] é válido e [method get_players] tem a lista inicial.
signal joined_zone(player_id: String)
## Um jogador (inclusive o local) está na zona. [param state] é atualizado ao vivo pelo Network.
signal player_added(player_id: String, state: PlayerState)
## Um jogador saiu da zona.
signal player_removed(player_id: String)
## Não foi possível conectar (servidor fora do ar, URL errada...).
signal connection_error(code: int, message: String)
## O servidor recusou algo que não é autenticação (ex.: "zone_full"). Lista em mmo-server/src/net/protocol.ts.
signal server_error(code: String, message: String)
## A conexão fechou depois de aberta (logout, queda, recusa ou outra conexão da mesma conta).
## [param code] é o close code do WebSocket.
signal left_zone(code: int, reason: String)
## Chegou um snapshot do servidor (já aplicado nos [PlayerState]). [param ack] = último input DESTE
## cliente que o servidor aplicou; o [LocalPlayer] usa para reconciliar. Ver mmo-docs [INFRA-09].
signal snapshot_received(tick: int, ack: int)
## O inventário mudou (chegou o primeiro após o login, ou uma troca foi aceita). Ver [member inventory].
signal inventory_changed(inventory: InventoryState)
## Resultado de uma tentativa de melhoria no ferreiro ([JOGO-16]): [param success] = subiu para [param level];
## pagou [param cost] moedas; o atributo ganhou [param points] (0 se falhou).
signal upgrade_result(uid: String, success: bool, cost: int, attribute: String, level: int, points: int)
## Baú de acampamento abriu ou fechou ([JOGO-19]); o estado fica em [member chests].
signal chest_changed(chest_id: String, open: bool)
## Você morreu ([JOGO-21]): o que perdeu e a peça da roleta (a tela de morte mostra).
signal death_report_received(report: DeathReport)
## Resultado de uma fusão no ferreiro ([JOGO-20]): o item [param uid] ganhou [param levels_gained] níveis e
## [param xp_gained] de experiência; agora está em [param level] com [param xp] de [param xp_next] rumo ao seguinte.
signal fuse_result(uid: String, levels_gained: int, xp_gained: float, level: int, xp: float, xp_next: float)
## Chegou a lista da Loja do Ferreiro ([JOGO-23]): peças +0 e o preço de cada uma (mesma ordem).
signal shop_received(items: Array[InventoryState.Item], prices: Array[int])
## Chegou uma mensagem do chat ([SOC-09]), inclusive a sua de volta.
signal chat_received(message: ChatMessage)
## Mercado ([JOGO-25]): página da busca, seus anúncios, ação feita e "um item seu vendeu".
signal market_page_received(listings: Array[MarketListing], total: int, page: int, page_size: int)
signal market_mine_received(listings: Array[MarketListing], max_listings: int)
signal market_result(action: String, item_name: String, price: int, gold: int)
signal market_sold(item_name: String, price: int, buyer_name: String)
## Sua mensagem do chat foi recusada: [param reason] ("spam", "cooldown"…) e [param seconds] de espera.
signal chat_refused(channel: String, reason: String, seconds: int)
## Compra ([param action] "buy") ou venda ("sell") feita na Loja do Ferreiro, por [param gold] moedas.
signal shop_result(action: String, item_id: String, gold: int)
## Chegou o que sobrou para você no baú [param chest_id] (resposta a abrir/pegar): itens e moedas.
signal chest_loot_received(chest_id: String, entries: Array[LootEntry])
## Um boneco/monstro está na zona (vem no welcome). [param state] é atualizado ao vivo.
signal npc_added(npc_id: String, state: PlayerState)
## Evento de combate do tick (dano, morte, renascimento). Ver [constant Protocol.MSG_SNAPSHOT].
signal combat_event(event: Dictionary)
## Chegaram os atributos pedidos por [method send_inspect] (tela de Atributos, mmo-docs [SOC-02]).
signal attributes_received(attributes: PlayerAttributes)
## O MEU grupo mudou ([member group]; null = saí/sem grupo). Ver mmo-docs [SOC-03].
signal group_changed(group: GroupState)
## Alguém me convidou para o grupo ([param from_name]); responder com [method send_group_answer] em até
## [param expires_in] s.
signal group_invited(from_id: String, from_name: String, expires_in: float)
## Aviso pequeno do grupo ([param code]: ver [constant Protocol.MSG_GROUP_NOTICE]); [param message] vem pronta.
signal group_notice(code: String, message: String)
## Minha lista de amigos mudou ([member friends]; [SOC-04]).
signal friends_changed(friends: FriendList)
## Alguém pediu minha amizade ([param from_name]); responder com [method send_friend_answer] em até
## [param expires_in] s.
signal friend_requested(from_id: String, from_name: String, expires_in: float)
## Aviso pequeno de amizade ([param code]: ver [constant Protocol.MSG_FRIEND_NOTICE]); [param message] vem pronta.
signal friend_notice(code: String, message: String)
## A Configuração social salva na conta mudou (veio no auth_ok ou o servidor confirmou uma mudança): valores
## [constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE] (amizade, grupo, guilda); [param profile] =
## PROFILE_* ([SOC-08]); [param trade_requests] = "Pedidos de troca" ([SOC-05]).
signal social_settings_changed(friend_requests: String, group_invites: String, guild_invites: String, profile: String, trade_requests: String)
## A MINHA guilda mudou ([member guild]; null = saí/sem guilda). Ver mmo-docs [SOC-06].
signal guild_changed(guild: GuildState)
## Alguém me convidou para a guilda [param guild_title] ("[TAG] Nome"); responder com [method send_guild_answer] em
## até [param expires_in] s.
signal guild_invited(from_id: String, from_name: String, guild_title: String, expires_in: float)
## Aviso pequeno da guilda; [param message] vem pronta.
signal guild_notice(code: String, message: String)
## A guilda do jogador [param id] da zona mudou (tag no nome e cor de guildeiro).
signal player_guild_changed(id: String)
## Chegou a lista do Procurar guilda ([SOC-06]) da busca [param query] (vazia = lista normal).
signal guild_list_received(query: String, guilds: Array[GuildState.Summary])
## Chegou a ficha de uma guilda (Procurar guilda).
signal guild_info_received(info: GuildState.Info)
## Chegou uma tabela de ranking ([SOC-07]), resposta ao [method send_ranking_request].
signal ranking_received(ranking: RankingData)
## Loja premium ([JOGO-27]): saldo/efeitos/catálogo novos (também em [member premium]).
signal premium_received(state: PremiumState)
## Loja premium: compra feita ([param kind] "pack" = entraram [param diamonds]; "product" = saíram).
signal premium_result(kind: String, id: String, name: String, diamonds: int)
## Loja premium: histórico de compras (mais nova primeiro).
signal premium_history_received(entries: Array[PremiumState.HistoryEntry])
## Troca ([SOC-05]): alguém quer trocar comigo; responder com [method send_trade_answer] em até [param expires_in] s.
signal trade_requested(from_id: String, from_name: String, expires_in: float)
## A MINHA troca aberta mudou (abriu, ofertas, confirmações, contagem).
signal trade_changed(state: TradeState)
## A troca com [param partner_name] aconteceu (o inventário e as moedas novas chegam logo depois).
signal trade_done(partner_name: String)
## Aviso de troca ([param code]: ver [constant Protocol.MSG_TRADE_NOTICE]); a janela de troca fecha. [param message] vem pronta.
signal trade_notice(code: String, message: String)
## Coliseu ([JOGO-28]): tela do Coliseu (ranking, fila, bloqueio).
signal colosseum_info_received(info: ColosseumData.Info)
## "Partida encontrada": [param seconds] para aceitar, [param total] jogadores.
signal colosseum_found(mode: String, seconds: int, total: int)
## Quantos já aceitaram a partida encontrada.
signal colosseum_accept_status(accepted: int, total: int)
## A partida encontrada caiu: [param reason] "you_refused" / "other_refused"; [param requeued] = voltou à fila.
signal colosseum_cancelled(reason: String, requeued: bool, ban_seconds: int)
## Placar novo da partida (fase, round, tempo, escolhas); também em [member colosseum_state].
signal colosseum_state_changed(state: ColosseumData.MatchState)
## Fim da partida para mim (prêmio já aplicado na conta).
signal colosseum_result_received(result: ColosseumData.Result)

## Margem de desenho ([INFRA-12]): os outros (jogadores, monstros) são desenhados este número de ticks antes do tick
## atual estimado do servidor. Pequena porque passou do último snapshot o desenho **extrapola** (PlayerState): a
## margem só cobre METADE da variação da rede (o resto a extrapolação cobre, com correção suave). ADAPTATIVA:
## [constant MIN_INTERPOLATION_TICKS] + metade do atraso que 95% dos snapshots tiveram nos últimos
## [constant _JITTER_WINDOW], entre estes limites (a 30 Hz: 17–150 ms). Antes (só interpolação, 20 Hz) era 75–400 ms.
const MIN_INTERPOLATION_TICKS: float = 0.5
const MAX_INTERPOLATION_TICKS: float = 4.5
## Começo (antes de medir a rede).
const START_INTERPOLATION_TICKS: float = 1.0
## Quantos snapshots recentes entram na medida da variação da rede (60 = 2 s a 30 Hz).
const _JITTER_WINDOW: int = 60
## Quão rápido a margem muda (ticks por segundo): devagar, para os outros não "acelerarem" de repente.
const _DELAY_ADJUST_TICKS_PER_SECOND: float = 0.5
## Sinal de vida ([constant Protocol.MSG_KEEP_ALIVE]): sem mandar nada há este tempo (ms) dentro da zona, manda um.
## Mantém o Wi-Fi do celular acordado; parado, ele cochilava e os snapshots chegavam em lotes (os outros andavam aos
## trancos até você se mexer). [INFRA-12]
const KEEP_ALIVE_MS: int = 100
## A cada quantos segundos o resumo de desempenho vai para o log (adb logcat, [INFRA-12]).
const _PERF_LOG_SECONDS: float = 10.0
## Se o relógio local se afastar mais que isto (ticks) do servidor, pula direto em vez de ajustar aos poucos.
const _CLOCK_SNAP_TICKS: float = 10.0
## Fração do erro do relógio corrigida a cada snapshot (ajuste suave, sem trancos).
const _CLOCK_CORRECTION: float = 0.1
## Buffer de entrada do socket (bytes). O padrão do Godot (64 KB) enche em ~0,5 s com a zona cheia de NPCs (snapshot
## de ~7 KB a 20 Hz); um quadro travado no celular (ex.: carregar o mapa ao entrar) estourava e a conexão caía
## (código 1006). 4 MB dão dezenas de segundos de folga.
const _INBOUND_BUFFER_BYTES: int = 4 * 1024 * 1024
## Mensagens na fila de entrada do socket antes de ler (padrão do Godot: 4096 = ~3 min de snapshots; folga igual).
const _MAX_QUEUED_PACKETS: int = 8192

## Diagnóstico de queda (vai junto da mensagem "Conexão perdida"): quando chegou o último dado (ms desde o início,
## Time.get_ticks_msec) e o quadro mais demorado desde que a conexão abriu (ms). Quadro longo = o aparelho travou e
## não respondeu ao heartbeat do servidor; último dado antigo = a rede parou de entregar.
var _last_packet_ms: int = 0
var _worst_frame_ms: int = 0
var _worst_frame_at_ms: int = 0
## Autenticou, mas a conta ainda não escolheu o corpo do personagem: mostrar a tela de escolha e chamar
## [method choose_body]. O [code]join[/code] só vai depois da escolha ([signal body_chosen]).
signal body_choice_needed
## O servidor salvou o corpo escolhido; o Network já pediu para entrar na zona.
signal body_chosen(body: String)
## Esqueci a senha ([INFRA-13]): o servidor recebeu o pedido (se a conta existe, o código foi para o e-mail dela).
signal password_reset_sent
## Senha trocada com o código do e-mail; agora é entrar com ela ([method login]).
signal password_reset_done
## Códigos de erro que são resposta a cadastro/login/sessão (viram [signal auth_failed]).
const _AUTH_ERROR_CODES: Array[String] = [
	"invalid_username", "invalid_email", "invalid_password", "username_taken", "email_taken",
	"invalid_credentials", "invalid_session", "too_many_attempts", "version_mismatch", "invalid_reset_code",
]

## Tela que baixa e carrega o pacote novo com o jogo aberto. ATENÇÃO: igual a LiveUpdater.SCENE.
const LIVE_UPDATER_SCENE: String = "res://scenes/boot/live_updater.tscn"
## Versão do pacote do jogo que o servidor mandou instalar ([constant Protocol.MSG_UPDATE_REQUIRED]); 0 = nenhuma.
## [constant UPDATE_UNKNOWN] = recusado por versão de protocolo (version_mismatch) fora do dev: tenta atualizar também.
## Quando a conexão fecha com isso marcado, abre o [LiveUpdater] em vez de voltar ao login ([INFRA-08]).
var _update_version: int = 0
## Valor de [member _update_version] quando a versão nova não é conhecida (version_mismatch).
const UPDATE_UNKNOWN: int = -1

## A instância viva (criada pelo [GameBoot]); null antes do boot.
static var instance: Network = null

## Id do jogador desta conta (estável); vazio enquanto não autenticou.
var player_id: String = ""
## Username desta conta, exatamente como foi cadastrado; vazio enquanto não autenticou.
var username: String = ""
## Corpo do personagem desta conta ([constant Protocol.BODY_MALE]/[constant Protocol.BODY_FEMALE]); vazio = ainda não
## escolheu (ou não autenticou).
var body: String = ""
## Última mensagem de erro/desconexão, em português, para a tela de login mostrar. Vazio = nenhuma.
var last_error: String = ""
## Parâmetros da simulação recebidos no welcome (o servidor manda; o cliente não decide).
var tick_rate: float = 30.0
var move_speed: float = 5.0
var zone_half_size: float = 150.0
## Último inventário recebido (vestido + mochila); null antes do primeiro.
var inventory: InventoryState = null
## Jogadores podem ser atacados nesta zona (vem no welcome).
var pvp: bool = false
## Dados só deste jogador, do último snapshot ("me"): mana, segundos para renascer e alvo fixo.
var mana: float = 0.0
var max_mana: float = 0.0
var respawn_in: float = 0.0
## Nível do personagem, XP juntada dentro dele e XP que o nível pede para subir (o jogo não tem nível máximo; 0 só se um dia tiver), [JOGO-12].
## ATENÇÃO: vem do `me` do snapshot (OwnStatus em mmo-server/src/net/protocol.ts); o cliente não calcula.
var level: int = 0
var xp: float = 0.0
var xp_next: float = 0.0
## Moedas do personagem ([JOGO-15]), do `me` do snapshot; mostradas no Inventário.
var gold: int = 0
## Meu grupo segundo o servidor ([SOC-03]); null = sem grupo. Membros do grupo não se atingem e aparecem com a cor
## de aliado ([RemotePlayer]).
var group: GroupState = null
## Depois de quanto tempo (s) sem [constant Protocol.MSG_GROUP_POSITIONS] a posição de um membro longe deixa de valer
## (3 mensagens perdidas; o mapa volta à última posição conhecida pelo snapshot).
const GROUP_POSITIONS_STALE_SECONDS: float = 3.0 / Protocol.GROUP_POSITIONS_HZ
## Posição no chão (x, z em m) dos membros do grupo LONGE de mim (fora do snapshot), da última
## [constant Protocol.MSG_GROUP_POSITIONS] ([SOC-03], mapa [CLI-11]). Quem volta para a área de interesse sai daqui
## (o snapshot passa a valer).
var _group_far: Dictionary[String, Vector2] = {}
## Quando (Time.get_ticks_msec) chegou a última [constant Protocol.MSG_GROUP_POSITIONS].
var _group_far_ms: int = 0
## Meus amigos segundo o servidor ([SOC-04]); lista vazia antes da primeira mensagem.
var friends: FriendList = FriendList.new()
## Configuração social salva na conta ([SOC-04]): "Solicitações de amizade" e "Convites de grupo"
## ([constant Protocol.SOCIAL_ALWAYS] = mostrar, [constant Protocol.SOCIAL_HIDE] = recusar sozinho).
var social_friend_requests: String = Protocol.SOCIAL_ALWAYS
var social_group_invites: String = Protocol.SOCIAL_ALWAYS
## "Convites de guilda" ([SOC-06]): mostrar ou recusar sozinho.
var social_guild_invites: String = Protocol.SOCIAL_ALWAYS
## Minha guilda segundo o servidor ([SOC-06]); null = sem guilda. Guildeiros não se atingem e aparecem em azul.
var guild: GuildState = null
## Loja premium ([JOGO-27]): Diamantes, VIP, pedras... (vem logo depois de autenticar e a cada compra); null = ainda não chegou.
var premium: PremiumState = null
## Quem vê o meu perfil ([SOC-08]): [constant Protocol.PROFILE_PUBLIC] / FRIENDS / NOBODY.
var social_profile: String = Protocol.PROFILE_PUBLIC
## "Pedidos de troca" ([SOC-05]): mostrar ou recusar sozinho.
var social_trade_requests: String = Protocol.SOCIAL_ALWAYS
## Lançamento em andamento segundo o servidor (carta): alvo ("" = nenhum) e segundos que faltam.
var casting_target: String = ""
var casting_remaining: float = 0.0

## Baús dos acampamentos da zona ([JOGO-19]): id → estado (vem no welcome; o evento `chest` muda o aberto/fechado).
var chests: Dictionary[String, ChestInfo] = {}

## Tipo da zona atual (do welcome): [constant ZONE_KIND_ZONE] ou [constant ZONE_KIND_ARENA] (Coliseu, [JOGO-28]).
var zone_kind: String = ZONE_KIND_ZONE
## Tipos de zona do welcome.
const ZONE_KIND_ZONE: String = "zone"
const ZONE_KIND_ARENA: String = "arena"
## Arena do Coliseu (só valem com [member zone_kind] = arena): raio do muro (m), meu time e a folga da barreira (m).
var arena_radius: float = 0.0
var arena_team: int = 0
var arena_barrier_gap: float = 0.5
## Último placar da partida do Coliseu; null fora de uma partida.
var colosseum_state: ColosseumData.MatchState = null
## Fim da partida ainda não mostrado ([JOGO-28]): chega junto com o welcome da volta à praça, quando a cena ainda vai
## trocar; a zona que abrir mostra e limpa ([method take_colosseum_result]).
var _pending_colosseum_result: ColosseumData.Result = null
## Cena da zona comum e da arena (a tela de login, a escolha de personagem e a própria zona abrem a certa).
const ZONE_SCENE: String = "res://scenes/world/zone_1.tscn"
const ARENA_SCENE: String = "res://scenes/world/arena.tscn"

## Estimativa do tick atual do servidor (fracionário), avançada pelo tempo local e ajustada a cada snapshot.
var _clock_tick: float = 0.0
## Margem de interpolação atual (ticks; ver [constant MIN_INTERPOLATION_TICKS]) e a que ela persegue.
var interpolation_delay_ticks: float = START_INTERPOLATION_TICKS
var _target_delay_ticks: float = START_INTERPOLATION_TICKS
## Variação da rede medida (ms): quanto 95% dos snapshots chegaram atrasados em relação ao mais adiantado.
var jitter_ms: float = 0.0
## Ping (ms): de mandar um passo até chegar o snapshot com ele aplicado (inclui a espera do tick do servidor, 0–33 ms a 30 Hz).
## Suavizado. -1 = ainda não medido (só mede andando).
var ping_ms: float = -1.0
## Pior ping dos últimos [constant _PERF_LOG_SECONDS] s (ms).
var worst_ping_ms: float = 0.0
## "tick do servidor − relógio local em ticks" de cada snapshot recente (a variação disso é a variação da rede).
var _arrival_offsets: PackedFloat64Array = PackedFloat64Array()
## Quando cada passo foi enviado (seq → µs), para medir o ping pelo ack.
var _input_sent_usec: Dictionary[int, int] = {}
var _perf_log_left: float = _PERF_LOG_SECONDS
## Quando foi o último envio ao servidor (ms, Time.get_ticks_msec): base do sinal de vida.
var _last_send_ms: int = 0
## A conexão caiu sem ninguém pedir (servidor reiniciou, Wi-Fi piscou): a tela de login reconecta sozinha com a sessão
## salva ([CLI-05], [INFRA-08]). Desliga ao entrar de novo, ao sair da conta, ao entrar em outro aparelho e quando o
## servidor recusa a sessão.
var should_reconnect: bool = false
## Pior quadro (ms) dos últimos [constant _PERF_LOG_SECONDS] s (o medidor na tela e o log mostram).
var worst_frame_window_ms: int = 0

var _socket: WebSocketPeer = null
## A conexão chegou a abrir (diferencia "não conectou" de "caiu depois").
var _was_open: bool = false
## Autenticado nesta conexão.
var _authenticated: bool = false
## Já recebeu o welcome (está dentro da zona).
var _in_zone: bool = false
## Mensagem de autenticação esperando a conexão abrir: { "type": String, "data": Dictionary } ou {}.
var _pending_auth: Dictionary = {}
## Estados vivos dos jogadores da zona, por player id.
var _players: Dictionary[String, PlayerState] = {}
## Bonecos/monstros da zona, por id.
var _npcs: Dictionary[String, PlayerState] = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	set_process(false)


## true se o aparelho tem uma sessão salva (dá para entrar direto com [method resume_session]).
func has_saved_session() -> bool:
	return not AccountStorage.load_session_token().is_empty()


## Entra com a sessão salva no aparelho. Sem sessão salva, não faz nada.
func resume_session() -> void:
	var token: String = AccountStorage.load_session_token()
	if not token.is_empty():
		_request_auth(Protocol.MSG_RESUME, {"version": Protocol.VERSION, "client": PackInfo.client_build(), "sessionToken": token})


## Entra com username OU e-mail + senha.
func login(login_name: String, password: String) -> void:
	_request_auth(Protocol.MSG_LOGIN, {
		"version": Protocol.VERSION, "client": PackInfo.client_build(), "login": login_name.strip_edges(), "password": password,
	})


## Cria a conta e já entra nela. O username fica exatamente como foi digitado (sem espaços nas pontas).
func register(new_username: String, email: String, password: String) -> void:
	_request_auth(Protocol.MSG_REGISTER, {
		"version": Protocol.VERSION,
		"client": PackInfo.client_build(),
		"username": new_username.strip_edges(),
		"email": email.strip_edges(),
		"password": password,
	})


## Esqueci a senha ([INFRA-13]): pede o código para o e-mail da conta ([param login_name] = username ou e-mail).
## Resposta em [signal password_reset_sent].
func request_password_reset(login_name: String) -> void:
	_request_auth(Protocol.MSG_PASSWORD_RESET_REQUEST, {
		"version": Protocol.VERSION, "client": PackInfo.client_build(), "login": login_name.strip_edges(),
	})


## Troca a senha com o [param code] do e-mail. Resposta em [signal password_reset_done] ou [signal auth_failed]
## ([code]invalid_reset_code[/code], [code]invalid_password[/code]).
func confirm_password_reset(login_name: String, code: String, password: String) -> void:
	_request_auth(Protocol.MSG_PASSWORD_RESET_CONFIRM, {
		"version": Protocol.VERSION, "client": PackInfo.client_build(), "login": login_name.strip_edges(),
		"code": code.strip_edges(), "password": password,
	})


## Sai da conta: o servidor invalida a sessão deste aparelho e fecha a conexão; o token local é apagado.
func logout() -> void:
	AccountStorage.clear_session_token()
	last_error = ""
	should_reconnect = false
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send(Protocol.MSG_LOGOUT, {})
	elif _socket != null:
		_socket.close(1000, "logout")


## true enquanto conecta ou está conectado.
## Escolhe o corpo do personagem ([constant Protocol.BODY_MALE] ou [constant Protocol.BODY_FEMALE]) e a arma
## inicial [param weapon] (itemId; "" = nenhuma, só dev). Vale para sempre; a resposta vem em [signal body_chosen]
## (e o Network entra na zona) ou como erro ([CLI-09]).
func choose_body(new_body: String, weapon: String = "") -> void:
	var data: Dictionary[String, Variant] = {"body": new_body}
	if not weapon.is_empty():
		data["weapon"] = weapon
	_send(Protocol.MSG_CHOOSE_BODY, data)


func is_connecting_or_connected() -> bool:
	return _socket != null


## true quando está dentro da zona com o WebSocket aberto.
func is_in_zone() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _in_zone


## Jogadores atualmente na zona (inclusive o local). Usado por quem entra depois do [signal joined_zone],
## como a cena da zona, que é carregada depois do welcome.
func get_players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	result.assign(_players.values())
	return result


## Duração de um tick de simulação, em segundos.
func tick_seconds() -> float:
	return 1.0 / tick_rate


## Tick (fracionário) em que os jogadores remotos devem ser desenhados agora: o tick estimado do
## servidor menos a margem de interpolação ([member interpolation_delay_ticks], adaptativa).
func render_tick() -> float:
	return _clock_tick - interpolation_delay_ticks


## Bonecos/monstros da zona.
func get_npcs() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	result.assign(_npcs.values())
	return result


## Estado de um jogador OU boneco pelo id, ou null.
func get_entity(id: String) -> PlayerState:
	if _players.has(id):
		return _players[id]
	if _npcs.has(id):
		return _npcs[id]
	return null


## Lança a habilidade [param ability_id] ([JOGO-06]). [param target_id]: mira "no alvo" ("" = nenhum).
## [param x]/[param z]: direção (mira "direção") ou ponto no chão (mira "área"); NAN = não enviar.
## [param seq]: Investida/Disparada (e o golpe com passo das adagas) vão na fila de movimento com este número
## ([JOGO-07]); 0 = não enviar. Ataque simples ([JOGO-05]): [param ability_id] = id do ataque da arma, x/z = direção.
func send_cast(ability_id: String, target_id: String = "", x: float = NAN, z: float = NAN, seq: int = 0) -> void:
	if not is_in_zone():
		return
	var data: Dictionary = {"abilityId": ability_id}
	if not target_id.is_empty():
		data["targetId"] = target_id
	if not is_nan(x) and not is_nan(z):
		data["x"] = x
		data["z"] = z
	if seq > 0:
		data["seq"] = seq
	_send(Protocol.MSG_CAST, data)


## Estado vivo de um jogador, ou null.
func get_player(id: String) -> PlayerState:
	if not _players.has(id):
		return null
	return _players[id]


## Envia o input de UM tick: direção desejada no mundo (comprimento até 1) e o número de sequência.
## Ignorado se não estiver na zona.
func send_input(seq: int, direction_x: float, direction_z: float) -> void:
	if not is_in_zone():
		return
	_send(Protocol.MSG_INPUT, {"seq": seq, "x": direction_x, "z": direction_z})
	_input_sent_usec[seq] = Time.get_ticks_usec()
	# O WebSocketPeer só escreve no socket no poll(): sem isto o passo esperava o próximo quadro (+16–33 ms).
	_socket.poll()


## Distância máxima (m) da lista "Jogadores Próximos" ([SOC-02]): a mesma da área de interesse do servidor
## (VIEW_RADIUS em mmo-server/src/zones/Zone.ts): quem está mais longe não vem no snapshot.
const NEARBY_RADIUS: float = 45.0


## Outros jogadores (sem você) a até [param radius] m de você, vivos ou mortos, do mais perto ao mais longe
## (Menu → Jogadores Próximos, [SOC-02]). Só quem está na área de interesse ([member PlayerState.in_view]).
func get_nearby_players(radius: float = NEARBY_RADIUS) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	var own: PlayerState = get_player(player_id)
	if own == null:
		return result
	var origin: Vector3 = own.position
	for state: PlayerState in _players.values():
		if state.id == player_id or not state.in_view:
			continue
		if Vector2(state.x - origin.x, state.z - origin.z).length() <= radius:
			result.append(state)
	result.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		return Vector2(a.x - origin.x, a.z - origin.z).length_squared() < Vector2(b.x - origin.x, b.z - origin.z).length_squared())
	return result


## Pede os atributos do jogador [param target_id] ([SOC-02]). A resposta vem em [signal attributes_received]
## (ou erro [constant Protocol.ERR_PLAYER_NOT_FOUND] em [signal server_error]).
func send_inspect(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_INSPECT, {"playerId": target_id})


## true se [param id] é OUTRO jogador do meu grupo (aliado: não é alvo de ataque, cor de aliado, [SOC-03]).
## Na arena do Coliseu ([JOGO-28]) o "grupo" é o meu time ([method is_teammate]).
func is_group_member(id: String) -> bool:
	if is_arena():
		return is_teammate(id)
	return group != null and id != player_id and group.has(id)


## true se estou na arena do Coliseu ([JOGO-28]).
func is_arena() -> bool:
	return zone_kind == ZONE_KIND_ARENA


## true se [param id] é OUTRO jogador do meu time na partida do Coliseu.
func is_teammate(id: String) -> bool:
	return is_arena() and id != player_id and colosseum_state != null and colosseum_state.team_of(id) == arena_team


## true se [param id] é do outro time na partida do Coliseu (alvo de ataque na arena).
func is_arena_enemy(id: String) -> bool:
	if not is_arena() or colosseum_state == null:
		return false
	var team: int = colosseum_state.team_of(id)
	return team >= 0 and team != arena_team


## Fim da partida do Coliseu esperando para aparecer (e o esquece); null = nenhum.
func take_colosseum_result() -> ColosseumData.Result:
	var result: ColosseumData.Result = _pending_colosseum_result
	_pending_colosseum_result = null
	return result


## Cena da zona atual: a arena do Coliseu ou a zona comum.
func zone_scene() -> String:
	return ARENA_SCENE if is_arena() else ZONE_SCENE


## Na arena ([JOGO-28]): prende [param state] no muro redondo e, com a barreira ligada (fora do round), no lado do meu
## time — a mesma conta do servidor ([method Movement.constrain_arena]). Fora da arena devolve [param state].
func constrain_arena(state: Movement.State) -> Movement.State:
	if not is_arena() or arena_radius <= 0.0:
		return state
	var barrier: bool = colosseum_state == null or colosseum_state.barrier_active()
	var side: int = 0 if not barrier else (-1 if arena_team == 0 else 1)
	return Movement.constrain_arena(state, arena_radius, side, arena_barrier_gap)


## Coliseu ([JOGO-28]): pede a tela do Coliseu (resposta em [signal colosseum_info_received]).
func send_colosseum_open() -> void:
	if _authenticated:
		_send(Protocol.MSG_COLOSSEUM_OPEN, {})


## Entra na fila do [param mode] com a [param build] (slot → conjunto). O servidor confere praça, bloqueio e healer.
func send_colosseum_queue(mode: String, build: Dictionary[String, String]) -> void:
	if is_in_zone():
		_send(Protocol.MSG_COLOSSEUM_QUEUE, {"mode": mode, "build": build})


## Sai da fila (na janela de aceite conta como recusa).
func send_colosseum_leave() -> void:
	if _authenticated:
		_send(Protocol.MSG_COLOSSEUM_LEAVE, {})


## Aceita (true) ou recusa (false) a partida encontrada.
func send_colosseum_answer(accept: bool) -> void:
	if _authenticated:
		_send(Protocol.MSG_COLOSSEUM_ACCEPT if accept else Protocol.MSG_COLOSSEUM_DECLINE, {})


## [param count] das 20 escolhas da preparação de uma vez: peça [param slot] → [param attribute] (cada uma pela regra
## +1 novo / +2 repetido; o servidor usa no máximo o que falta).
func send_colosseum_point(slot: String, attribute: String, count: int = 1) -> void:
	if is_in_zone():
		_send(Protocol.MSG_COLOSSEUM_POINT, {"slot": slot, "attribute": attribute, "count": clampi(count, 1, 20)})


## Botão "Sair da partida" (abandono: sem prêmio, perde ranking e 10 min sem fila).
func send_colosseum_leave_match() -> void:
	if is_in_zone():
		_send(Protocol.MSG_COLOSSEUM_LEAVE_MATCH, {})


## true se sou o líder do meu grupo.
func is_group_leader() -> bool:
	return group != null and group.leader_id == player_id


## true se há posição recente (de [constant Protocol.MSG_GROUP_POSITIONS]) do membro [param id], que está LONGE de mim
## (fora da área de interesse). Perto, a posição vem no snapshot ([method get_players]).
func has_group_far_position(id: String) -> bool:
	return _group_far.has(id) and is_group_member(id) and Time.get_ticks_msec() - _group_far_ms <= int(GROUP_POSITIONS_STALE_SECONDS * 1000.0)


## Posição no chão (x, z em m) do membro longe [param id] (ver [method has_group_far_position]); Vector2.ZERO se não há.
func group_far_position(id: String) -> Vector2:
	return _group_far.get(id, Vector2.ZERO)


## Convida [param target_id] para o grupo ([SOC-03]). Resposta: [signal group_notice] (aceitou/recusou/expirou) ou erro.
func send_group_invite(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_GROUP_INVITE, {"playerId": target_id})


## Pede para trocar com [param target_id] ([SOC-05]). Resposta: [signal trade_changed] (aceitou), [signal trade_notice]
## ou erro.
func send_trade_request(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_TRADE_REQUEST, {"playerId": target_id})


## Responde ao pedido de troca de [param from_id].
func send_trade_answer(from_id: String, accept: bool) -> void:
	if is_in_zone() and not from_id.is_empty():
		_send(Protocol.MSG_TRADE_ANSWER, {"fromId": from_id, "accept": accept})


## Troca a minha oferta inteira: itens da mochila [param uids] e [param gold_amount] moedas.
func send_trade_offer(uids: Array[String], gold_amount: int) -> void:
	if is_in_zone():
		_send(Protocol.MSG_TRADE_OFFER, {"uids": uids, "gold": maxi(gold_amount, 0)})


## Confirma a troca como está.
func send_trade_confirm() -> void:
	if is_in_zone():
		_send(Protocol.MSG_TRADE_CONFIRM, {})


## Fecha a janela de troca (cancela para os dois).
func send_trade_cancel() -> void:
	if is_in_zone():
		_send(Protocol.MSG_TRADE_CANCEL, {})


## Responde ao convite de [param from_id] ([param accept] = aceitar).
func send_group_answer(from_id: String, accept: bool) -> void:
	if is_in_zone() and not from_id.is_empty():
		_send(Protocol.MSG_GROUP_ANSWER, {"fromId": from_id, "accept": accept})


## Líder expulsa [param target_id] do grupo.
func send_group_kick(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_GROUP_KICK, {"playerId": target_id})


## Sai do grupo.
func send_group_leave() -> void:
	if is_in_zone():
		_send(Protocol.MSG_GROUP_LEAVE, {})


## Cria a guilda [param guild_name] / [param tag] ([SOC-06]; custa [constant Protocol.GUILD_CREATE_COST] moedas).
## Resposta: [signal guild_changed] + aviso, ou erro em [signal server_error].
func send_guild_create(guild_name: String, tag: String, description: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_GUILD_CREATE, {"name": guild_name, "tag": tag, "description": description})


## Procurar guilda: pede a lista ([signal guild_list_received]); [param query] = nome/tag buscado (vazio = as que
## aceitam gente).
func send_guild_list(query: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_GUILD_LIST, {"query": query})


## Pede a ficha da guilda [param guild_id] ([signal guild_info_received]).
func send_guild_info(guild_id: String) -> void:
	if _authenticated and not guild_id.is_empty():
		_send(Protocol.MSG_GUILD_INFO, {"guildId": guild_id})


## Pede para entrar na guilda [param guild_id] (líder/oficial aceita depois).
func send_guild_request(guild_id: String) -> void:
	if _authenticated and not guild_id.is_empty():
		_send(Protocol.MSG_GUILD_REQUEST, {"guildId": guild_id})


## Líder/oficial aceita ([param accept]) ou recusa o pedido de [param target_id].
func send_guild_request_answer(target_id: String, accept: bool) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_GUILD_REQUEST_ANSWER, {"playerId": target_id, "accept": accept})


## Líder troca a descrição da guilda.
func send_guild_description(description: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_GUILD_DESCRIPTION, {"description": description})


## Convida [param target_id] para a minha guilda.
func send_guild_invite(target_id: String) -> void:
	if is_in_zone() and not target_id.is_empty():
		_send(Protocol.MSG_GUILD_INVITE, {"playerId": target_id})


## Responde ao convite de guilda de [param from_id].
func send_guild_answer(from_id: String, accept: bool) -> void:
	if _authenticated and not from_id.is_empty():
		_send(Protocol.MSG_GUILD_ANSWER, {"fromId": from_id, "accept": accept})


## Sai da guilda (1 h sem aceitar convite de outra).
func send_guild_leave() -> void:
	if _authenticated:
		_send(Protocol.MSG_GUILD_LEAVE, {})


## Expulsa [param target_id] da guilda.
func send_guild_kick(target_id: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_GUILD_KICK, {"playerId": target_id})


## Líder muda o cargo de [param target_id] para [param role] ([constant GuildState.ROLE_OFFICER] / ROLE_MEMBER).
func send_guild_role(target_id: String, role: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_GUILD_ROLE, {"playerId": target_id, "role": role})


## Pede a tabela de ranking [param category] / [param period] ([RankingData] CATEGORY_* / PERIOD_*, [SOC-07]).
func send_ranking_request(category: String, period: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_RANKING_REQUEST, {"category": category, "period": period})


## true se [param id] é OUTRO jogador da minha guilda que está na zona (não é alvo de ataque, cor azul, [SOC-06]).
func is_guild_member(id: String) -> bool:
	if guild == null or id == player_id or not _players.has(id):
		return false
	return _players[id].guild_id == guild.id


## true se [param id] é meu amigo ([SOC-04]).
func is_friend(id: String) -> bool:
	return friends.has(id)


## Pede a amizade de [param target_id] ([SOC-04]). Resposta: [signal friend_notice] (aceitou/recusou/expirou) ou erro.
func send_friend_request(target_id: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_FRIEND_REQUEST, {"playerId": target_id})


## Responde ao pedido de amizade de [param from_id] ([param accept] = aceitar).
func send_friend_answer(from_id: String, accept: bool) -> void:
	if _authenticated and not from_id.is_empty():
		_send(Protocol.MSG_FRIEND_ANSWER, {"fromId": from_id, "accept": accept})


## Remove [param target_id] dos amigos (dos dois lados).
func send_friend_remove(target_id: String) -> void:
	if _authenticated and not target_id.is_empty():
		_send(Protocol.MSG_FRIEND_REMOVE, {"playerId": target_id})


## Muda a Configuração social ([constant Protocol.SOCIAL_ALWAYS] / [constant Protocol.SOCIAL_HIDE]); o servidor salva
## na conta e confirma ([signal social_settings_changed]). [param profile] = quem vê o perfil (PROFILE_*, [SOC-08]).
func send_social_settings(friend_requests: String, group_invites: String, guild_invites: String, profile: String, trade_requests: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_SOCIAL_SETTINGS, {"friendRequests": friend_requests, "groupInvites": group_invites,
				"guildInvites": guild_invites, "profile": profile, "tradeRequests": trade_requests})


## Pede para vestir o item [param uid] da mochila. A resposta vem em [signal inventory_changed] (ou erro).
func send_equip(uid: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_EQUIP, {"uid": uid})


## Pede para tirar o item do [param slot] ("hand", "head", "chest", "feet") para a mochila: na vaga [param index]
## (arrastado até ela, [CLI-10]) ou, com −1, no fim.
func send_unequip(slot: String, index: int = -1) -> void:
	if not _authenticated:
		return
	var data: Dictionary = {"slot": slot}
	if index >= 0:
		data["index"] = index
	_send(Protocol.MSG_UNEQUIP, data)


## Tenta melhorar o item [param uid] no ferreiro escolhendo o atributo [param attribute] ([JOGO-16]). A resposta vem em
## [signal upgrade_result] (ou erro).
## Pede o que há para você no baú [param chest_id] (perto dele e aberto, [JOGO-19]).
func send_chest_open(chest_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_CHEST_OPEN, {"chestId": chest_id})


## Pega [param loot_id] do baú [param chest_id].
func send_chest_take(chest_id: String, loot_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_CHEST_TAKE, {"chestId": chest_id, "lootId": loot_id})


## Pede para fundir [param material_uid] (da mochila) em [param target_uid] (o mesmo item), perto do ferreiro.
func send_fuse(target_uid: String, material_uid: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_FUSE, {"targetUid": target_uid, "materialUid": material_uid})


## Tela de morte → "Renascer": renasce no spawn agora ([JOGO-21]).
func send_respawn() -> void:
	if is_in_zone():
		_send(Protocol.MSG_RESPAWN, {})


## Ferreiro ([JOGO-16]): melhora [param uid] em [param attribute]; [param guaranteed] = gastar uma pedra garantida da
## Loja premium ([JOGO-27]; o servidor só gasta se a chance for menor que 100%).
func send_upgrade(uid: String, attribute: String, guaranteed: bool = false) -> void:
	if _authenticated:
		_send(Protocol.MSG_UPGRADE, {"uid": uid, "attribute": attribute, "guaranteed": guaranteed})


## Loja premium ([JOGO-27]): pede saldo/catálogo (resposta em [signal premium_received]).
func send_premium_open() -> void:
	if _authenticated:
		_send(Protocol.MSG_PREMIUM_OPEN, {})


## Compra o produto [param product_id] com Diamantes (resposta: [signal premium_result] + [signal premium_received]).
func send_premium_buy(product_id: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_PREMIUM_BUY, {"productId": product_id})


## Compra o pacote de Diamantes [param pack_id] (hoje só a compra de teste do servidor de dev).
func send_premium_pack(pack_id: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_PREMIUM_PACK, {"packId": pack_id})


## Pede o histórico de compras da Loja (resposta em [signal premium_history_received]).
func send_premium_history() -> void:
	if _authenticated:
		_send(Protocol.MSG_PREMIUM_HISTORY, {})


## Mercado ([JOGO-25]): busca [param query] (nome do item ou do conjunto), [param slot] ("" = todos), ordem
## [param sort] ("price"/"new") e página [param page] (0…). Resposta: [signal market_page_received].
func send_market_list(query: String, slot: String, sort: String, page: int) -> void:
	if is_in_zone():
		_send(Protocol.MSG_MARKET_LIST, {"query": query, "slot": slot if not slot.is_empty() else null, "sort": sort, "page": page})


## Mercado: pede os seus anúncios ([signal market_mine_received]).
func send_market_mine() -> void:
	if is_in_zone():
		_send(Protocol.MSG_MARKET_MINE, {})


## Mercado: anuncia o item [param uid] da mochila por [param price] moedas (a taxa de 5% sai agora).
func send_market_sell(uid: String, price: int) -> void:
	if is_in_zone():
		_send(Protocol.MSG_MARKET_SELL, {"uid": uid, "price": price})


## Mercado: compra o anúncio [param listing_id].
func send_market_buy(listing_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_MARKET_BUY, {"listingId": listing_id})


## Mercado: cancela/retira o seu anúncio [param listing_id] (item e taxa voltam).
func send_market_cancel(listing_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_MARKET_CANCEL, {"listingId": listing_id})


## Chat ([SOC-09]): manda [param text] no [param channel] ("zone", "group", "guild", "private", "global"); no privado,
## [param to] = nome de quem recebe. Resposta: [signal chat_received] (a sua de volta) ou [signal chat_refused].
func send_chat(channel: String, text: String, to: String = "") -> void:
	if not is_in_zone():
		return
	var data: Dictionary = {"channel": channel, "text": text}
	if not to.is_empty():
		data["to"] = to
	_send(Protocol.MSG_CHAT_SEND, data)


## Armazém ([JOGO-26]): guarda o item [param uid] da mochila (resposta: [signal inventory_changed] ou erro).
func send_storage_put(uid: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_STORAGE_PUT, {"uid": uid})


## Armazém: tira o item [param uid] para a mochila.
func send_storage_take(uid: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_STORAGE_TAKE, {"uid": uid})


## Armazém: compra mais uma aba de 20 espaços (as moedas vêm no snapshot).
func send_storage_buy_tab() -> void:
	if is_in_zone():
		_send(Protocol.MSG_STORAGE_BUY_TAB, {})


## Loja do Ferreiro ([JOGO-23]): pede a lista à venda (resposta em [signal shop_received]).
func send_shop_open() -> void:
	if is_in_zone():
		_send(Protocol.MSG_SHOP_OPEN, {})


## Compra a peça [param item_id] (+0) na Loja do Ferreiro (resposta em [signal shop_result] ou erro).
func send_shop_buy(item_id: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_SHOP_BUY, {"itemId": item_id})


## Vende o item [param uid] da mochila na Loja do Ferreiro (resposta em [signal shop_result] ou erro).
func send_shop_sell(uid: String) -> void:
	if is_in_zone():
		_send(Protocol.MSG_SHOP_SELL, {"uid": uid})


## Destrói para sempre o item [param uid] (vestido ou na mochila, [JOGO-24]). A resposta vem em
## [signal inventory_changed] (ou erro).
## ATENÇÃO: espelha `item_destroy` em mmo-server/src/net/protocol.ts.
func send_item_destroy(uid: String) -> void:
	if _authenticated:
		_send(Protocol.MSG_ITEM_DESTROY, {"uid": uid})


## Pede para trocar de lugar os itens das vagas [param from] e [param to] da mochila (vaga livre = leva para o fim).
func send_bag_move(from: int, to: int) -> void:
	if _authenticated:
		_send(Protocol.MSG_BAG_MOVE, {"from": from, "to": to})


func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE) and _socket != null:
		# Fechar o app não é logout: a sessão continua salva para entrar direto da próxima vez.
		_socket.close(1000, "app fechado")


## Manda a mensagem de autenticação agora (conexão aberta) ou guarda e abre a conexão.
func _request_auth(type: String, data: Dictionary) -> void:
	last_error = ""
	if _authenticated:
		return
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send(type, data)
		return
	_pending_auth = {"type": type, "data": data}
	if _socket == null:
		_open_socket()


func _open_socket() -> void:
	_socket = WebSocketPeer.new()
	_worst_frame_ms = 0
	_last_packet_ms = Time.get_ticks_msec()
	_socket.inbound_buffer_size = _INBOUND_BUFFER_BYTES
	_socket.max_queued_packets = _MAX_QUEUED_PACKETS
	_arrival_offsets.clear()
	_input_sent_usec.clear()
	interpolation_delay_ticks = START_INTERPOLATION_TICKS
	_target_delay_ticks = START_INTERPOLATION_TICKS
	ping_ms = -1.0
	var url: String = NetworkConfig.server_url()
	var error: Error = _socket.connect_to_url(url)
	if error != OK:
		_socket = null
		_fail_connection(error, "URL do servidor inválida: %s" % url)
		return
	_was_open = false
	set_process(true)


func _process(delta: float) -> void:
	_clock_tick += delta * tick_rate
	interpolation_delay_ticks = move_toward(interpolation_delay_ticks, _target_delay_ticks, _DELAY_ADJUST_TICKS_PER_SECOND * delta)
	_perf_log_left -= delta
	if _perf_log_left <= 0.0:
		_perf_log_left = _PERF_LOG_SECONDS
		if _in_zone:
			var corrections: Vector3 = PlayerState.take_correction_stats()
			print("Perf: ping %d ms (pior %d) · variação da rede %d ms · margem %d ms · pior quadro %d ms · correção dos outros %d× média %d cm (maior %d)" % [
				int(ping_ms), int(worst_ping_ms), int(jitter_ms), int(interpolation_delay_ticks * 1000.0 / tick_rate), worst_frame_window_ms,
				int(corrections.z), int(corrections.x * 100.0), int(corrections.y * 100.0)])
		worst_ping_ms = 0.0
		worst_frame_window_ms = 0
	var frame_ms: int = int(delta * 1000.0)
	worst_frame_window_ms = maxi(worst_frame_window_ms, frame_ms)
	if frame_ms > _worst_frame_ms:
		_worst_frame_ms = frame_ms
		_worst_frame_at_ms = Time.get_ticks_msec()
	_socket.poll()
	var state: WebSocketPeer.State = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		# Sem o algoritmo de Nagle: o passo (mensagem pequena, 20 por segundo) sai na hora, sem esperar juntar.
		# (Só dá depois de abrir: antes o socket TCP ainda não existe.)
		_socket.set_no_delay(true)
		if not _pending_auth.is_empty():
			_send(Protocol.read_string(_pending_auth, "type"), Protocol.read_dict(_pending_auth, "data"))
			_pending_auth = {}

	# Atenção: o WebSocketPeer DESCARTA o que chega junto com o close (testado em 2026-11-14); por isso o servidor espera
	# CLOSE_DELAY_MS (mmo-server/src/GameServer.ts) entre o "error"/"update_required" e o fechamento.
	while _socket.get_available_packet_count() > 0:
		_last_packet_ms = Time.get_ticks_msec()
		_handle_message(_socket.get_packet().get_string_from_utf8())
	if _socket != null:
		_keep_radio_awake()

	if state == WebSocketPeer.STATE_CLOSED:
		_on_closed()


func _send(type: String, data: Dictionary) -> void:
	_socket.send_text(Protocol.encode(type, data))
	_last_send_ms = Time.get_ticks_msec()


## Parado (sem passos nem outros envios há [constant KEEP_ALIVE_MS]): manda o sinal de vida e já escreve no socket.
func _keep_radio_awake() -> void:
	if not _in_zone or _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if Time.get_ticks_msec() - _last_send_ms < KEEP_ALIVE_MS:
		return
	_send(Protocol.MSG_KEEP_ALIVE, {})
	_socket.poll()


func _handle_message(text: String) -> void:
	var message: Dictionary = Protocol.decode(text)
	if message.is_empty():
		push_warning("Network: mensagem fora do protocolo: %s" % text)
		return
	var type: String = Protocol.read_string(message, "type")
	var data: Dictionary = Protocol.read_dict(message, "data")

	match type:
		Protocol.MSG_AUTH_OK:
			_authenticated = true
			player_id = Protocol.read_string(data, "playerId")
			username = Protocol.read_string(data, "username")
			var token: String = Protocol.read_string(data, "sessionToken")
			if not token.is_empty():
				AccountStorage.save_session_token(token)
			body = Protocol.read_string(data, "body")
			_apply_social_settings(Protocol.read_dict(data, "social"))
			should_reconnect = false
			authenticated.emit(username)
			# Primeira entrada: escolher o corpo antes de entrar na zona ([INFRA-07]).
			if body.is_empty():
				body_choice_needed.emit()
			else:
				_send(Protocol.MSG_JOIN, {"zone": NetworkConfig.ZONE_ID})
		Protocol.MSG_PASSWORD_RESET_SENT:
			password_reset_sent.emit()
		Protocol.MSG_PASSWORD_RESET_DONE:
			password_reset_done.emit()
		Protocol.MSG_BODY_CHOSEN:
			body = Protocol.read_string(data, "body")
			body_chosen.emit(body)
			_send(Protocol.MSG_JOIN, {"zone": NetworkConfig.ZONE_ID})
		Protocol.MSG_WELCOME:
			# Segundo welcome na mesma conexão = o servidor trocou de zona (entrou/saiu da arena do Coliseu, [JOGO-28]):
			# o que era da zona anterior some (a cena nova cria tudo de novo).
			if _in_zone:
				_reset_zone_state()
			zone_kind = ZONE_KIND_ARENA if Protocol.read_string(data, "kind") == ZONE_KIND_ARENA else ZONE_KIND_ZONE
			var arena: Dictionary = Protocol.read_dict(data, "arena")
			arena_radius = Protocol.read_float(arena, "radius")
			arena_team = Protocol.read_int(arena, "team")
			arena_barrier_gap = Protocol.read_float(arena, "barrierGap", 0.5)
			if zone_kind != ZONE_KIND_ARENA:
				colosseum_state = null
			var sim: Dictionary = Protocol.read_dict(data, "sim")
			tick_rate = Protocol.read_float(sim, "tickRate", tick_rate)
			move_speed = Protocol.read_float(sim, "moveSpeed", move_speed)
			zone_half_size = Protocol.read_float(sim, "zoneHalfSize", zone_half_size)
			_clock_tick = float(Protocol.read_int(data, "tick"))
			var pvp_value: Variant = data.get("pvp")
			pvp = pvp_value is bool and pvp_value == true
			_in_zone = true
			for npc: Dictionary in Protocol.read_dict_array(data, "npcs"):
				var npc_state: PlayerState = PlayerState.from_snapshot(npc, int(_clock_tick))
				if npc_state != null and not _npcs.has(npc_state.id):
					# Fora da vista até vir no snapshot ([INFRA-11]: o servidor só manda quem está perto).
					npc_state.in_view = false
					_npcs[npc_state.id] = npc_state
					npc_added.emit(npc_state.id, npc_state)
			chests.clear()
			for chest_data: Dictionary in Protocol.read_dict_array(data, "chests"):
				var chest: ChestInfo = ChestInfo.from_dict(chest_data)
				if chest != null:
					chests[chest.id] = chest
			# Lista primeiro: quem reagir ao joined_zone já encontra os jogadores em get_players().
			for info: Dictionary in Protocol.read_dict_array(data, "players"):
				_add_player(info)
			joined_zone.emit(player_id)
		Protocol.MSG_PLAYER_JOINED:
			_add_player(Protocol.read_dict(data, "player"))
		Protocol.MSG_PLAYER_LEFT:
			_remove_player(Protocol.read_string(data, "id"))
		Protocol.MSG_SNAPSHOT:
			_apply_snapshot(data)
		Protocol.MSG_INVENTORY:
			inventory = InventoryState.from_dict(data)
			inventory_changed.emit(inventory)
		Protocol.MSG_DEATH_REPORT:
			death_report_received.emit(DeathReport.from_dict(data))
		Protocol.MSG_SHOP:
			var items: Array[InventoryState.Item] = []
			var prices: Array[int] = []
			for offer: Dictionary in Protocol.read_dict_array(data, "offers"):
				var item: InventoryState.Item = InventoryState.Item.from_dict(Protocol.read_dict(offer, "item"))
				if item != null:
					items.append(item)
					prices.append(Protocol.read_int(offer, "price"))
			shop_received.emit(items, prices)
		Protocol.MSG_MARKET_PAGE:
			market_page_received.emit(MarketListing.list_from(data), Protocol.read_int(data, "total"), Protocol.read_int(data, "page"), Protocol.read_int(data, "pageSize", 20))
		Protocol.MSG_MARKET_MINE_LIST:
			market_mine_received.emit(MarketListing.list_from(data), Protocol.read_int(data, "maxListings", 10))
		Protocol.MSG_MARKET_RESULT:
			market_result.emit(Protocol.read_string(data, "action"), Protocol.read_string(data, "itemName"), Protocol.read_int(data, "price"), Protocol.read_int(data, "gold"))
		Protocol.MSG_MARKET_SOLD:
			market_sold.emit(Protocol.read_string(data, "itemName"), Protocol.read_int(data, "price"), Protocol.read_string(data, "buyerName"))
		Protocol.MSG_CHAT:
			chat_received.emit(ChatMessage.from_dict(data))
		Protocol.MSG_CHAT_REFUSED:
			chat_refused.emit(Protocol.read_string(data, "channel"), Protocol.read_string(data, "reason"), Protocol.read_int(data, "seconds"))
		Protocol.MSG_SHOP_RESULT:
			shop_result.emit(Protocol.read_string(data, "action"), Protocol.read_string(data, "itemId"), Protocol.read_int(data, "gold"))
		Protocol.MSG_FUSE_RESULT:
			fuse_result.emit(Protocol.read_string(data, "uid"), Protocol.read_int(data, "levelsGained"),
				Protocol.read_float(data, "xpGained"), Protocol.read_int(data, "level"), Protocol.read_float(data, "xp"),
				Protocol.read_float(data, "xpNext"))
		Protocol.MSG_CHEST_LOOT:
			var entries: Array[LootEntry] = []
			for entry: Dictionary in Protocol.read_dict_array(data, "entries"):
				var parsed: LootEntry = LootEntry.from_dict(entry)
				if parsed != null:
					entries.append(parsed)
			chest_loot_received.emit(Protocol.read_string(data, "chestId"), entries)
		Protocol.MSG_UPGRADE_RESULT:
			var success_value: Variant = data.get("success")
			upgrade_result.emit(Protocol.read_string(data, "uid"), success_value is bool and success_value == true,
				Protocol.read_int(data, "cost"), Protocol.read_string(data, "attribute"), Protocol.read_int(data, "level"),
				Protocol.read_int(data, "points"))
		Protocol.MSG_ATTRIBUTES:
			var attributes: PlayerAttributes = PlayerAttributes.from_dict(data)
			if attributes != null:
				attributes_received.emit(attributes)
		Protocol.MSG_GROUP:
			group = GroupState.from_dict(Protocol.read_dict(data, "group"))
			if group == null:
				_group_far.clear()
			group_changed.emit(group)
		Protocol.MSG_GROUP_POSITIONS:
			_apply_group_positions(data)
		Protocol.MSG_GROUP_INVITED:
			group_invited.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"), Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_GROUP_NOTICE:
			group_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_FRIENDS:
			friends = FriendList.from_dict(data)
			friends_changed.emit(friends)
		Protocol.MSG_FRIEND_REQUESTED:
			friend_requested.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"), Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_FRIEND_NOTICE:
			friend_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_SOCIAL_SETTINGS:
			_apply_social_settings(data)
		Protocol.MSG_GUILD:
			guild = GuildState.from_dict(Protocol.read_dict(data, "guild"))
			guild_changed.emit(guild)
		Protocol.MSG_GUILD_INVITED:
			guild_invited.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"),
					"[%s] %s" % [Protocol.read_string(data, "guildTag"), Protocol.read_string(data, "guildName")],
					Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_GUILD_NOTICE:
			guild_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_GUILD_LIST:
			guild_list_received.emit(Protocol.read_string(data, "query"), GuildState.Summary.list_from(data))
		Protocol.MSG_GUILD_INFO:
			guild_info_received.emit(GuildState.Info.from_dict(data))
		Protocol.MSG_RANKING:
			ranking_received.emit(RankingData.from_dict(data))
		Protocol.MSG_PREMIUM:
			premium = PremiumState.from_dict(data)
			premium_received.emit(premium)
		Protocol.MSG_PREMIUM_RESULT:
			premium_result.emit(Protocol.read_string(data, "kind"), Protocol.read_string(data, "id"), Protocol.read_string(data, "name"), Protocol.read_int(data, "diamonds"))
		Protocol.MSG_PREMIUM_HISTORY_LIST:
			premium_history_received.emit(PremiumState.HistoryEntry.list_from(data))
		Protocol.MSG_TRADE_REQUESTED:
			trade_requested.emit(Protocol.read_string(data, "fromId"), Protocol.read_string(data, "fromName"), Protocol.read_float(data, "expiresIn", 30.0))
		Protocol.MSG_TRADE_STATE:
			trade_changed.emit(TradeState.from_dict(data))
		Protocol.MSG_TRADE_DONE:
			trade_done.emit(Protocol.read_string(data, "partnerName"))
		Protocol.MSG_TRADE_NOTICE:
			trade_notice.emit(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		Protocol.MSG_PLAYER_GUILD:
			var guild_player_id: String = Protocol.read_string(data, "id")
			if _players.has(guild_player_id):
				_players[guild_player_id].guild_id = Protocol.read_string(data, "guildId")
				_players[guild_player_id].guild_tag = Protocol.read_string(data, "guildTag")
				player_guild_changed.emit(guild_player_id)
		Protocol.MSG_COLOSSEUM_INFO:
			colosseum_info_received.emit(ColosseumData.Info.from_dict(data))
		Protocol.MSG_COLOSSEUM_FOUND:
			colosseum_found.emit(Protocol.read_string(data, "mode"), Protocol.read_int(data, "seconds"), Protocol.read_int(data, "total"))
		Protocol.MSG_COLOSSEUM_ACCEPT_STATUS:
			colosseum_accept_status.emit(Protocol.read_int(data, "accepted"), Protocol.read_int(data, "total"))
		Protocol.MSG_COLOSSEUM_CANCELLED:
			var requeued_value: Variant = data.get("requeued")
			colosseum_cancelled.emit(Protocol.read_string(data, "reason"), requeued_value is bool and requeued_value == true, Protocol.read_int(data, "banSeconds"))
		Protocol.MSG_COLOSSEUM_STATE:
			colosseum_state = ColosseumData.MatchState.from_dict(data)
			colosseum_state_changed.emit(colosseum_state)
		Protocol.MSG_COLOSSEUM_RESULT:
			_pending_colosseum_result = ColosseumData.Result.from_dict(data)
			colosseum_result_received.emit(_pending_colosseum_result)
		Protocol.MSG_UPDATE_REQUIRED:
			# Fecha já (o servidor também fecharia, com 4003, um pouco depois); no fechamento abre o LiveUpdater ([INFRA-08]).
			_update_version = maxi(Protocol.read_int(data, "version"), 1)
			print("[rede] pacote novo publicado (versão %d): atualizando" % _update_version)
			_socket.close(1000, "update")
		Protocol.MSG_ERROR:
			_handle_error(Protocol.read_string(data, "code"), Protocol.read_string(data, "message"))
		_:
			push_warning("Network: tipo de mensagem desconhecido: %s" % type)


## Guarda a Configuração social vinda do servidor (valor desconhecido/faltando = mostrar) e avisa.
func _apply_social_settings(data: Dictionary) -> void:
	var friend_requests: String = Protocol.read_string(data, "friendRequests")
	var group_invites: String = Protocol.read_string(data, "groupInvites")
	social_friend_requests = Protocol.SOCIAL_HIDE if friend_requests == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	social_group_invites = Protocol.SOCIAL_HIDE if group_invites == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	var guild_invites: String = Protocol.read_string(data, "guildInvites")
	social_guild_invites = Protocol.SOCIAL_HIDE if guild_invites == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	var profile: String = Protocol.read_string(data, "profile")
	social_profile = profile if profile in [Protocol.PROFILE_FRIENDS, Protocol.PROFILE_NOBODY] else Protocol.PROFILE_PUBLIC
	var trade_requests: String = Protocol.read_string(data, "tradeRequests")
	social_trade_requests = Protocol.SOCIAL_HIDE if trade_requests == Protocol.SOCIAL_HIDE else Protocol.SOCIAL_ALWAYS
	social_settings_changed.emit(social_friend_requests, social_group_invites, social_guild_invites, social_profile, social_trade_requests)


func _handle_error(code: String, message: String) -> void:
	push_warning("Network: servidor recusou (%s): %s" % [code, message])
	last_error = message
	if code == Protocol.ERR_VERSION_MISMATCH and not PackInfo.is_dev():
		# Servidor com outro protocolo: quase sempre há pacote novo. O LiveUpdater confere o manifesto e, se não houver
		# versão nova, mostra a mensagem e "Tentar de novo" (sem laço de atualização).
		_update_version = UPDATE_UNKNOWN
		_socket.close(1000, "update")
		return
	if code in _AUTH_ERROR_CODES:
		if code == Protocol.ERR_INVALID_SESSION:
			AccountStorage.clear_session_token()
		# Sessão recusada (expirou, conta mudou): não adianta insistir sozinho.
		should_reconnect = false
		auth_failed.emit(code, message)
	else:
		server_error.emit(code, message)


func _add_player(info: Dictionary) -> void:
	var state: PlayerState = PlayerState.from_snapshot(info, int(_clock_tick))
	if state == null or _players.has(state.id):
		return
	# Fora da vista até vir no snapshot (você sempre vem), [INFRA-11].
	state.in_view = state.id == player_id
	_players[state.id] = state
	player_added.emit(state.id, state)


## Guarda as posições dos membros do grupo longe ([constant Protocol.MSG_GROUP_POSITIONS]): a lista substitui a anterior
## (quem não veio está perto, no snapshot, ou saiu do grupo).
func _apply_group_positions(data: Dictionary) -> void:
	_group_far.clear()
	_group_far_ms = Time.get_ticks_msec()
	for entry: Dictionary in Protocol.read_dict_array(data, "members"):
		var id: String = Protocol.read_string(entry, "id")
		if not id.is_empty():
			_group_far[id] = Vector2(Protocol.read_float(entry, "x"), Protocol.read_float(entry, "z"))


## Aplica um snapshot ([INFRA-04], versão 22 por diferença, [INFRA-11]): guarda o estado de cada um naquele tick,
## ajusta o relógio e avisa.
## - Entrada em [code]players[/code]/[code]npcs[/code]: só os campos que mudaram (todos, se acabou de entrar na vista);
##   junta aos que já conhecemos e marca como à vista.
## - [code]gone[/code]: saiu da vista (longe ou limite da multidão): esconde e congela até voltar.
## - À vista e não veio: está igual ao último; entra no histórico mesmo assim (a interpolação não vê buraco).
## - [code]me[/code]: só os campos que mudaram; os outros ficam como estavam.
func _apply_snapshot(data: Dictionary) -> void:
	var server_tick: int = Protocol.read_int(data, "tick", -1)
	if server_tick < 0:
		return
	_measure_arrival(server_tick)
	_measure_ping(Protocol.read_int(data, "ack"))
	var gone: Variant = data.get("gone")
	if gone is Array:
		for id_value: Variant in gone:
			if id_value is String:
				var who: PlayerState = get_entity(id_value)
				if who != null and who.id != player_id:
					who.in_view = false
	# Instante que está sendo desenhado agora (para a correção suave da extrapolação, PlayerState.apply_snapshot).
	var render_now: float = render_tick()
	var touched: Dictionary[String, bool] = {}
	for entry: Dictionary in Protocol.read_dict_array(data, "players"):
		var id: String = Protocol.read_string(entry, "id")
		if _players.has(id):
			_players[id].apply_snapshot(entry, server_tick, render_now)
			_players[id].in_view = true
			touched[id] = true
			# Membro do grupo voltou para perto: vale o snapshot, não a posição de longe (velha).
			_group_far.erase(id)
	for entry: Dictionary in Protocol.read_dict_array(data, "npcs"):
		var npc_id: String = Protocol.read_string(entry, "id")
		if _npcs.has(npc_id):
			_npcs[npc_id].apply_snapshot(entry, server_tick, render_now)
			_npcs[npc_id].in_view = true
			touched[npc_id] = true
	var unchanged: Dictionary = {}
	for state: PlayerState in _players.values():
		if state.in_view and not touched.has(state.id):
			state.apply_snapshot(unchanged, server_tick, render_now)
	for state: PlayerState in _npcs.values():
		if state.in_view and not touched.has(state.id):
			state.apply_snapshot(unchanged, server_tick, render_now)
	var me: Dictionary = Protocol.read_dict(data, "me")
	mana = Protocol.read_float(me, "mana", mana)
	max_mana = Protocol.read_float(me, "maxMana", max_mana)
	respawn_in = Protocol.read_float(me, "respawnIn", respawn_in)
	level = Protocol.read_int(me, "level", level)
	xp = Protocol.read_float(me, "xp", xp)
	xp_next = Protocol.read_float(me, "xpNext", xp_next)
	gold = Protocol.read_int(me, "gold", gold)
	# O lançamento pode virar null: só muda quando a chave vem.
	if me.has("casting"):
		var casting: Dictionary = Protocol.read_dict(me, "casting")
		casting_target = Protocol.read_string(casting, "target")
		casting_remaining = Protocol.read_float(casting, "remaining")
	_sync_clock(server_tick)
	snapshot_received.emit(server_tick, Protocol.read_int(data, "ack"))
	for event: Dictionary in Protocol.read_dict_array(data, "events"):
		if Protocol.read_string(event, "type") == "chest":
			var chest_id: String = Protocol.read_string(event, "id")
			var open_value: Variant = event.get("open")
			if chests.has(chest_id) and open_value is bool:
				var chest: ChestInfo = chests[chest_id]
				# O evento também vem só para mudar o relógio da volta (mapa, [CLI-11]): avisa só se abriu/fechou.
				chest.set_reset_in(Protocol.read_float(event, "resetIn"))
				if chest.open != open_value:
					chest.open = open_value
					chest_changed.emit(chest_id, open_value)
			continue
		if Protocol.read_string(event, "type") == "look":
			# Jogador ou NPC humano (o atirador de teste troca de roupa, [JOGO-11]).
			var who: PlayerState = get_entity(Protocol.read_string(event, "id"))
			if who != null:
				who.set_look(Protocol.read_dict(event, "look"), Protocol.read_dict(event, "levels"))
			continue
		combat_event.emit(event)


## Variação da rede ([INFRA-12]): guarda "tick do servidor − relógio local" deste snapshot. O mais adiantado da janela
## é o caminho sem atraso extra; quanto os outros ficaram atrás dele é a variação. Margem de interpolação = 1 tick + a
## variação que 95% tiveram + folga.
func _measure_arrival(server_tick: int) -> void:
	var local_ticks: float = float(Time.get_ticks_usec()) / 1000000.0 * tick_rate
	_arrival_offsets.append(float(server_tick) - local_ticks)
	if _arrival_offsets.size() > _JITTER_WINDOW:
		_arrival_offsets.remove_at(0)
	var best: float = _arrival_offsets[0]
	for offset: float in _arrival_offsets:
		best = maxf(best, offset)
	var lateness: PackedFloat64Array = PackedFloat64Array()
	for offset: float in _arrival_offsets:
		lateness.append(best - offset)
	lateness.sort()
	var p95: float = lateness[mini(lateness.size() - 1, int(float(lateness.size()) * 0.95))]
	jitter_ms = p95 * 1000.0 / tick_rate
	_target_delay_ticks = clampf(MIN_INTERPOLATION_TICKS + p95 * 0.5, MIN_INTERPOLATION_TICKS, MAX_INTERPOLATION_TICKS)


## Ping: o snapshot confirma (ack) os passos até [param ack]; o tempo desde que o último deles saiu é o ping.
func _measure_ping(ack: int) -> void:
	if not _input_sent_usec.has(ack):
		return
	var sample: float = float(Time.get_ticks_usec() - _input_sent_usec[ack]) / 1000.0
	ping_ms = sample if ping_ms < 0.0 else lerpf(ping_ms, sample, 0.2)
	worst_ping_ms = maxf(worst_ping_ms, sample)
	for seq: int in _input_sent_usec.keys():
		if seq <= ack:
			_input_sent_usec.erase(seq)


## Puxa o relógio local na direção do tick do servidor: aos poucos, ou de uma vez se estiver longe. Usa o snapshot
## MAIS ADIANTADO da janela (o caminho sem atraso extra), não o último: um snapshot atrasado não puxa o relógio para trás.
func _sync_clock(server_tick: int) -> void:
	var target: float = float(server_tick)
	if not _arrival_offsets.is_empty():
		var best: float = _arrival_offsets[0]
		for offset: float in _arrival_offsets:
			best = maxf(best, offset)
		target = float(Time.get_ticks_usec()) / 1000000.0 * tick_rate + best
	var error: float = target - _clock_tick
	if absf(error) > _CLOCK_SNAP_TICKS:
		_clock_tick = float(server_tick)
	else:
		_clock_tick += error * _CLOCK_CORRECTION


func _remove_player(id: String) -> void:
	if _players.erase(id):
		player_removed.emit(id)


## Esquece o que era da zona anterior quando o servidor troca de zona (arena do Coliseu, [JOGO-28]): jogadores,
## NPCs, baús, alvo e o relógio de chegada (cada zona tem o seu tick). Não avisa ninguém: a cena da zona vai ser
## trocada no [signal joined_zone].
func _reset_zone_state() -> void:
	_players.clear()
	_npcs.clear()
	chests.clear()
	_group_far.clear()
	casting_target = ""
	casting_remaining = 0.0
	_arrival_offsets.clear()
	_input_sent_usec.clear()
	interpolation_delay_ticks = START_INTERPOLATION_TICKS
	_target_delay_ticks = START_INTERPOLATION_TICKS


func _on_closed() -> void:
	var code: int = _socket.get_close_code()
	var reason: String = _socket.get_close_reason()
	var was_open: bool = _was_open
	_socket = null
	_was_open = false
	_authenticated = false
	_in_zone = false
	_pending_auth = {}
	player_id = ""
	username = ""
	body = ""
	inventory = null
	group = null
	_group_far.clear()
	friends = FriendList.new()
	social_friend_requests = Protocol.SOCIAL_ALWAYS
	social_group_invites = Protocol.SOCIAL_ALWAYS
	social_profile = Protocol.PROFILE_PUBLIC
	social_guild_invites = Protocol.SOCIAL_ALWAYS
	social_trade_requests = Protocol.SOCIAL_ALWAYS
	guild = null
	premium = null
	zone_kind = ZONE_KIND_ZONE
	colosseum_state = null
	_npcs.clear()
	chests.clear()
	set_process(false)

	for id: String in _players.keys():
		_remove_player(id)

	if _update_version != 0:
		# Pacote novo: nada de voltar ao login. O LiveUpdater tira este Network da árvore, baixa o pacote, carrega e
		# reabre o jogo (que entra direto com a sessão salva).
		_update_version = 0
		last_error = ""
		get_tree().change_scene_to_file(LIVE_UPDATER_SCENE)
		return
	if not was_open:
		_fail_connection(code, "Não foi possível conectar ao servidor.")
		return
	if code == Protocol.CLOSE_REPLACED:
		last_error = "Sua conta entrou em outro aparelho."
		should_reconnect = false
	elif code != 1000:
		# Caiu sem pedir (servidor reiniciou, Wi-Fi): a tela de login reconecta sozinha.
		should_reconnect = has_saved_session()
	if code != Protocol.CLOSE_REPLACED and last_error.is_empty() and code != 1000:
		var now: int = Time.get_ticks_msec()
		last_error = "Conexão perdida (código %d). Último dado há %.1f s; pior quadro %d ms (há %.0f s)." % [
			code, (now - _last_packet_ms) / 1000.0, _worst_frame_ms, (now - _worst_frame_at_ms) / 1000.0]
		print("[rede] ", last_error)
	left_zone.emit(code, reason)


func _fail_connection(code: int, message: String) -> void:
	last_error = message
	connection_error.emit(code, message)
