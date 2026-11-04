class_name PaperDoll
extends Control
## Área "vestido" do inventário ([CLI-10]): a silhueta de uma pessoa em pixel art e, em cima dela, um quadro
## ([ItemSlot]) por slot: cabeça na cabeça, peito no tronco, pés nos pés e a arma ao lado da mão.
## Tocar num quadro emite [signal slot_pressed] (a HUD abre a ficha do item vestido).

## Tocou no quadro do [param slot] ("hand", "head", "chest", "feet").
signal slot_pressed(slot: String)

## Silhueta em células ("#" = cheio). Desenhada em blocos para combinar com os ícones pixel art.
const SILHOUETTE: Array[String] = [
	"....####....",
	"...######...",
	"...######...",
	"...######...",
	"....####....",
	".....##.....",
	"..########..",
	".##########.",
	".##.####.##.",
	".##.####.##.",
	".##.####.##.",
	"##..####..##",
	"##..####..##",
	"....####....",
	"....#..#....",
	"...##..##...",
	"...##..##...",
	"...##..##...",
	"...##..##...",
	"..###..###..",
]
## Linha (célula) onde fica o centro do quadro de cada slot; a arma fica ao lado da mão esquerda da silhueta.
const SLOT_ROWS: Dictionary[String, float] = {"head": 2.0, "chest": 9.0, "hand": 11.5, "feet": 17.5}
## Tamanho dos quadros, em px.
const SLOT_SIZE: float = 104.0
## Cor da silhueta e do fundo da vitrine.
const SILHOUETTE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.32)
const BACKGROUND: Color = Color(0.2, 0.13, 0.08, 0.85)

var _slots: Dictionary[String, ItemSlot] = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for slot: String in InventoryState.SLOTS:
		var view: ItemSlot = ItemSlot.new()
		view.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		view.size = view.custom_minimum_size
		view.pressed.connect(slot_pressed.emit.bind(slot))
		add_child(view)
		_slots[slot] = view
	resized.connect(_place_slots)
	_place_slots()


## Mostra o que [param inventory] tem vestido.
func show_inventory(inventory: InventoryState) -> void:
	for slot: String in _slots:
		_slots[slot].show_item(inventory.item_in(slot), AbilityView.SLOT_LABELS[slot])


## Tamanho (px) de uma célula da silhueta para caber na altura atual.
func _cell() -> float:
	return size.y / (float(SILHOUETTE.size()) + 1.0)


## Canto de cima/esquerda da silhueta (centrada na horizontal, meia célula de margem em cima).
func _origin() -> Vector2:
	var cell: float = _cell()
	return Vector2((size.x - float(SILHOUETTE[0].length()) * cell) / 2.0, cell * 0.5)


func _place_slots() -> void:
	var cell: float = _cell()
	var origin: Vector2 = _origin()
	for slot: String in _slots:
		var center: Vector2 = Vector2(size.x / 2.0, origin.y + (SLOT_ROWS[slot] + 0.5) * cell)
		if slot == "hand":
			# Ao lado da mão (esquerda da tela), sem cobrir o tronco.
			center.x = origin.x - SLOT_SIZE * 0.25
		var view: ItemSlot = _slots[slot]
		view.position = center - view.size / 2.0
	queue_redraw()


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.set_corner_radius_all(14)
	box.set_border_width_all(3)
	box.border_color = Color(0.12, 0.07, 0.03, 0.9)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var cell: float = _cell()
	var origin: Vector2 = _origin()
	for row: int in range(SILHOUETTE.size()):
		var line: String = SILHOUETTE[row]
		for column: int in range(line.length()):
			if line[column] == "#":
				draw_rect(Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell)), SILHOUETTE_COLOR)
