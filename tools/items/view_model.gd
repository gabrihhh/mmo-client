extends SceneTree
## Foto de conferência de um modelo sozinho (.glb/.tscn): frente, lado, costas, 3/4 e o outro lado, em câmera
## ortográfica, centrado; imprime a caixa (AABB, no espaço do modelo) — serve para medir escala e ver a frente.
## Rodar da pasta mmo-client (precisa de tela):
##   godot --path . --resolution 1800x500 --script res://tools/items/view_model.gd -- <res://modelo.glb> <saida.png>
var _frames: int = 0
var _out: String = ""
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		var args: PackedStringArray = OS.get_cmdline_user_args()
		_out = args[1]
		var scene: Node3D = (load(args[0]) as PackedScene).instantiate() as Node3D
		var aabb: AABB = AABB()
		var first: bool = true
		for mi: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			var b: AABB = m.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
		print("AABB ", aabb)
		var angles: Array[float] = [0.0, 90.0, 180.0, 45.0, -90.0]
		for i: int in range(angles.size()):
			var holder: Node3D = Node3D.new()
			var copy: Node3D = scene.duplicate() as Node3D
			copy.position = -aabb.get_center()
			holder.add_child(copy)
			holder.rotation_degrees.y = angles[i]
			holder.position = Vector3((i - 2) * aabb.size.length() * 0.75, 0, 0)
			root.add_child(holder)
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = aabb.size.length() * 1.2
		cam.position = Vector3(0, 0, 10)
		root.add_child(cam)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, 20, 0)
		root.add_child(light)
		var env: WorldEnvironment = WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.55, 0.75, 0.55)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.6
		root.add_child(env)
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(_out)
		return true
	return false
