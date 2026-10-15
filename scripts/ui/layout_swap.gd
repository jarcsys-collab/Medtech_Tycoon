class_name LayoutSwap
extends RefCounted
## Swap a Control between its scene (desktop) layout and a mobile layout.
## `apply` remembers each property's scene value the first time it is overridden; `restore`
## puts every remembered value back, so the desktop layout always comes from the .tscn files.
## Works for anchors/offsets/sizes and theme overrides ("theme_override_font_sizes/font_size";
## a scene without that override restores to "no override").

const META := &"_scene_layout"


## Apply `values` (property -> value). List anchors before offsets.
static func apply(c: Control, values: Dictionary) -> void:
	var saved: Dictionary = c.get_meta(META, {})
	for p in values:
		if not saved.has(p):
			saved[p] = c.get(p)
	c.set_meta(META, saved)
	for p in values:
		c.set(p, values[p])


static func restore(c: Control) -> void:
	if not c.has_meta(META):
		return
	var saved: Dictionary = c.get_meta(META)
	for p in saved:
		c.set(p, saved[p])
	c.remove_meta(META)


## Anchors + offsets for a control stretched across the screen between `top` and `bottom` insets.
static func band(left: float, top: float, right: float, bottom: float) -> Dictionary:
	return {
		"anchor_left": 0.0, "anchor_top": 0.0, "anchor_right": 1.0, "anchor_bottom": 1.0,
		"offset_left": left, "offset_top": top, "offset_right": -right, "offset_bottom": -bottom,
	}
