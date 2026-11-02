class_name LoginScreen
extends Control
## Tela de login/cadastro (primeira tela do jogo, aberta pelo [GameBoot]). Ver mmo-docs [CLI-05], [INFRA-07].
##
## - Com sessão salva no aparelho: entra direto ("Entrando...") sem mostrar o formulário.
## - "Entrar": username OU e-mail + senha.
## - "Criar conta": username (exibido no jogo exatamente como digitado), e-mail, senha e confirmação.
## - "Entrar como convidado" (TESTE): conta gerada pelo cliente e lembrada no aparelho.
## As regras são conferidas aqui para avisar na hora ([Protocol]), mas quem decide é o servidor.
## Autenticou → o [Network] entra na zona sozinho → no [signal Network.joined_zone] abre a zona.
## Se a conexão cair, o jogo volta para cá e mostra [member Network.last_error].

## Cena aberta depois de entrar.
const ZONE_SCENE: String = "res://scenes/world/zone_1.tscn"
## Dev/testes: `-- --dev-user=Nome` entra como Nome (senha [constant DEV_PASSWORD]), criando a conta
## (e-mail nome@dev.local) se não existir. Útil no headless e em várias janelas no mesmo PC.
const DEV_USER_ARG: String = "--dev-user="
const DEV_PASSWORD: String = "dev-password-123"

@onready var _status_label: Label = %StatusLabel
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

## Nome do --dev-user ("" = desligado) e se já tentou criar a conta dele.
var _dev_user: String = ""
var _dev_registering: bool = false
## Cadastro de convidado em andamento: credenciais geradas, salvas só se o servidor aceitar.
var _pending_guest: Dictionary = {}
## Login com as credenciais de convidado salvas em andamento (se falhar, cria outro convidado).
var _guest_login: bool = false


func _ready() -> void:
	if Network.instance == null:
		# Aberta sem passar pelo boot (ex.: F6 no editor): o boot cria o Network e volta para cá.
		get_tree().change_scene_to_file.call_deferred(GameBoot.SCENE)
		return
	var network: Network = Network.instance
	network.joined_zone.connect(_on_joined_zone)
	network.auth_failed.connect(_on_auth_failed)
	network.connection_error.connect(_on_connection_failed)
	network.left_zone.connect(_on_left_zone)

	_login_button.pressed.connect(_on_login_pressed)
	_guest_button.pressed.connect(_on_guest_pressed)
	network.authenticated.connect(_on_authenticated)
	_register_button.pressed.connect(_on_register_pressed)
	_to_register_button.pressed.connect(_show_form.bind(true))
	_to_login_button.pressed.connect(_show_form.bind(false))
	_password_field.text_submitted.connect(func(_text: String) -> void: _on_login_pressed())
	_confirm_field.text_submitted.connect(func(_text: String) -> void: _on_register_pressed())

	_dev_user = _read_dev_user()
	_status_label.text = network.last_error
	_show_form(false)

	# Sessão salva e não voltou por erro: entra direto.
	if network.has_saved_session() and network.last_error.is_empty():
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


## "Entrar como convidado" (TESTE): entra na conta de convidado deste aparelho/perfil, ou cria uma
## com username Convidado_NNNNN, e-mail @convidado.local e senha aleatórios. Ver mmo-docs [CLI-05].
func _on_guest_pressed() -> void:
	var saved: Dictionary = AccountStorage.load_guest_credentials()
	if not saved.is_empty():
		_set_busy("Entrando como convidado...")
		_guest_login = true
		Network.instance.login(Protocol.read_string(saved, "username"), Protocol.read_string(saved, "password"))
		return
	_register_guest()


func _register_guest() -> void:
	var number: int = randi_range(10000, 99999)
	var guest_name: String = "Convidado_%d" % number
	var password: String = "%x%x" % [randi(), randi()]
	_pending_guest = {"username": guest_name, "password": password}
	_set_busy("Criando convidado...")
	Network.instance.register(guest_name, "%s@convidado.local" % guest_name.to_lower(), password)


func _on_authenticated(_username: String) -> void:
	_guest_login = false
	if not _pending_guest.is_empty():
		AccountStorage.save_guest_credentials(Protocol.read_string(_pending_guest, "username"), Protocol.read_string(_pending_guest, "password"))
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


func _on_joined_zone(_player_id: String) -> void:
	get_tree().change_scene_to_file(ZONE_SCENE)


func _on_auth_failed(code: String, message: String) -> void:
	# Convidado salvo não existe mais no servidor (ex.: banco de dev apagado) → cria outro.
	if _guest_login:
		_guest_login = false
		if code == "invalid_credentials":
			_register_guest()
			return
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
	_show_form(code in ["username_taken", "email_taken", "invalid_username", "invalid_email", "invalid_password"] and _register_form.visible)
	_show_error(message)


func _on_connection_failed(_code: int, _message: String) -> void:
	_show_error(Network.instance.last_error)


func _on_left_zone(_code: int, _reason: String) -> void:
	_show_error(Network.instance.last_error)


## Mostra o formulário de cadastro ([param register] = true) ou o de entrar.
func _show_form(register: bool) -> void:
	_register_form.visible = register
	_login_form.visible = not register
	_set_enabled(true)


func _show_error(message: String) -> void:
	_status_label.text = message
	if not _register_form.visible and not _login_form.visible:
		_login_form.visible = true
	_set_enabled(true)


## Esconde os formulários e mostra só a mensagem (entrando/criando conta).
func _set_busy(message: String) -> void:
	_status_label.text = message
	_set_enabled(false)


## Botões ativos só quando não há pedido em andamento (evita mandar duas vezes).
func _set_enabled(enabled: bool) -> void:
	for button: Button in [_login_button, _register_button, _to_register_button, _to_login_button, _guest_button]:
		button.disabled = not enabled


func _read_dev_user() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_USER_ARG):
			return arg.trim_prefix(DEV_USER_ARG)
	return ""
