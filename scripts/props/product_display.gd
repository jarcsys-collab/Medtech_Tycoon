@tool
class_name ProductDisplay
extends Node2D
## Placeholder product carton drawn from ProductData (colour + short code), origin at the bottom centre
## so it sits on a shelf deck. Uses ProductData.icon instead when one is assigned (final art).

const FONT := preload("res://assets/fonts/PixelifySansMedTycoon-SemiBold.ttf")

@export var product: ProductData:
	set(value):
		product = value
		queue_redraw()
@export var box_size := Vector2(58, 46):
	set(value):
		box_size = value
		queue_redraw()


func _draw() -> void:
	var w := box_size.x
	var h := box_size.y
	var front := Rect2(-w / 2.0, -h, w, h)
	if product == null:
		draw_rect(front, Color(0.3, 0.3, 0.3, 0.6))
		return
	if product.icon:
		draw_texture_rect(product.icon, front, false)
		return
	var base := product.color
	# Top face (3/4 view) and front face.
	draw_rect(Rect2(front.position.x, front.position.y - 10, w, 10), base.lightened(0.35))
	draw_rect(front, base.darkened(0.08))
	draw_rect(Rect2(front.position.x, front.position.y, 6, h), base.darkened(0.25))
	# White label band with the product code.
	var band := Rect2(front.position.x + 8, front.position.y + h * 0.38, w - 14, h * 0.36)
	draw_rect(band, Color(0.96, 0.96, 0.93))
	draw_rect(Rect2(front.position.x - 0.5, front.position.y - 10, w + 1, h + 10), Color(0.04, 0.06, 0.06), false, 2.0)
	var fs := 15
	var text_w := FONT.get_string_size(product.short_code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(FONT, Vector2(band.get_center().x - text_w / 2.0, band.end.y - 4), product.short_code,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.1, 0.1))
