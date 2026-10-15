@tool
class_name DepotArt
extends Node2D
## Procedural placeholder art for the Supplier Depot (floor, walls, doors, dock).
## Replace this node with a Sprite2D "Background" when final Aseprite art exists; collisions are separate.

const FONT := preload("res://assets/fonts/PixelifySansMedTycoon-SemiBold.ttf")

@export var floor_rect := Rect2(20, 330, 740, 990):
	set(v):
		floor_rect = v
		queue_redraw()
@export var dock_span := Vector2(200, 580):
	set(v):
		dock_span = v
		queue_redraw()
@export var aisle_x := Vector2(330, 450):
	set(v):
		aisle_x = v
		queue_redraw()


func _draw() -> void:
	var f := floor_rect
	var wall_top := f.position.y - 155.0
	var outer := Rect2(f.position.x - 20, wall_top - 15, f.size.x + 40, f.end.y - wall_top + 35)

	# Building shell.
	draw_rect(outer, Color("#1b2226"))

	# Concrete floor tiles with subtle alternating shades.
	draw_rect(f, Color("#3a413e"))
	var tile := 92.0
	var y := f.position.y
	var row := 0
	while y < f.end.y:
		var x := f.position.x
		var col := 0
		while x < f.end.x:
			var r := Rect2(x, y, minf(tile, f.end.x - x), minf(tile, f.end.y - y))
			draw_rect(r.grow(-1.0), Color("#3e4642") if (row + col) % 2 == 0 else Color("#383f3c"))
			x += tile
			col += 1
		y += tile
		row += 1

	# Shadow the back wall casts onto the floor.
	for i in 8:
		draw_rect(Rect2(f.position.x, f.position.y + i * 7.0, f.size.x, 7.0), Color(0, 0, 0, 0.32 * (1.0 - i / 8.0)))

	# Back wall: cap, face, roller doors, sign plate.
	draw_rect(Rect2(f.position.x - 20, wall_top - 15, f.size.x + 40, 18), Color("#4a5860"))
	draw_rect(Rect2(f.position.x, wall_top, f.size.x, f.position.y - wall_top), Color("#2b353a"))
	draw_rect(Rect2(f.position.x, f.position.y - 10, f.size.x, 10), Color("#20282c"))
	for door_x in [f.position.x + 60.0, f.end.x - 220.0]:
		var d := Rect2(door_x, wall_top + 30, 160, f.position.y - wall_top - 40)
		draw_rect(d.grow(4), Color("#1d2427"))
		draw_rect(d, Color("#5d6a71"))
		var sy := d.position.y + 8.0
		while sy < d.end.y:
			draw_line(Vector2(d.position.x, sy), Vector2(d.end.x, sy), Color("#4b575d"), 2.0)
			sy += 12.0
		draw_rect(Rect2(d.position.x + d.size.x / 2 - 14, d.end.y - 14, 28, 6), Color("#2a3236"))
	var sign_rect := Rect2(f.get_center().x - 120, wall_top + 26, 240, 86)
	draw_rect(sign_rect.grow(3), Color("#e8c25a"))
	draw_rect(sign_rect, Color("#111a1c"))
	_text_centered("SUPPLIER DEPOT", Vector2(sign_rect.get_center().x, sign_rect.position.y + 40), 30, Color("#e8c25a"))
	_text_centered("HARBOR · WHOLESALE", Vector2(sign_rect.get_center().x, sign_rect.position.y + 70), 18, Color("#9fb0ad"))

	# Side walls.
	draw_rect(Rect2(f.position.x - 20, wall_top, 20, f.end.y - wall_top + 20), Color("#232c30"))
	draw_rect(Rect2(f.end.x, wall_top, 20, f.end.y - wall_top + 20), Color("#232c30"))

	# Aisle safety lines (dashed yellow).
	for ax in [aisle_x.x, aisle_x.y]:
		var dy := f.position.y + 40.0
		while dy < f.end.y - 90.0:
			draw_rect(Rect2(ax - 2, dy, 4, 26), Color("#c9a640", 0.75))
			dy += 44.0

	# Front wall lip with the loading-dock opening.
	draw_rect(Rect2(f.position.x - 20, f.end.y, dock_span.x - f.position.x + 20, 20), Color("#232c30"))
	draw_rect(Rect2(dock_span.y, f.end.y, f.end.x + 20 - dock_span.y, 20), Color("#232c30"))
	var dock := Rect2(dock_span.x, f.end.y - 34, dock_span.y - dock_span.x, 34)
	draw_rect(dock, Color("#e0b43c"))
	var sx := dock.position.x + 6.0
	while sx + dock.size.y < dock.end.x:
		draw_line(Vector2(sx, dock.end.y - 3), Vector2(sx + dock.size.y - 6, dock.position.y + 3), Color("#1a1a16"), 10.0)
		sx += 32.0
	_text_centered("LOADING DOCK · EXIT", Vector2(dock.get_center().x, f.end.y + 42), 20, Color("#9fb0ad"))


func _text_centered(text: String, center_baseline: Vector2, size: int, color: Color) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, Vector2(center_baseline.x - w / 2.0, center_baseline.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
