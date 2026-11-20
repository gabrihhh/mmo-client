class_name LoginScreen
extends Control
## Tela de login/cadastro (primeira tela do jogo, aberta pelo [GameBoot]). Ver mmo-docs [CLI-05], [INFRA-07].
##
## - Com sessão salva no aparelho: entra direto ("Entrando...") sem mostrar o formulário.
## - "Entrar": username OU e-mail + senha.
## - "Criar conta": username (exibido no jogo exatamente como digitado), e-mail, senha e confirmação.
## - "Entrar como convidado" (TESTE): cada toque cria uma conta NOVA, com dados gerados pelo cliente.
## - "Esqueci a senha" ([INFRA-13]): usuário/e-mail → código no e-mail → código + senha nova → entra com ela.
## As regras são conferidas aqui para avisar na hora ([Protocol]), mas quem decide é o servidor.
## Esperando o servidor ("Entrando...", "Criando conta..."): os campos e botões SOMEM e fica só a mensagem com o
## carregando pixel art ([PixelLoader]); erro → volta o formulário de onde veio. Visual pixel art: [CLI-05].
## Autenticou → o [Network] entra na zona sozinho → no [signal Network.joined_zone] abre a zona. Conta que ainda não
## escolheu o corpo ([signal Network.body_choice_needed]) vai antes para a escolha de personagem ([CharacterSelect]).
## Se a conexão cair, o jogo volta para cá e mostra [member Network.last_error].

## Escolha de personagem (primeira entrada da conta).
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
## Dev/testes: `-- --body=female` escolhe o corpo sozinho quando a conta do --dev-user ainda não tem (padrão: male).
const DEV_BODY_ARG: String = "--body="
## Dev/testes: `-- --weapon=knight_sword` escolhe também a arma inicial (padrão: nenhuma), [CLI-09].
const DEV_WEAPON_ARG: String = "--weapon="
## Dev/testes: `-- --dev-user=Nome` entra como Nome (senha [constant DEV_PASSWORD]), criando a conta
## (e-mail nome@dev.local) se não existir. Útil no headless e em várias janelas no mesmo PC.
const DEV_USER_ARG: String = "--dev-user="
const DEV_PASSWORD: String = "dev-password-123"

## Reconexão automática depois de queda ([member Network.should_reconnect]): espera antes de cada tentativa (s),
## dobrando de [constant RECONNECT_FIRST_SECONDS] até [constant RECONNECT_MAX_SECONDS]; tenta para sempre enquanto o app
## está aberto (servidor reiniciando volta sozinho). Versão nova no servidor → o atualizador assume ([INFRA-08]).
const RECONNECT_FIRST_SECONDS: float = 1.0
const RECONNECT_MAX_SECONDS: float = 8.0
var _reconnect_attempt: int = 0
var _reconnect_timer: SceneTreeTimer = null

@onready var _status_label: Label = %StatusLabel
## Carregando pixel art, visível só enquanto espera o servidor.
@onready var _loader: PixelLoader = %Loader
@onready var _login_form: Control = %LoginForm
@onready var _login_field: LineEdit = %LoginField
@onready var _password_field: LineEdit = %PasswordField
@onready var _login_button: Button = %LoginButton
@onready var _to_register_button: Button = %ToRegisterButton
@onready var _guest_button: Button = %GuestButton
@onready var _register_form: Control = %RegisterForm
@onready var _username_field: LineEdit = %UsernameField
@onready var _email_field: LineEdit = %EmailField
@onready var _new_password_field: LineEdit = %NewPasswordField
@onready var _confirm_field: LineEdit = %ConfirmField
@onready var _register_button: Button = %RegisterButton
@onready var _to_login_button: Button = %ToLoginButton
@onready var _forgot_button: Button = %ForgotButton
## Esqueci a senha: 1ª etapa (usuário/e-mail) e 2ª ([member _reset_code_step]: código + senha nova).
@onready var _reset_form: Control = %ResetForm
@onready var _reset_login_field: LineEdit = %ResetLoginField
@onready var _reset_send_button: Button = %ResetSendButton
@onready var _reset_code_step: Control = %ResetCodeStep
@onready var _reset_code_field: LineEdit = %ResetCodeField
@onready var _reset_password_field: LineEdit = %ResetPasswordField
@onready var _reset_confirm_field: LineEdit = %ResetConfirmField
@onready var _reset_confirm_button: Button = %ResetConfirmButton
@onready var _reset_resend_button: Button = %ResetResendButton
@onready var _reset_back_button: Button = %ResetBackButton

## Formulários da tela.
const FORM_LOGIN: String = "login"
const FORM_REGISTER: String = "register"
const FORM_RESET: String = "reset"

## Nome do --dev-user ("" = desligado) e se já tentou criar a conta dele.
var _dev_user: String = ""
var _dev_registering: bool = false
## Cadastro de convidado em andamento (se o nome sorteado já existir, sorteia outro).
var _pending_guest: Dictionary = {}
## Formulário em uso ([constant FORM_LOGIN], [constant FORM_REGISTER], [constant FORM_RESET]): é o que volta depois de
## um erro.
var _form: String = FORM_LOGIN
## Esqueci a senha: o código já foi pedido (mostra a 2ª etapa) e a senha nova, para entrar com ela no fim.
var _reset_code_sent: bool = false
var _reset_new_password: String = ""


func _ready() -> void:
	if Network.instance == null:
		# Aberta sem passar pelo boot (ex.: F6 no editor): o boot cria o Network e volta para cá.
		get_tree().change_scene_to_file.call_deferred(GameBoot.SCENE)
		return
	var network: Network = Network.instance
	network.joined_zone.connect(_on_joined_zone)
	network.body_choice_needed.connect(_on_body_choice_needed)
	network.auth_failed.connect(_on_auth_failed)
	network.connection_error.connect(_on_connection_failed)
	network.left_zone.connect(_on_left_zone)

	_login_button.pressed.connect(_on_login_pressed)
	_guest_button.pressed.connect(_on_guest_pressed)
	network.authenticated.connect(_on_authenticated)
	_register_button.pressed.connect(_on_register_pressed)
	_to_register_button.pressed.connect(_show_form.bind(FORM_REGISTER))
	_to_login_button.pressed.connect(_show_form.bind(FORM_LOGIN))
	_forgot_button.pressed.connect(_on_forgot_pressed)
	_reset_back_button.pressed.connect(_show_form.bind(FORM_LOGIN))
	_reset_send_button.pressed.connect(_on_reset_send_pressed)
	_reset_resend_button.pressed.connect(_on_reset_send_pressed)
	_reset_confirm_button.pressed.connect(_on_reset_confirm_pressed)
	_reset_confirm_field.text_submitted.connect(func(_text: String) -> void: _on_reset_confirm_pressed())
	network.password_reset_sent.connect(_on_reset_sent)
	network.password_reset_done.connect(_on_reset_done)
	_password_field.text_submitted.connect(func(_text: String) -> void: _on_login_pressed())
	_confirm_field.text_submitted.connect(func(_text: String) -> void: _on_register_pressed())

	_dev_user = _read_dev_user()
	_status_label.text = network.last_error
	_show_form(FORM_LOGIN)

	# Caiu sem pedir (servidor reiniciou, Wi-Fi piscou): reconecta sozinho com a sessão salva.
	if network.should_reconnect and network.has_saved_session():
		_schedule_reconnect()
	# Sessão salva e não voltou por erro: entra direto.
	elif network.has_saved_session() and network.last_error.is_empty():
		_set_busy("Entrando...")
		network.resume_session()
	elif not _dev_user.is_empty() and network.last_error.is_empty():
		_set_busy("Entrando como %s (dev)..." % _dev_user)
		network.login(_dev_user, DEV_PASSWORD)


func _on_login_pressed() -> void:
	var login_name: String = _login_field.text.strip_edges()
	if login_name.is_empty() or _password_field.text.is_empty():
		_show_error("Preencha usuário/e-mail e senha.")
		return
	_set_busy("Entrando...")
	Network.instance.login(login_name, _password_field.text)


## "Entrar como convidado" (TESTE): cada toque cria uma conta nova (username Convidado_NNNNN, e-mail
## @convidado.local e senha aleatórios; nada é guardado). Ver mmo-docs [CLI-05].
func _on_guest_pressed() -> void:
	_register_guest()


func _register_guest() -> void:
	var number: int = randi_range(10000, 99999)
	var guest_name: String = "Convidado_%d" % number
	var password: String = "%x%x" % [randi(), randi()]
	_pending_guest = {"username": guest_name, "password": password}
	_set_busy("Criando convidado...")
	Network.instance.register(guest_name, "%s@convidado.local" % guest_name.to_lower(), password)


func _on_authenticated(_username: String) -> void:
	_pending_guest = {}


func _on_register_pressed() -> void:
	var new_username: String = _username_field.text.strip_edges()
	var problem: String = Protocol.username_problem(new_username)
	if problem.is_empty():
		problem = Protocol.email_problem(_email_field.text.strip_edges())
	if problem.is_empty():
		problem = Protocol.password_problem(_new_password_field.text)
	if problem.is_empty() and _new_password_field.text != _confirm_field.text:
		problem = "As senhas não conferem."
	if not problem.is_empty():
		_show_error(problem)
		return
	_set_busy("Criando conta...")
	Network.instance.register(new_username, _email_field.text, _new_password_field.text)


## "Esqueci a senha": abre a 1ª etapa já com o que estava digitado em usuário/e-mail.
func _on_forgot_pressed() -> void:
	_reset_code_sent = false
	_reset_login_field.text = _login_field.text.strip_edges()
	_status_label.text = "Digite o usuário ou e-mail da conta: mandamos um código para o e-mail dela."
	_show_form(FORM_RESET)


## Pede o código (ou de novo, pelo "Enviar de novo").
func _on_reset_send_pressed() -> void:
	if _reset_login_field.text.strip_edges().is_empty():
		_show_error("Digite o usuário ou e-mail da conta.")
		return
	_set_busy("Enviando código...")
	Network.instance.request_password_reset(_reset_login_field.text)


## O servidor recebeu o pedido: mostra a 2ª etapa (código + senha nova). Não diz se a conta existe.
func _on_reset_sent() -> void:
	_reset_code_sent = true
	_status_label.text = "Se a conta existe, mandamos um código para o e-mail dela (vale 15 minutos). Olhe também o spam."
	_show_form(FORM_RESET)
	_reset_code_field.grab_focus()


func _on_reset_confirm_pressed() -> void:
	var code: String = _reset_code_field.text.strip_edges()
	var problem: String = "" if code.length() == 6 and code.is_valid_int() else "O código tem 6 números."
	if problem.is_empty():
		problem = Protocol.password_problem(_reset_password_field.text)
	if problem.is_empty() and _reset_password_field.text != _reset_confirm_field.text:
		problem = "As senhas não conferem."
	if not problem.is_empty():
		_show_error(problem)
		return
	_reset_new_password = _reset_password_field.text
	_set_busy("Trocando a senha...")
	Network.instance.confirm_password_reset(_reset_login_field.text, code, _reset_new_password)


## Senha trocada: entra direto com ela (na mesma conexão).
func _on_reset_done() -> void:
	var login_name: String = _reset_login_field.text.strip_edges()
	_login_field.text = login_name
	_password_field.text = ""
	_reset_code_field.text = ""
	_reset_password_field.text = ""
	_reset_confirm_field.text = ""
	_reset_code_sent = false
	_form = FORM_LOGIN
	_set_busy("Senha trocada! Entrando...")
	Network.instance.login(login_name, _reset_new_password)
	_reset_new_password = ""


## Primeira entrada da conta: abre a escolha de personagem. Com --dev-user escolhe sozinho (--body=, padrão male).
func _on_body_choice_needed() -> void:
	if not _dev_user.is_empty():
		var dev_body: String = Protocol.BODY_MALE
		var dev_weapon: String = ""
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with(DEV_BODY_ARG):
				dev_body = arg.trim_prefix(DEV_BODY_ARG)
			elif arg.begins_with(DEV_WEAPON_ARG):
				dev_weapon = arg.trim_prefix(DEV_WEAPON_ARG)
		Network.instance.choose_body(dev_body, dev_weapon)
		return
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_joined_zone(_player_id: String) -> void:
	# Dois welcome seguidos (voltou para a arena e a partida acabou na hora): o segundo chega com esta tela já saindo.
	if not is_inside_tree():
		return
	# A zona comum ou, voltando para uma partida em andamento, a arena do Coliseu ([JOGO-28]). A cena aberta confere
	# de novo o tipo da zona ao abrir (Zone._ready).
	get_tree().change_scene_to_file.call_deferred(Network.instance.zone_scene())


func _on_auth_failed(code: String, message: String) -> void:
	# Convidado: o número sorteado já existe → sorteia outro.
	if not _pending_guest.is_empty():
		_pending_guest = {}
		if code == "username_taken" or code == "email_taken":
			_register_guest()
			return
	# --dev-user: a conta ainda não existe → cria uma vez.
	if not _dev_user.is_empty() and code == "invalid_credentials" and not _dev_registering:
		_dev_registering = true
		Network.instance.register(_dev_user, "%s@dev.local" % _dev_user.to_lower(), DEV_PASSWORD)
		return
	# Sessão salva não vale mais: mostra o formulário de entrar.
	if _form == FORM_REGISTER and not code in ["username_taken", "email_taken", "invalid_username", "invalid_email", "invalid_password"]:
		_form = FORM_LOGIN
	elif _form == FORM_RESET and not code in ["invalid_reset_code", "invalid_password"]:
		_form = FORM_LOGIN
	_show_error(message)


func _on_connection_failed(_code: int, _message: String) -> void:
	if Network.instance.should_reconnect:
		_schedule_reconnect()
		return
	_show_error(Network.instance.last_error)


func _on_left_zone(_code: int, _reason: String) -> void:
	if Network.instance.should_reconnect:
		_schedule_reconnect()
		return
	_show_error(Network.instance.last_error)


## Próxima tentativa de reconectar, depois de esperar (1 s, 2 s, 4 s, 8 s, 8 s...). Mostra "Reconectando..." com o
## carregando; os formulários ficam escondidos.
func _schedule_reconnect() -> void:
	var wait: float = minf(RECONNECT_FIRST_SECONDS * pow(2.0, float(_reconnect_attempt)), RECONNECT_MAX_SECONDS)
	_reconnect_attempt += 1
	_set_busy("Conexão perdida — reconectando%s..." % ("" if _reconnect_attempt <= 1 else " (tentativa %d)" % _reconnect_attempt))
	_reconnect_timer = get_tree().create_timer(wait)
	_reconnect_timer.timeout.connect(_try_reconnect)


func _try_reconnect() -> void:
	var network: Network = Network.instance
	if network == null or not network.should_reconnect or not network.has_saved_session():
		_show_error(network.last_error if network != null else "")
		return
	network.resume_session()


## Mostra o formulário [param form] ([constant FORM_LOGIN], [constant FORM_REGISTER] ou [constant FORM_RESET]; no de
## recuperar, a 2ª etapa só depois de pedir o código).
func _show_form(form: String) -> void:
	_form = form
	_register_form.visible = form == FORM_REGISTER
	_login_form.visible = form == FORM_LOGIN
	_reset_form.visible = form == FORM_RESET
	_reset_code_step.visible = _reset_code_sent
	_reset_send_button.visible = not _reset_code_sent
	_reset_login_field.editable = not _reset_code_sent
	_loader.visible = false
	_set_enabled(true)


## Mostra a mensagem de erro e devolve o formulário em uso (some o carregando).
func _show_error(message: String) -> void:
	_status_label.text = message
	_show_form(_form)


## Esconde os formulários (nada para tocar) e mostra só a mensagem com o carregando (entrando/criando conta).
func _set_busy(message: String) -> void:
	_status_label.text = message
	_login_form.visible = false
	_register_form.visible = false
	_reset_form.visible = false
	_loader.visible = true
	# Fecha o teclado do celular, se estava aberto num campo.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_set_enabled(false)


## Botões ativos só quando não há pedido em andamento (evita mandar duas vezes).
func _set_enabled(enabled: bool) -> void:
	for button: Button in [_login_button, _register_button, _to_register_button, _to_login_button, _guest_button,
			_forgot_button, _reset_send_button, _reset_confirm_button, _reset_resend_button, _reset_back_button]:
		button.disabled = not enabled


func _read_dev_user() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_USER_ARG):
			return arg.trim_prefix(DEV_USER_ARG)
	return ""
