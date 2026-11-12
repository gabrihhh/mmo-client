extends SceneTree
## Grava os monstros da cena res://scenes/world/zone_1_monsters.tscn no arquivo do servidor sem abrir o editor
## ([MUN-05]; o normal é salvar a cena no editor, que faz o mesmo).
##   godot --headless --path . --script res://tools/world/save_monsters.gd


func _initialize() -> void:
	var root: MonsterSpawns = (load("res://scenes/world/zone_1_monsters.tscn") as PackedScene).instantiate() as MonsterSpawns
	get_root().add_child(root)
	root.save_to_server()
	quit()
