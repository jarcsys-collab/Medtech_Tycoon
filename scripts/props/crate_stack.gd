@tool
class_name CrateStack
extends StaticBody2D
## Placeholder decor: a pallet with stacked cardboard boxes. Footprint = collision + nav obstacle.

@export var footprint := Vector2(96, 56):
	set(v):
		footprint = v
		queue_redraw()
@export_range(1, 3) var layers := 2:
	set(v):
		layers = v
		queue_redraw()


func _ready() -> void:
	add_to_group(&"nav_obstacles")


func get_nav_outline() -> PackedVector2Array:
	var h := footprint / 2.0
	return global_transform * PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


func _draw() -> void:
	var h := footprint / 2.0
	# Contact shadow + pallet.
	draw_rect(Rect2(-h.x + 4, -h.y + 10, footprint.x, footprint.y), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-h.x, h.y - 14, footprint.x, 14), Color("#7a5a36"))
	draw_rect(Rect2(-h.x, h.y - 14, footprint.x, 3), Color("#9a7448"))
	var box_h := 46.0
	for i in layers:
		var top := h.y - 14 - box_h * (i + 1)
		var inset := 6.0 * i
		var r := Rect2(-h.x + 4 + inset, top, footprint.x - 8 - inset * 2, box_h)
		draw_rect(r, Color("#b88a55"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 12)), Color("#d0a46b"))
		draw_rect(Rect2(r.get_center().x - 6, r.position.y, 12, r.size.y), Color("#c9b48c", 0.9))
		draw_rect(r, Color("#5a4024"), false, 2.0)
