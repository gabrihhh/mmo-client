extends SceneTree
## Gera os modelos placeholder (.glb) em assets/placeholders/ ([ART-02]).
##
## Rodar da pasta mmo-client:
##   godot --headless --path . --script res://tools/placeholders/make_placeholders.gd
##
## Placeholder novo: escreva uma função `_make_<nome>() -> LowPolyBuilder` com as formas e
## adicione em [constant _MODELS]. Medidas em metros; Y para cima; frente em +Z.
## Itens de segurar: origem no meio do cabo (onde a mão fecha) e comprimento ao longo de +Y.
## Itens de cabeça: origem no centro da base (assenta no topo da cabeça).

## Onde os .glb são gravados.
const OUTPUT_DIR: String = "res://assets/placeholders"

## Nome do arquivo (sem .glb) → função que monta o modelo.
const _MODELS: Array[String] = ["sword", "staff", "cap", "dummy"]

const _STEEL: Color = Color(0.72, 0.75, 0.8)
const _DARK_STEEL: Color = Color(0.35, 0.37, 0.42)
const _WOOD: Color = Color(0.45, 0.3, 0.17)
const _CRYSTAL: Color = Color(0.3, 0.8, 1.0)
const _CLOTH: Color = Color(0.75, 0.2, 0.2)
const _GOLD: Color = Color(0.9, 0.72, 0.25)
const _BURLAP: Color = Color(0.78, 0.66, 0.45)
const _ROPE: Color = Color(0.55, 0.4, 0.25)
const _DARK_WOOD: Color = Color(0.32, 0.22, 0.13)
const _TARGET_RED: Color = Color(0.8, 0.15, 0.12)
const _WHITE: Color = Color(0.95, 0.95, 0.9)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failed: bool = false
	for model_name: String in _MODELS:
		var builder: LowPolyBuilder = call("_make_" + model_name)
		failed = not _export(model_name, builder) or failed
	quit(1 if failed else 0)


## Espada (~1 m): pomo, cabo, guarda e lâmina com ponta. Origem no meio do cabo.
func _make_sword() -> LowPolyBuilder:
	var b: LowPolyBuilder = LowPolyBuilder.new()
	b.gem(Vector3(0.0, -0.12, 0.0), 0.025, 0.025, 6, _GOLD)          # pomo
	b.prism(6, 0.016, 0.016, -0.095, 0.095, _WOOD)                  # cabo (19 cm)
	b.box(Vector3(0.0, 0.11, 0.0), Vector3(0.22, 0.03, 0.045), _DARK_STEEL)  # guarda
	var blade_section: Vector2 = Vector2(1.0, 0.25)                 # seção de losango achatado
	b.prism(4, 0.03, 0.03, 0.125, 0.74, _STEEL, blade_section)      # lâmina
	b.prism(4, 0.03, 0.0, 0.74, 0.84, _STEEL, blade_section)        # ponta
	return b


## Cajado (~1,6 m): ponteira, haste de madeira e cristal no topo. Origem onde a mão segura.
func _make_staff() -> LowPolyBuilder:
	var b: LowPolyBuilder = LowPolyBuilder.new()
	b.prism(6, 0.026, 0.026, -0.42, -0.37, _DARK_STEEL)             # ponteira
	b.prism(6, 0.022, 0.018, -0.4, 0.95, _WOOD)                     # haste
	b.prism(6, 0.04, 0.03, 0.95, 1.0, _DARK_STEEL)                  # suporte do cristal
	b.gem(Vector3(0.0, 1.08, 0.0), 0.05, 0.08, 5, _CRYSTAL)         # cristal
	return b


## Boné: cúpula de 8 lados, aba para a frente (+Z) e botão no topo. Origem no centro da base.
func _make_cap() -> LowPolyBuilder:
	var b: LowPolyBuilder = LowPolyBuilder.new()
	b.dome(0.0, 0.105, 8, 3, 0.85, _CLOTH)                          # copa (cabeça ~ 0,1 m de raio)
	b.box(Vector3(0.0, 0.006, 0.125), Vector3(0.17, 0.012, 0.09), _CLOTH)  # aba
	b.gem(Vector3(0.0, 0.092, 0.0), 0.012, 0.006, 6, _CLOTH)        # botão
	return b


## Boneco de treino (~1,7 m): base, poste, saco de palha com alvo no peito (+Z), braços de madeira e cabeça de saco.
## Origem no chão, no centro (o balanço ao apanhar gira em volta da base).
func _make_dummy() -> LowPolyBuilder:
	var b: LowPolyBuilder = LowPolyBuilder.new()
	b.prism(8, 0.32, 0.28, 0.0, 0.08, _DARK_WOOD)                       # base
	b.prism(6, 0.06, 0.06, 0.08, 1.0, _WOOD)                            # poste
	b.prism(8, 0.2, 0.24, 0.75, 1.35, _BURLAP)                          # saco do corpo
	b.prism(8, 0.245, 0.245, 1.0, 1.04, _ROPE)                          # amarração
	b.prism(8, 0.25, 0.25, 1.24, 1.28, _ROPE)
	b.box(Vector3(0.0, 1.25, 0.0), Vector3(0.9, 0.07, 0.07), _WOOD)     # braços
	for x: float in [-0.42, 0.42]:
		b.box(Vector3(x, 1.25, 0.0), Vector3(0.12, 0.11, 0.11), _BURLAP)
	b.prism(6, 0.04, 0.04, 1.35, 1.45, _WOOD)                           # pescoço
	b.gem(Vector3(0.0, 1.56, 0.0), 0.15, 0.14, 8, _BURLAP)              # cabeça
	b.box(Vector3(0.0, 1.12, 0.235), Vector3(0.18, 0.18, 0.02), _TARGET_RED)  # alvo
	b.box(Vector3(0.0, 1.12, 0.245), Vector3(0.09, 0.09, 0.02), _WHITE)
	b.box(Vector3(0.0, 1.12, 0.255), Vector3(0.04, 0.04, 0.02), _TARGET_RED)
	return b


## Grava [param builder] em OUTPUT_DIR/<model_name>.glb. false se falhou.
func _export(model_name: String, builder: LowPolyBuilder) -> bool:
	var root: Node3D = Node3D.new()
	root.name = model_name.to_pascal_case()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = builder.build()
	root.add_child(mesh_instance)
	mesh_instance.owner = root

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var path: String = "%s/%s.glb" % [OUTPUT_DIR, model_name]
	var error: Error = document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	root.free()
	if error != OK:
		push_error("Falhou ao gerar %s: %s" % [path, error_string(error)])
		return false
	print("%s: %d triângulos" % [path, builder.triangle_count()])
	return true
