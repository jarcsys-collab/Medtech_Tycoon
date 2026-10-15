class_name InteractionMarker
extends Node2D
## Floating [E] key badge above the player's current interaction target. Constant on-screen size.

const FONT := preload("res://assets/fonts/PixelifySansMedTycoon-Bold.ttf")
const SIZE := 34.0

## Touch screens show a tap badge instead of the E key (the action button does the rest).
var touch_mode := false
var _target: Interactable
var _t := 0.0
var _cap := StyleBoxFlat.new()


func _ready() -> void:
	_cap.bg_color = Color("#f2efe6")
	_cap.set_corner_radius_all(7)
	_cap.border_width_bottom = 5
	_cap.border_color = Color("#9aa3a0")
	_cap.shadow_color = Color(0, 0, 0, 0.4)
	_cap.shadow_size = 4
	_cap.shadow_offset = Vector2(0, 3)
	z_index = 100
	z_as_relative = false
	hide()


func follow(target: Interactable) -> void:
	_target = target
	visible = target != null
	if visible:
		_t = 0.0
		scale = Vector2.ZERO
		_process(0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		hide()
		return
	_t += delta
	var cam := get_viewport().get_camera_2d()
	var inv := 1.0 / cam.zoom.x if cam else 1.0
	var pop := minf(_t / 0.18, 1.0)
	scale = Vector2.ONE * inv * ease(pop, 0.4) * (1.0 + 0.12 * (1.0 - pop))
	global_position = _target.get_marker_position() + Vector2(0, sin(_t * 4.0) * 4.0 * inv)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_cap, Rect2(-SIZE / 2.0, -SIZE, SIZE, SIZE))
	var fs := 22
	var key := "!" if touch_mode else "E"
	var w := FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(FONT, Vector2(-w / 2.0, -SIZE * 0.32), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#111a1c"))
