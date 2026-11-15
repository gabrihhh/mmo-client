extends SceneTree
func _init() -> void:
	print("set_no_delay: ", ClassDB.class_has_method("WebSocketPeer", "set_no_delay"))
	print("versão: ", Engine.get_version_info().string)
	quit()
