class_name Protocol
extends RefCounted
## Contrato de rede cliente ↔ servidor (constantes e leitura tipada do JSON).
##
## Transporte: WebSocket, um objeto JSON por mensagem de texto: { "type": String, "data": Dictionary }.
## Posições em metros, rotações em radianos.
## Fluxo: conectar → register/login/resume → auth_ok → join → welcome → input/snapshot.
##
## ATENÇÃO: espelho de mmo-server/src/net/protocol.ts (e das regras de conta em
## mmo-server/src/accounts/credentials.ts). Mudou lá → mude aqui e atualize mmo-docs [INFRA-04], [INFRA-07].

## Versão do protocolo enviada ao autenticar. Precisa ser igual a PROTOCOL_VERSION do servidor.
## v17: [constant MSG_GROUP_POSITIONS] (membros do grupo longe, para o mapa, [SOC-03]).
## v18: [code]tauntSeconds[/code] no AbilityView do inventário (Desafio do cavaleiro provoca os monstros, [JOGO-14]).
## v19: [constant MSG_BAG_MOVE], [code]index[/code] no [constant MSG_UNEQUIP] (arrastar no Inventário, [CLI-10]) e
## [code]gold[/code] no [code]me[/code] do snapshot (moedas, [JOGO-15]).
## v20: ferreiro ([JOGO-16]): [constant MSG_UPGRADE] / [constant MSG_UPGRADE_RESULT], nível e atributos no ItemView,
## [code]service[/code] no NpcSnapshot e [code]crit[/code] no evento de dano.
## v21: [code]levels[/code] (nível de melhoria das peças) no PlayerInfo e no evento [code]look[/code]: brilho ([JOGO-17]).
## v22: snapshot por diferença ([INFRA-11]): cada entrada traz só os campos que mudaram, [code]gone[/code] lista
## quem saiu da vista, [code]me[/code] parcial; posição em cm; eventos só de perto; limite da multidão.
## v23: baús dos acampamentos ([JOGO-19]): [code]chests[/code] no welcome, evento [code]chest[/code],
## [constant MSG_CHEST_OPEN] / [constant MSG_CHEST_TAKE] / [constant MSG_CHEST_LOOT].
## v24: fusão no ferreiro ([JOGO-20]): [constant MSG_FUSE] / [constant MSG_FUSE_RESULT], xp/xpNext/fusionXp no item.
## v25: tela de morte ([JOGO-21]): [constant MSG_DEATH_REPORT] e [constant MSG_RESPAWN].
## v26: PvP ([JOGO-22]): [code]levelsLost[/code] no [constant MSG_DEATH_REPORT].
## v27: recuperar senha ([INFRA-13]): [constant MSG_PASSWORD_RESET_REQUEST]/[constant MSG_PASSWORD_RESET_CONFIRM].
## v28: acampamentos ([JOGO-19]): [code]resetIn[/code] (segundos até o acampamento voltar) no baú do welcome e no
## evento [code]chest[/code], que também vem quando o relógio começa/muda/para (mapa, [CLI-11]).
## v29: perfil ([SOC-08]): [code]profile[/code] ([constant PROFILE_PUBLIC]/[constant PROFILE_FRIENDS]/
## [constant PROFILE_NOBODY]) na Configuração social; [constant MSG_ATTRIBUTES] traz [code]stats[/code] ou, perfil
## fechado, só [code]hidden: true[/code].
## v30: guilda ([SOC-06]): [constant MSG_GUILD_CREATE] etc. → [constant MSG_GUILD] / [constant MSG_GUILD_INVITED] /
## [constant MSG_GUILD_NOTICE]; [constant MSG_PLAYER_GUILD]; guildId/guildTag no PlayerInfo; guildInvites na
## Configuração social.
## v31: rankings ([SOC-07]): [constant MSG_RANKING_REQUEST] → [constant MSG_RANKING].
## v32: Procurar guilda e solicitações ([SOC-06]): [constant MSG_GUILD_LIST], [constant MSG_GUILD_INFO],
## [constant MSG_GUILD_REQUEST], [constant MSG_GUILD_REQUEST_ANSWER], [constant MSG_GUILD_DESCRIPTION].
## v33: busca no Procurar guilda: [constant MSG_GUILD_LIST] com { query } (nome ou tag; acha também as cheias).
const VERSION: int = 33

# --- Cliente → servidor ---
## Cria conta. data: { version, client, username, email, password }. As três mensagens de autenticação levam
## [code]client: { platform, pack }[/code] = o pacote do jogo em uso ([PackInfo]; pack 0 = dev), v16, [INFRA-08].
const MSG_REGISTER: String = "register"
## Entra com username OU e-mail + senha. data: { version, login, password }.
const MSG_LOGIN: String = "login"
## Entra com o token de sessão salvo no aparelho. data: { version, sessionToken }.
const MSG_RESUME: String = "resume"
## Encerra a sessão deste aparelho e fecha a conexão. data: {}.
const MSG_LOGOUT: String = "logout"
## Esqueci a senha ([INFRA-13]): manda um código para o e-mail da conta. data: { version, client, login (username ou
## e-mail) }. Resposta: sempre [constant MSG_PASSWORD_RESET_SENT] (não diz se a conta existe).
## ATENÇÃO: ClientMessageType.PasswordResetRequest em mmo-server/src/net/protocol.ts.
const MSG_PASSWORD_RESET_REQUEST: String = "password_reset_request"
## Troca a senha com o código do e-mail. data: { version, client, login, code, password }. Resposta:
## [constant MSG_PASSWORD_RESET_DONE] ou erro [code]invalid_reset_code[/code] / [code]invalid_password[/code].
const MSG_PASSWORD_RESET_CONFIRM: String = "password_reset_confirm"
## Sinal de vida do celular parado ([INFRA-12]): vazio, a cada ~100 ms sem outros envios, para o Wi-Fi do Android não
## entrar em economia de energia. ATENÇÃO: ClientMessageType.KeepAlive em mmo-server/src/net/protocol.ts.
const MSG_KEEP_ALIVE: String = "ka"
## Pede para entrar numa zona (depois de autenticar). data: { zone: String }.
const MSG_JOIN: String = "join"
## Escolhe o corpo do personagem, uma vez só (primeira entrada). data: { body: [constant BODY_MALE] |
## [constant BODY_FEMALE] }. Resposta: [constant MSG_BODY_CHOSEN]. Ver mmo-docs [INFRA-07].
const MSG_CHOOSE_BODY: String = "choose_body"
## Corpos de personagem. ATENÇÃO: espelho de BODY_TYPES em mmo-server/src/net/protocol.ts.
const BODY_MALE: String = "male"
const BODY_FEMALE: String = "female"
## Corpo de monstro (só NPC; nenhum jogador escolhe). ATENÇÃO: NPC_BODY_TYPES em mmo-server/src/net/protocol.ts.
const BODY_ZOMBIE: String = "zombie"
## Intenção de movimento de UM tick (o servidor simula; o cliente não manda posição).
## data: { seq: int crescente, x, z: direção no mundo, comprimento até 1 }. Ver mmo-docs [INFRA-09].
const MSG_INPUT: String = "input"
## Veste um item da mochila (o do slot volta para a mochila). data: { uid }. Ver mmo-docs [JOGO-04].
const MSG_EQUIP: String = "equip"
## Tira o item do slot para a mochila. data: { slot: "hand" | "head" | "chest" | "feet", index?: vaga da mochila onde
## foi solto (sem = no fim) }.
const MSG_UNEQUIP: String = "unequip"
## Organiza a mochila: troca o item da vaga [code]from[/code] com o da vaga [code]to[/code] (vaga livre = vai para o
## fim). data: { from: int, to: int }. Ver mmo-docs [JOGO-04], [CLI-10].
const MSG_BAG_MOVE: String = "bag_move"
## Tenta melhorar um item no ferreiro (perto dele, com moedas). data: { uid, attribute: id de [ItemAttributes] }.
## Resposta: [constant MSG_UPGRADE_RESULT] (+ inventário se subiu) ou erro (not_enough_gold, too_far...). [JOGO-16]
const MSG_UPGRADE: String = "upgrade"
## Abre o baú de um acampamento (perto e aberto): {chestId}. Resposta: [constant MSG_CHEST_LOOT] ou erro. [JOGO-19]
## ATENÇÃO: ClientMessageType.ChestOpen em mmo-server/src/net/protocol.ts.
const MSG_CHEST_OPEN: String = "chest_open"
## Funde no ferreiro um item da mochila em outro igual: {targetUid, materialUid}. Resposta: [constant MSG_FUSE_RESULT]
## + inventário, ou erro (not_same_item, material_equipped, too_far). [JOGO-20]
const MSG_FUSE: String = "fuse"
## Tela de morte → "Renascer": renasce no spawn agora (sem payload). [JOGO-21]
const MSG_RESPAWN: String = "respawn"
## Pega um item/moedas do baú: {chestId, lootId}. Resposta: [constant MSG_CHEST_LOOT] atualizado (+ inventário se item).
const MSG_CHEST_TAKE: String = "chest_take"
## Fixa (ou limpa, com null) o alvo do ataque simples; o servidor bate sozinho quando em alcance.
## data: { targetId: String ou null }. Ver mmo-docs [JOGO-05].
const MSG_ATTACK: String = "attack"
## Lança uma habilidade vestida. data: { abilityId, targetId?, x?, z?, seq? } (x/z = direção ou ponto, conforme a
## mira; seq = só Investida/Disparada, na MESMA sequência dos inputs). Ver mmo-docs [JOGO-06], [JOGO-07].
const MSG_CAST: String = "cast"
## Pede os atributos de um jogador da zona (Menu → Jogadores Próximos → Atributos). data: { playerId }.
## Resposta: [constant MSG_ATTRIBUTES] ou erro [constant ERR_PLAYER_NOT_FOUND]. Ver mmo-docs [SOC-02].
const MSG_INSPECT: String = "inspect"
## Convida um jogador da zona para o seu grupo (sem grupo, ele nasce quando o outro aceitar; com grupo, só o líder
## convida). data: { playerId }. Ver mmo-docs [SOC-03].
const MSG_GROUP_INVITE: String = "group_invite"
## Responde a um convite recebido ([constant MSG_GROUP_INVITED]). data: { fromId, accept: bool }.
const MSG_GROUP_ANSWER: String = "group_answer"
## Líder expulsa um membro. data: { playerId }.
const MSG_GROUP_KICK: String = "group_kick"
## Sai do grupo. data: {}.
const MSG_GROUP_LEAVE: String = "group_leave"
## Guilda ([SOC-06]). Cria (custa [constant GUILD_CREATE_COST] moedas, vira líder). data: { name, tag, description }.
const MSG_GUILD_CREATE: String = "guild_create"
## Convida um jogador online para a minha guilda (líder/oficial). data: { playerId }.
const MSG_GUILD_INVITE: String = "guild_invite"
## Responde a um convite de guilda ([constant MSG_GUILD_INVITED]). data: { fromId, accept: bool }.
const MSG_GUILD_ANSWER: String = "guild_answer"
## Sai da guilda (1 h sem aceitar convite de outra). data: {}.
const MSG_GUILD_LEAVE: String = "guild_leave"
## Expulsa um membro (líder: qualquer um; oficial: só membro comum). data: { playerId }.
const MSG_GUILD_KICK: String = "guild_kick"
## Líder muda o cargo de um membro. data: { playerId, role: [constant GuildState.ROLE_OFFICER] | ROLE_MEMBER }.
const MSG_GUILD_ROLE: String = "guild_role"
## Pede uma tabela de ranking ([SOC-07]). data: { category, period } ([RankingData] CATEGORY_* / PERIOD_*).
const MSG_RANKING_REQUEST: String = "ranking_request"
## Procurar guilda: pede a lista (data { query }: vazio = as que não estão cheias; com texto = busca por nome/tag, cheias
## incluídas); a resposta vem com o mesmo nome: { query, guilds: Array[{ id, name, tag, members }] } (da mais cheia para
## a mais vazia). Lido por [GuildState.Summary].
const MSG_GUILD_LIST: String = "guild_list"
## Ficha de uma guilda: pede com { guildId }; a resposta (mesmo nome) traz { id, name, tag, description, leaderName,
## members, createdAt (ms), monsterXp, kills, requested }. Lido por [GuildState.Info].
const MSG_GUILD_INFO: String = "guild_info"
## Pede para entrar numa guilda (líder/oficial aceita). data: { guildId }.
const MSG_GUILD_REQUEST: String = "guild_request"
## Líder/oficial aceita ou recusa um pedido. data: { playerId, accept }.
const MSG_GUILD_REQUEST_ANSWER: String = "guild_request_answer"
## Líder troca a descrição. data: { description }.
const MSG_GUILD_DESCRIPTION: String = "guild_description"
## Moedas para criar uma guilda. ATENÇÃO: GUILD_CREATE_COST em mmo-server/src/net/protocol.ts.
const GUILD_CREATE_COST: int = 1000
## Pede amizade a um jogador online (ou fake de teste). data: { playerId }. Resposta: aviso [constant MSG_FRIEND_NOTICE]
## (aceitou/recusou/expirou) ou erro. Ver mmo-docs [SOC-04].
const MSG_FRIEND_REQUEST: String = "friend_request"
## Responde a um pedido de amizade recebido ([constant MSG_FRIEND_REQUESTED]). data: { fromId, accept: bool }.
const MSG_FRIEND_ANSWER: String = "friend_answer"
## Desfaz uma amizade (dos dois lados). data: { playerId }.
const MSG_FRIEND_REMOVE: String = "friend_remove"
## Configuração social, nos DOIS sentidos: o cliente manda a mudança, o servidor salva na conta e responde com a
## mesma mensagem (confirmação). data: { friendRequests, groupInvites: [constant SOCIAL_ALWAYS] | [constant SOCIAL_HIDE],
## profile: [constant PROFILE_PUBLIC] | [constant PROFILE_FRIENDS] | [constant PROFILE_NOBODY] }.
const MSG_SOCIAL_SETTINGS: String = "social_settings"
## Opções da Configuração social: mostrar os pedidos/convites, ou recusar sozinho sem mostrar nada.
## ATENÇÃO: espelho de SOCIAL_VISIBILITIES em mmo-server/src/net/protocol.ts.
const SOCIAL_ALWAYS: String = "always"
const SOCIAL_HIDE: String = "hide"
## Quem vê o seu perfil (tela de Atributos, [SOC-08]): todos, só amigos ou ninguém (você sempre vê o seu).
## ATENÇÃO: espelho de PROFILE_VISIBILITIES em mmo-server/src/net/protocol.ts.
const PROFILE_PUBLIC: String = "public"
const PROFILE_FRIENDS: String = "friends"
const PROFILE_NOBODY: String = "nobody"

# --- Servidor → cliente ---
## Autenticação aceita. data: { playerId, username (como foi cadastrado), sessionToken, body ("male" | "female" |
## null = ainda não escolheu: mostrar a escolha antes do join), social: { friendRequests, groupInvites, profile } (Configuração
## social salva na conta, [SOC-04]) }.
const MSG_AUTH_OK: String = "auth_ok"
## Corpo escolhido e salvo (resposta ao [constant MSG_CHOOSE_BODY]). data: { body }.
const MSG_BODY_CHOSEN: String = "body_chosen"
## "Se a conta existe, mandamos o código" ([INFRA-13]). data: {}.
const MSG_PASSWORD_RESET_SENT: String = "password_reset_sent"
## Senha trocada; todas as sessões da conta caíram (entrar com a senha nova). data: {}.
const MSG_PASSWORD_RESET_DONE: String = "password_reset_done"
## Entrada na zona aceita. data: { playerId, zone, tick: int, sim: { tickRate, moveSpeed, zoneHalfSize },
## players: Array[PlayerInfo] } (PlayerInfo = PlayerSnapshot + name + look + body). look = { hand, head, chest, feet:
## itemId ou null } (o que veste; [ART-02]). ATENÇÃO: Look em mmo-server/src/net/protocol.ts.
const MSG_WELCOME: String = "welcome"
## Outro jogador entrou. data: { player: PlayerInfo }.
const MSG_PLAYER_JOINED: String = "player_joined"
## Um jogador saiu. data: { id: String }.
const MSG_PLAYER_LEFT: String = "player_left"
## Estado da zona a cada tick (20 Hz). data: { tick: int, ack: int (último input MEU aplicado),
## players: Array[PlayerSnapshot] (com shield), npcs: Array[NpcSnapshot], events: Array[CombatEvent],
## me: { mana, maxMana, respawnIn, target } }. PlayerSnapshot = { id, x, y, z, rotY, hp, maxHp, dead }.
## CombatEvent = { type: "damage", source, target, amount, absorbed, ability } | { type: "heal", source, target,
## amount, ability } | { type: "impact", source, ability, x, z, radius } | { type: "cast_start", source, ability,
## target, duration, x?, z?, radius?, aim?, release? } (release = s antes do fim em que o tiro sai da mão; [JOGO-08]) | { type: "cast_cancel", source, ability } (andou durante o lançamento:
## sem efeito; habilidade: mana devolvida, recarga zerada; golpe do ataque simples: recomeça quando parar; [JOGO-05]/[JOGO-06]) | { type: "miss", source, target, ability } | { type: "death", id, killer } | { type: "respawn", id }
## | { type: "look", id, look } (trocou o que veste) | { type: "projectile", id, source, ability, x, z, dirX, dirZ,
## speed, range, radius } | { type: "projectile_end", id, x, z } ([JOGO-08]).
## me.casting = { ability, target, remaining } ou null (golpe em andamento).
const MSG_SNAPSHOT: String = "snapshot"
## Inventário completo. data: { equipped: { hand, head, chest, feet: ItemView ou null }, bag: Array[ItemView],
## bagCapacity, unarmedAttack: AbilityView }. ItemView = { uid, itemId, name, slot, basicAttack, abilities }.
const MSG_INVENTORY: String = "inventory"
## Resultado da melhoria no ferreiro. data: { uid, success, cost, attribute, level, points }. ATENÇÃO:
## UpgradeResultData em mmo-server/src/net/protocol.ts. [JOGO-16]
const MSG_UPGRADE_RESULT: String = "upgrade_result"
## O que sobrou para você num baú: {chestId, entries: [{lootId, kind: "item", item: ItemView} | {lootId, kind: "gold",
## amount}]}. [JOGO-19] ATENÇÃO: ChestLootData em mmo-server/src/net/protocol.ts.
const MSG_CHEST_LOOT: String = "chest_loot"
## Resultado da fusão: {uid, levelsGained, xpGained, level, xp, xpNext}. [JOGO-20]
const MSG_FUSE_RESULT: String = "fuse_result"
## Você morreu: {killer, goldLost, xpLost, equipped: [{slot, item}], pickedSlot, broken, autoRespawnSeconds}. [JOGO-21]
## ATENÇÃO: DeathReportData em mmo-server/src/net/protocol.ts.
const MSG_DEATH_REPORT: String = "death_report"
## Atributos de um jogador (resposta ao [constant MSG_INSPECT]). data: { id, name, level, maxHp, maxMana,
## power: { damage, healing, shield } (multiplicadores pelo nível, 1 = nível 0), equipped: { hand, head, chest, feet:
## { itemId, name, set } ou null }, stats: { monsterXp, kills, deaths } ([SOC-08]) }. Perfil fechado para mim:
## só { id, name, level, hidden: true }. ATENÇÃO: AttributesData em mmo-server/src/net/protocol.ts; lido por
## [PlayerAttributes]. Ver mmo-docs [SOC-02].
const MSG_ATTRIBUTES: String = "attributes"
## Estado do MEU grupo, a cada mudança. data: { group: { leaderId, members: Array[{ id, name, level }] } ou null (sem
## grupo) }. Membros na ordem em que entraram (o líder é o primeiro). ATENÇÃO: GroupView em
## mmo-server/src/net/protocol.ts; lido por [GroupState]. Ver mmo-docs [SOC-03].
const MSG_GROUP: String = "group"
## Alguém me convidou para o grupo dele (janela Aceitar/Recusar). data: { fromId, fromName, expiresIn (s) }.
const MSG_GROUP_INVITED: String = "group_invited"
## Aviso pequeno do grupo, pronto para mostrar. data: { code ("accepted" | "rejected" | "expired" | "in_group" |
## "joined" | "left" | "kicked" | "leader" | "disbanded"), name, message }.
const MSG_GROUP_NOTICE: String = "group_notice"
## A MINHA guilda ([SOC-06]), após o auth_ok e a cada mudança. data: { guild: { id, name, tag, members: Array[{ id, name,
## role, online, level (ou null) }] } ou null }. ATENÇÃO: GuildView em mmo-server/src/net/protocol.ts; lido por
## [GuildState].
const MSG_GUILD: String = "guild"
## Alguém me convidou para a guilda dele. data: { fromId, fromName, guildName, guildTag, expiresIn (s) }.
const MSG_GUILD_INVITED: String = "guild_invited"
## Aviso pequeno da guilda, pronto para mostrar. data: { code, message }.
const MSG_GUILD_NOTICE: String = "guild_notice"
## A guilda de um jogador da zona mudou (tag no nome, cor de guildeiro). data: { id, guildId, guildTag } (null = sem).
const MSG_PLAYER_GUILD: String = "player_guild"
## Uma tabela de ranking ([SOC-07]). data: { category, period, rows: Array[{ rank, id, name, value }], me (ou null),
## resetsIn (s), age (s) }. Lido por [RankingData].
const MSG_RANKING: String = "ranking"
## Onde estão os membros do MEU grupo que ficaram FORA da minha área de interesse (não vêm no snapshot), para o mapa do
## Menu ([CLI-11]). data: { members: Array[{ id, x, z }] } (m, 1 casa decimal). Só para quem está em grupo, a
## [constant GROUP_POSITIONS_HZ] Hz, e só quando há membro longe (v17). ATENÇÃO: GroupPositionsData em
## mmo-server/src/net/protocol.ts. Ver mmo-docs [SOC-03].
const MSG_GROUP_POSITIONS: String = "group_positions"
## Frequência (Hz) de [constant MSG_GROUP_POSITIONS]. ATENÇÃO: GROUP_POSITIONS_HZ em mmo-server/src/net/protocol.ts.
const GROUP_POSITIONS_HZ: float = 2.0
## Minha lista de amigos com online/offline (após o auth_ok, no join e a cada mudança). data: { friends: Array[{ id,
## name, online: bool }] } (online primeiro). ATENÇÃO: FriendView em mmo-server/src/net/protocol.ts; lido por
## [FriendList]. Ver mmo-docs [SOC-04].
const MSG_FRIENDS: String = "friends"
## Alguém pediu minha amizade (janela Aceitar/Recusar). data: { fromId, fromName, expiresIn (s) }.
const MSG_FRIEND_REQUESTED: String = "friend_requested"
## Aviso pequeno de amizade, pronto para mostrar. data: { code ("accepted" | "rejected" | "expired" | "added" |
## "removed"), name, message }.
const MSG_FRIEND_NOTICE: String = "friend_notice"
## Há pacote do jogo mais novo para esta plataforma (no lugar do auth_ok, ou com o jogo aberto quando sai versão
## nova). data: { version: int }. Logo depois o servidor fecha com [constant CLOSE_UPDATE_REQUIRED] e o [Network] abre
## o [LiveUpdater], que baixa e entra de novo sozinho. Ver mmo-docs [INFRA-08].
## ATENÇÃO: contrato ESTÁVEL entre versões do protocolo (UpdateRequired em mmo-server/src/net/protocol.ts).
const MSG_UPDATE_REQUIRED: String = "update_required"
## Pedido recusado ou mensagem inválida. data: { code: String, message: String }.
const MSG_ERROR: String = "error"

## Close code enviado pelo servidor ao recusar a entrada (precedido de uma mensagem "error").
const CLOSE_REJECTED: int = 4000
## Close code do servidor quando a conexão não respondeu ao heartbeat.
const CLOSE_TIMEOUT: int = 4001
## Close code quando a mesma conta entrou por outra conexão (outro aparelho/janela).
const CLOSE_REPLACED: int = 4002
## Close code depois do [constant MSG_UPDATE_REQUIRED] (pacote do jogo desatualizado).
const CLOSE_UPDATE_REQUIRED: int = 4003

## Erro: versão do protocolo diferente da do servidor (fecha a conexão). Fora do dev, o [Network] tenta atualizar
## sozinho ([LiveUpdater]): servidor com protocolo novo quase sempre quer dizer pacote novo publicado.
const ERR_VERSION_MISMATCH: String = "version_mismatch"
## Erro: token de sessão não vale mais (o cliente apaga o token e mostra o formulário).
const ERR_INVALID_SESSION: String = "invalid_session"
## Erro: [constant MSG_INSPECT] de quem não está (mais) na zona.
const ERR_PLAYER_NOT_FOUND: String = "player_not_found"
## Erros dos pedidos de grupo ([SOC-03]); viram aviso na tela (a mensagem vem pronta do servidor).
const ERR_NOT_GROUP_LEADER: String = "not_group_leader"
const ERR_GROUP_FULL: String = "group_full"
const ERR_INVALID_INVITE: String = "invalid_invite"
const ERR_INVITE_NOT_FOUND: String = "invite_not_found"
const ERR_ALREADY_IN_GROUP: String = "already_in_group"
const ERR_NOT_IN_GROUP: String = "not_in_group"
## Erros dos pedidos de amizade ([SOC-04]); viram aviso na tela (a mensagem vem pronta do servidor).
const ERR_INVALID_FRIEND_REQUEST: String = "invalid_friend_request"
const ERR_ALREADY_FRIENDS: String = "already_friends"
const ERR_FRIEND_REQUEST_PENDING: String = "friend_request_pending"
const ERR_FRIEND_REQUEST_NOT_FOUND: String = "friend_request_not_found"
const ERR_FRIEND_LIST_FULL: String = "friend_list_full"
const ERR_NOT_FRIENDS: String = "not_friends"

# --- Regras de conta (só para avisar na hora; quem decide é o servidor) ---
## Username: 3 a 16 caracteres, letras sem acento, números e _. Único sem diferenciar maiúsculas,
## mas exibido exatamente como foi digitado.
const USERNAME_MIN_LENGTH: int = 3
const USERNAME_MAX_LENGTH: int = 16
## Senha: 8 a 72 caracteres.
const PASSWORD_MIN_LENGTH: int = 8
const PASSWORD_MAX_LENGTH: int = 72


## Mensagem de erro para o username, ou "" se estiver válido.
static func username_problem(username: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^[A-Za-z0-9_]+$")
	if username.length() < USERNAME_MIN_LENGTH or username.length() > USERNAME_MAX_LENGTH or regex.search(username) == null:
		return "Username deve ter de %d a %d caracteres: letras, números ou _." % [USERNAME_MIN_LENGTH, USERNAME_MAX_LENGTH]
	return ""


## Mensagem de erro para o e-mail, ou "" se estiver válido.
static func email_problem(email: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	return "" if regex.search(email) != null else "E-mail inválido."


## Mensagem de erro para a senha, ou "" se estiver válida.
static func password_problem(password: String) -> String:
	if password.length() < PASSWORD_MIN_LENGTH or password.length() > PASSWORD_MAX_LENGTH:
		return "A senha deve ter de %d a %d caracteres." % [PASSWORD_MIN_LENGTH, PASSWORD_MAX_LENGTH]
	return ""


## Monta o texto de uma mensagem para enviar.
## full_precision: os números vão com todos os dígitos, para o servidor simular com o MESMO
## double que o cliente usou na predição.
static func encode(type: String, data: Dictionary) -> String:
	return JSON.stringify({"type": type, "data": data}, "", true, true)


## Decodifica uma mensagem recebida. Retorna { "type": String, "data": Dictionary },
## ou um Dictionary vazio se o texto não estiver no formato do protocolo.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var message: Dictionary = parsed
	var type: Variant = message.get("type")
	var data: Variant = message.get("data")
	if not type is String or not data is Dictionary:
		return {}
	return message


## Lê um número de [param data]; retorna [param fallback] se faltar ou não for número.
## (JSON no Godot entrega todo número como float.)
static func read_float(data: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value: Variant = data.get(key)
	if value is float or value is int:
		var number: float = value
		return number
	return fallback


## Lê um inteiro de [param data] (JSON entrega float); retorna [param fallback] se não for número inteiro.
static func read_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = data.get(key)
	if value is int:
		var whole: int = value
		return whole
	if value is float:
		var number: float = value
		if number == floorf(number):
			return int(number)
	return fallback


## Lê uma String de [param data]; retorna "" se faltar ou tiver outro tipo.
static func read_string(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key)
	if value is String:
		var text: String = value
		return text
	return ""


## Lê um Dictionary de [param data]; retorna {} se faltar ou tiver outro tipo.
static func read_dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	if value is Dictionary:
		var dict: Dictionary = value
		return dict
	return {}


## Lê uma lista de objetos de [param data], descartando o que não for Dictionary.
static func read_dict_array(data: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = data.get(key)
	if not value is Array:
		return result
	var items: Array = value
	for item: Variant in items:
		if item is Dictionary:
			var dict: Dictionary = item
			result.append(dict)
	return result


## true se [param data] é um PlayerSnapshot válido: { id: String, x, y, z, rotY: number }.
static func is_player_snapshot(data: Dictionary) -> bool:
	if read_string(data, "id").is_empty():
		return false
	for key: String in ["x", "y", "z", "rotY"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int):
			return false
	return true
