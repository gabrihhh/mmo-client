class_name InputActions
extends RefCounted
## Nomes das ações de input e registro do teclado (usado só para testar no desktop).
##
## No celular o movimento vem do [VirtualJoystick]; o teclado é um atalho de desenvolvimento.

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"


## Registra WASD/setas se as ações ainda não existirem. Pode ser chamado várias vezes.
static func register_defaults() -> void:
	_add_keys(MOVE_LEFT, [KEY_A, KEY_LEFT])
	_add_keys(MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_add_keys(MOVE_FORWARD, [KEY_W, KEY_UP])
	_add_keys(MOVE_BACK, [KEY_S, KEY_DOWN])


## Vetor de movimento do teclado: x = direita, y = trás (forward é y negativo).
static func get_keyboard_vector() -> Vector2:
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)


static func _add_keys(action: StringName, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
