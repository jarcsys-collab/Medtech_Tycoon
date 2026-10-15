@tool
class_name GroundShadow
extends Node2D
## Soft elliptical contact shadow under characters and props (drawn, no texture needed).

@export var radius := Vector2(36, 12):
	set(v):
		radius = v
		queue_redraw()
@export_range(0.0, 1.0) var opacity := 0.38:
	set(v):
		opacity = v
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, radius.y / radius.x))
	const STEPS := 5
	for i in STEPS:
		var t := float(i) / STEPS
		draw_circle(Vector2.ZERO, radius.x * (1.0 - t * 0.55), Color(0, 0, 0, opacity / STEPS * 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
