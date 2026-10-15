class_name UIAnim
extends RefCounted
## Short, consistent UI motion. Animates scale/alpha only, so anchored layouts are never disturbed.

const OPEN_TIME := 0.16
const CLOSE_TIME := 0.12


## Show `c` with a soft pop. `body` (optional) is the visual part to scale, e.g. a centred panel.
static func pop_in(c: CanvasItem, body: Control = null, from_scale := 0.94) -> void:
	_kill(c)
	c.show()
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, OPEN_TIME).set_trans(Tween.TRANS_SINE)
	if body:
		body.pivot_offset = body.size / 2.0
		body.scale = Vector2.ONE * from_scale
		tw.tween_property(body, "scale", Vector2.ONE, OPEN_TIME + 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta(&"ui_tween", tw)


## Fade `c` out, then hide it.
static func fade_out(c: CanvasItem) -> void:
	if not c.visible:
		return
	_kill(c)
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, CLOSE_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(c.hide)
	c.set_meta(&"ui_tween", tw)


## Quick attention pulse (e.g. a stat that just changed).
static func pulse(c: Control, strength := 1.12) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * strength, 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _kill(c: CanvasItem) -> void:
	if c.has_meta(&"ui_tween"):
		var old: Tween = c.get_meta(&"ui_tween")
		if old and old.is_valid():
			old.kill()
