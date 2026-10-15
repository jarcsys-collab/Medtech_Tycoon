class_name Shelf
extends StaticBody2D
## Supplier Depot shelf stocked with one product. E opens a wholesale purchase dialog.

@export var product: ProductData
@export var size := Vector2(240, 64)
@export var batch_sizes: Array[int] = [1, 5, 10]

@onready var interact_area: Interactable = $Interactable
@onready var name_label: Label = $NameLabel
@onready var displays: Node2D = $Displays


func _ready() -> void:
	add_to_group(&"nav_obstacles")
	interact_area.interacted.connect(_on_interacted)
	GameState.stats_changed.connect(_refresh)
	for d in displays.get_children():
		if d is ProductDisplay:
			d.product = product
	_refresh()


func get_nav_outline() -> PackedVector2Array:
	var h := size / 2.0
	return global_transform * PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


func is_locked() -> bool:
	return product == null or product.unlock_level > GameState.level


## Rack drawn standing on its footprint (collision = footprint only), ~character height,
## two decks that hold the ProductDisplay boxes. Replace with a sprite later; keep RACK_HEIGHT in mind.
const RACK_HEIGHT := 190.0
const DECK_Y := [-8.0, -96.0]


func _draw() -> void:
	var h := size / 2.0
	var front := h.y - 4.0
	var top := front - RACK_HEIGHT
	# Floor shadow under the footprint.
	draw_rect(Rect2(-h.x + 6, -h.y + 14, size.x, size.y), Color(0, 0, 0, 0.28))
	# Back panel (mesh) and side uprights.
	draw_rect(Rect2(-h.x + 8, top + 6, size.x - 16, front - top - 6), Color("#26302f"))
	var mx := -h.x + 20
	while mx < h.x - 12:
		draw_line(Vector2(mx, top + 8), Vector2(mx, front - 2), Color("#2f3a3a"), 2.0)
		mx += 18.0
	for deck_y in DECK_Y:
		# Deck: top surface + front lip.
		draw_rect(Rect2(-h.x + 6, deck_y - 6, size.x - 12, 10), Color("#7d8c94"))
		draw_rect(Rect2(-h.x + 6, deck_y + 4, size.x - 12, 8), Color("#e0743a"))
	draw_rect(Rect2(-h.x + 6, top, size.x - 12, 8), Color("#e0743a"))
	for ux in [-h.x, h.x - 12.0]:
		draw_rect(Rect2(ux, top - 4, 12, front - top + 8), Color("#3c6aa8"))
		draw_rect(Rect2(ux + 2, top - 4, 3, front - top + 8), Color("#5a8bd0"))
		draw_rect(Rect2(ux - 2, front + 2, 16, 6), Color("#1d2427"))


func _refresh() -> void:
	if product == null:
		name_label.text = "Empty shelf"
		return
	if is_locked():
		name_label.text = "%s\nLOCKED · LV %d" % [product.display_name, product.unlock_level]
		displays.modulate = Color(0.35, 0.35, 0.35)
		interact_area.prompt = "Locked (Level %d)" % product.unlock_level
	else:
		name_label.text = "%s\n$%s / unit" % [product.display_name, GameState.format_money(product.wholesale_cost)]
		displays.modulate = Color.WHITE
		interact_area.prompt = "Restock %s" % product.display_name


func _on_interacted(_player: Node) -> void:
	if product == null:
		return
	if is_locked():
		UIEvents.toast("%s unlocks at Level %d" % [product.display_name, product.unlock_level])
		return
	var options: Array = []
	for qty in batch_sizes:
		var cost := product.wholesale_cost * qty
		options.append(UIEvents.option("Buy %d  ($%s)" % [qty, GameState.format_money(cost)],
			_buy.bind(qty), cost > GameState.cash, qty == batch_sizes[0]))
	options.append(UIEvents.option("Done"))
	UIEvents.ask(product.display_name,
		"%s\nWholesale [color=#e8c25a]$%s[/color] · Typical sale $%s\nIn stock: [b]%d[/b] · Cash: $%s" % [
			product.description, GameState.format_money(product.wholesale_cost),
			GameState.format_money(product.retail_price), GameState.stock_of(product.id),
			GameState.format_money(GameState.cash)],
		options)


func _buy(qty: int) -> void:
	if GameState.buy_stock(product, qty):
		_on_interacted(null)  # keep the dialog open for repeat purchases
