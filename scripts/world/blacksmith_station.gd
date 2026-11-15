class_name BlacksmithStation
extends Node3D
## O Ferreiro no mundo ([JOGO-16]): a cena fixa do ferreiro com a fornalha e a bigorna (Meshy, uma peça só) no lugar
## do NPC `blacksmith` do servidor, pousada no chão, com o nome em cima. Não anda, não é alvo nem leva dano; perto
## dele a HUD mostra o botão "Ferreiro" ([Hud], [method Zone._near_blacksmith]).

## Cena do conjunto (escala e origem acertadas na própria cena).
const SCENE: PackedScene = preload("res://assets/props/blacksmith/blacksmith.tscn")
## Giro em Y (graus): 45 = de frente para a câmera isométrica ([CLI-02]); um pouco menos mostra a fornalha de lado.
const FACING_DEGREES: float = 25.0
## Altura (m) do nome acima do chão (acima da chaminé, ~2,7 m).
const NAME_HEIGHT_M: float = 3.0


## Põe a cena no lugar de [param state] (o NPC do servidor), no chão da zona.
func setup(state: PlayerState) -> void:
	name = "Blacksmith_%s" % state.id
	position = Vector3(state.x, ZoneTerrain.height_at(state.x, state.z), state.z)
	rotation_degrees.y = FACING_DEGREES
	add_child(SCENE.instantiate())
	var label: Label3D = Label3D.new()
	label.text = state.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0065
	label.font_size = 40
	label.outline_size = 10
	label.position = Vector3(0.0, NAME_HEIGHT_M, 0.0)
	label.modulate = Color(1.0, 0.85, 0.45)
	add_child(label)
