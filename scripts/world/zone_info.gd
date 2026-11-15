class_name ZoneInfo
extends RefCounted
## Zonas de nível e fogueiras da zona 1 ([JOGO-18]), lidas do `zone_1_info.json` que o exportador do mapa grava a
## partir do `spawn.blend` ([ART-10]): `regions` (nome, nível recomendado, contorno, buracos e onde vai o nome) e
## `fires` (centro, tamanho e raio sem flores de cada fogueira).
##
## Usado pelo mapa do Menu ([ZoneMap]: contorno colorido + nome de cada zona), pelo aviso "Entrando em ..." ao trocar
## de zona ([method region_at]) e pelo cenário ([Zone1Scenery]: fogo animado e chão dos acampamentos sem flores).
## Lido uma vez e guardado (estático). Só visual: quem decide nível de monstro é o servidor.
## ATENÇÃO: formato escrito por mmo-client/tools/blender/blender_export_zone.py (read_regions, read_fires).

## Arquivo exportado (importado pelo Godot como recurso JSON).
const INFO_PATH: String = "res://assets/zones/zone_1/zone_1_info.json"


## Uma zona de nível: nome, nível recomendado (de [member min_level] a [member max_level]) e a forma no chão
## (coordenadas do jogo, x e z em metros).
class Region:
	extends RefCounted
	var name: String = ""
	var min_level: int = 0
	var max_level: int = 0
	## Contorno de fora (x, z).
	var outer: PackedVector2Array = PackedVector2Array()
	## Buracos (a Campina tem a praça no meio).
	var holes: Array[PackedVector2Array] = []
	## Onde escrever o nome no mapa (x, z).
	var label: Vector2 = Vector2.ZERO

	## true se o ponto (x, z) está dentro (no contorno e fora dos buracos).
	func contains(point: Vector2) -> bool:
		if not Geometry2D.is_point_in_polygon(point, outer):
			return false
		for hole: PackedVector2Array in holes:
			if Geometry2D.is_point_in_polygon(point, hole):
				return false
		return true

	## "Nome (nv 5-7)".
	func title() -> String:
		return "%s (nv %d-%d)" % [name, min_level, max_level]


## Uma fogueira: centro (x, altura, z em m), tamanho (m) e raio do chão do acampamento em volta (m; 0 = nenhum).
class Fire:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	var size: float = 1.0
	var clear_radius: float = 0.0


static var _loaded: bool = false
static var _regions: Array[Region] = []
static var _fires: Array[Fire] = []


## Todas as zonas de nível (vazio se o arquivo não existir).
static func regions() -> Array[Region]:
	_load()
	return _regions


## Todas as fogueiras.
static func fires() -> Array[Fire]:
	_load()
	return _fires


## Zona de nível onde fica o ponto (x, z) em metros; null = nenhuma (praça, montanhas).
static func region_at(x: float, z: float) -> Region:
	var point: Vector2 = Vector2(x, z)
	for region: Region in regions():
		if region.contains(point):
			return region
	return null


## true se (x, z) cai no chão de algum acampamento (sem flores nem grama ali).
static func is_camp_ground(x: float, z: float) -> bool:
	for fire: Fire in fires():
		if fire.clear_radius > 0.0 and Vector2(x - fire.position.x, z - fire.position.z).length() < fire.clear_radius:
			return true
	return false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not ResourceLoader.exists(INFO_PATH):
		push_warning("ZoneInfo: %s não existe (rode tools/blender/export_zone.py)" % INFO_PATH)
		return
	var json: JSON = load(INFO_PATH) as JSON
	if json == null or not (json.data is Dictionary):
		push_warning("ZoneInfo: %s inválido" % INFO_PATH)
		return
	var data: Dictionary = json.data
	var region_list: Variant = data.get("regions")
	if region_list is Array:
		for entry: Variant in region_list:
			if entry is Dictionary:
				var region: Region = _read_region(entry)
				if region != null:
					_regions.append(region)
	var fire_list: Variant = data.get("fires")
	if fire_list is Array:
		for entry: Variant in fire_list:
			if entry is Dictionary:
				var item: Dictionary = entry
				var fire: Fire = Fire.new()
				fire.position = Vector3(Protocol.read_float(item, "x"), Protocol.read_float(item, "y"),
						Protocol.read_float(item, "z"))
				fire.size = Protocol.read_float(item, "size", 1.0)
				fire.clear_radius = Protocol.read_float(item, "clearRadius")
				_fires.append(fire)


static func _read_region(item: Dictionary) -> Region:
	var region: Region = Region.new()
	region.name = Protocol.read_string(item, "name")
	region.min_level = Protocol.read_int(item, "minLevel")
	region.max_level = Protocol.read_int(item, "maxLevel")
	region.outer = _read_points(item.get("outer"))
	if region.name.is_empty() or region.outer.size() < 3:
		return null
	var holes: Variant = item.get("holes")
	if holes is Array:
		for hole: Variant in holes:
			var points: PackedVector2Array = _read_points(hole)
			if points.size() >= 3:
				region.holes.append(points)
	var label: PackedVector2Array = _read_points([item.get("label")])
	region.label = label[0] if label.size() == 1 else region.outer[0]
	return region


## Lista JSON [[x, z], ...] → pontos.
static func _read_points(value: Variant) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if not (value is Array):
		return points
	for pair: Variant in value:
		if pair is Array:
			var xz: Array = pair
			if xz.size() == 2 and (xz[0] is float or xz[0] is int) and (xz[1] is float or xz[1] is int):
				points.append(Vector2(float(xz[0]), float(xz[1])))
	return points
