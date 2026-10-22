@tool
class_name PhoneRow
extends Button
## Sales Phone menu row: icon, title, subtitle, chevron. Emits `chosen(id)`.

signal chosen(id: StringName)

@export var id: StringName
@export var title := "Title":
	set(v):
		title = v
		if is_node_ready():
			$Row/Text/Title.text = v
@export var subtitle := "":
	set(v):
		subtitle = v
		if is_node_ready():
			$Row/Text/Sub.text = v
@export var row_icon: Texture2D:
	set(v):
		row_icon = v
		if is_node_ready():
			$Row/Icon.texture = v
## Red count badge on the icon's top-right corner; hidden at 0.
@export var badge := 0:
	set(v):
		badge = v
		if is_node_ready():
			_update_badge()

var _badge: Label


func _ready() -> void:
	$Row/Text/Title.text = title
	$Row/Text/Sub.text = subtitle
	$Row/Icon.texture = row_icon
	_build_badge()
	pressed.connect(func(): chosen.emit(id))


func _build_badge() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e2493f")
	style.border_color = Color("#0b1211")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	_badge = Label.new()
	_badge.name = "Badge"
	_badge.add_theme_stylebox_override(&"normal", style)
	_badge.add_theme_font_size_override(&"font_size", 11)
	_badge.add_theme_color_override(&"font_color", Color.WHITE)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.custom_minimum_size = Vector2(18, 18)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = $Row/Icon
	icon.add_child(_badge)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.position = Vector2(icon.custom_minimum_size.x - 12.0, -6.0)
	_update_badge()


func _update_badge() -> void:
	_badge.visible = badge > 0
	_badge.text = str(badge)
