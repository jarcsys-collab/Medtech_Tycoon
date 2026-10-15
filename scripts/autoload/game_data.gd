extends Node
## Static game content: product catalog, locations, progression tables, tasks. (Tutorial steps: Tutorial autoload.)
## Products and locations are loaded from .tres files, so new ones can be added without code changes.

const PRODUCT_DIR := "res://data/products/"
const LOCATION_DIR := "res://data/locations/"
const COMING_SOON_SCENE := "res://scenes/locations/coming_soon.tscn"

## Total XP needed to reach level N (index 0 = level 1).
const LEVEL_XP: Array[int] = [0, 100, 250, 450, 700]

const TASKS := [
	{"id": "open_phone", "title": "Check your phone", "desc": "Open the Sales Phone to review your leads.", "xp": 10},
	{"id": "visit_cafe", "title": "Go to Coffee Corner", "desc": "Use TRAVEL to visit the café on Market St.", "xp": 10},
	{"id": "meet_prospect", "title": "Meet a prospect", "desc": "Walk up to a café customer and press E.", "xp": 10},
	{"id": "first_deal", "title": "Close your first deal", "desc": "Sell to a lead in person (E) or by phone.", "xp": 20},
	{"id": "reach_lv2", "title": "Reach Level 2", "desc": "Earn XP from deals. Unlocks the Supplier Depot.", "xp": 0},
	{"id": "restock", "title": "Restock inventory", "desc": "Buy stock from a shelf at the Supplier Depot.", "xp": 15},
	{"id": "sleep", "title": "End the day", "desc": "Go Home and press E at your bed to sleep.", "xp": 10},
]

const FIRST_NAMES := ["Maria", "Jun", "Aisha", "Tomas", "Grace", "Ravi", "Elena", "Marcus", "Noor", "Ben", "Lea", "Kenji"]
const LAST_NAMES := ["Reyes", "Santos", "Lim", "Okafor", "Novak", "Tan", "Cruz", "Haddad", "Park", "Silva"]
const BUSINESSES := ["Family Clinic", "Pharmacy", "Dental Office", "Diagnostic Lab", "Home Care Agency", "Sports Clinic", "School Nurse Office"]

const STARTING_CUSTOMERS := ["Sunrise Family Clinic", "Harbor Pharmacy", "Dr. Lim Dental"]
const STARTING_INVENTORY := {"pulse_oximeter": 6, "bp_monitor": 3, "glucose_meter": 6}

var products: Array[ProductData] = []
var locations: Array[LocationData] = []
var _products_by_id := {}
var _locations_by_id := {}


func _ready() -> void:
	for res in _load_dir(PRODUCT_DIR):
		if res is ProductData:
			products.append(res)
			_products_by_id[String(res.id)] = res
	for res in _load_dir(LOCATION_DIR):
		if res is LocationData:
			locations.append(res)
			_locations_by_id[String(res.id)] = res
	products.sort_custom(func(a, b): return a.wholesale_cost < b.wholesale_cost)
	locations.sort_custom(func(a, b): return a.sort_order < b.sort_order)


func get_product(id: Variant) -> ProductData:
	return _products_by_id.get(String(id))


func get_location(id: Variant) -> LocationData:
	return _locations_by_id.get(String(id))


func products_for_level(level: int) -> Array[ProductData]:
	var out: Array[ProductData] = []
	for p in products:
		if p.unlock_level <= level:
			out.append(p)
	return out


func level_for_xp(xp: int) -> int:
	var lvl := 1
	for i in LEVEL_XP.size():
		if xp >= LEVEL_XP[i]:
			lvl = i + 1
	return lvl


func max_level() -> int:
	return LEVEL_XP.size()


func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("GameData: missing directory %s" % dir_path)
		return out
	for file in dir.get_files():
		# Exported builds list remapped resources as *.tres.remap.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(dir_path + file)
			if res:
				out.append(res)
	return out
