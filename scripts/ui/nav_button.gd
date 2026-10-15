@tool
class_name NavButton
extends Button
## Side-nav tile (TASKS / PHONE / TRAVEL / DEALS / INVENTORY / FINANCE). Emits `chosen(id)`.

signal chosen(id: StringName)

@export var id: StringName
@export var label := "LABEL":
	set(v):
		label = v
		if is_node_ready():
			$Content/Label.text = v
@export var nav_icon: Texture2D:
	set(v):
		nav_icon = v
		if is_node_ready():
			$Content/Icon.texture = v
@export var icon_size := Vector2(32, 32):
	set(v):
		icon_size = v
		if is_node_ready():
			$Content/Icon.custom_minimum_size = v
@export var show_dot := false:
	set(v):
		show_dot = v
		if is_node_ready():
			$Dot.visible = v


func _ready() -> void:
	$Content/Label.text = label
	$Content/Icon.texture = nav_icon
	$Content/Icon.custom_minimum_size = icon_size
	$Dot.visible = show_dot
	if tooltip_text == "":
		tooltip_text = label.capitalize()
	pressed.connect(func():
		UIAnim.pulse(self, 1.06)
		chosen.emit(id))


## Compact tile for the mobile bottom bar: shares the bar width, smaller icon and label.
func set_compact(on: bool) -> void:
	if not has_meta(&"_desktop_min"):
		set_meta(&"_desktop_min", custom_minimum_size)
	custom_minimum_size = Vector2(0, 54) if on else get_meta(&"_desktop_min")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	$Content/Icon.custom_minimum_size = icon_size * (0.75 if on else 1.0)
	$Content/Label.add_theme_font_size_override(&"font_size", 10 if on else 12)
	$Content.add_theme_constant_override(&"separation", 2 if on else 4)


func set_active(active: bool) -> void:
	set_pressed_no_signal(active)
	$Content/Label.add_theme_color_override(&"font_color", Color("#7ed8f7") if active else Color("#d7dde0"))
