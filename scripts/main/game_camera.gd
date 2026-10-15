class_name GameCamera
extends Camera2D
## Frames the current location's focus rect at any window size and drifts gently toward the player.
## Zoom fits the focus rect into the viewport, so portrait room art works on landscape screens.

## Fraction of the player's offset from the room centre the camera follows (0 = static, 1 = locked on).
@export_range(0.0, 1.0) var drift := 0.18
@export var follow_speed := 3.5
## Never zoom in further than this (keeps big rooms from looking blurry on tall screens).
@export var max_zoom := 1.0
## Screen pixels kept free on each side for the HUD columns (objective/tutorial left, nav rail right).
@export var side_reserve := 330.0
## Screen pixels covered by the top stat bar; the focus rect is fitted below it.
@export var top_reserve := 66.0

var focus := Rect2(0, 0, 1280, 720)
var target: Node2D
## Screen-space shift of the framing (e.g. slide the room left while the phone covers the right side).
var screen_shift := Vector2.ZERO
## Responsive (portrait phones): returns Vector2(top, bottom) screen px covered by the HUD, read
## every frame. When set it replaces top_reserve and side_reserve (no side columns in portrait).
## Not set on desktop, so desktop framing is unchanged.
var inset_source: Callable


func frame(focus_rect: Rect2, follow: Node2D) -> void:
	focus = focus_rect
	target = follow
	zoom = Vector2.ONE * _fit_zoom()
	global_position = _desired_position()
	reset_smoothing()


func _process(delta: float) -> void:
	var z := _fit_zoom()
	zoom = Vector2.ONE * z
	global_position = global_position.lerp(_desired_position(), clampf(follow_speed * delta, 0.0, 1.0))


func _fit_zoom() -> float:
	var vp := get_viewport_rect().size
	if focus.size.x <= 0.0 or focus.size.y <= 0.0:
		return 1.0
	var r := _reserves()
	var usable_w := maxf(vp.x - r.x * 2.0, vp.x * 0.45)
	var usable_h := maxf(vp.y - r.y - r.z, vp.y * 0.5)
	return minf(minf(usable_h / focus.size.y, usable_w / focus.size.x), max_zoom)


func _desired_position() -> Vector2:
	var center := focus.get_center()
	if target and is_instance_valid(target) and target.is_inside_tree():
		center += (target.global_position - center) * drift
	# Moving the camera right moves the room left on screen; the top bar pushes framing down.
	# Never slide the room under the left HUD column.
	var r := _reserves()
	var shift := screen_shift + Vector2(0, (r.y - r.z) / 2.0)
	var vp := get_viewport_rect().size
	var room_left := vp.x / 2.0 - focus.size.x * zoom.x / 2.0
	shift.x = maxf(shift.x, minf(0.0, r.x - room_left))
	return center - shift / maxf(zoom.x, 0.01)


## Screen reserves: x = each side, y = top, z = bottom.
func _reserves() -> Vector3:
	if inset_source.is_valid():
		var insets: Vector2 = inset_source.call()
		return Vector3(0.0, insets.x, insets.y)
	return Vector3(side_reserve, top_reserve, 0.0)
