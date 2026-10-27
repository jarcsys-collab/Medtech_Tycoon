class_name PhoneApp
extends Button
## Sales Phone home-grid tile (Sales Simulator handoff: rounded tile, tinted icon square, label, red
## count badge, optional gold caption such as "SOON"). Emits `chosen(id)`. An app that is not built yet
## is `available = false`: dimmed, captioned SOON and disabled, so it never pretends to work.

signal chosen(id: StringName)

## ZIP tile metrics (596 px phone) scaled to the ~332 px Godot phone.
const TILE_HEIGHT := 84.0
const ICON_BOX := 44.0
const ICON_MAX := Vector2(31, 30)
const TILE_BG := Color("#112324")
const TILE_BORDER := Color("#2b4f4f")
const TILE_HOVER := Color("#3a6b6b")
const BADGE_BG := Color("#e5483a")
const SUB_COLOR := Color("#e8c25a")

var id: StringName
var title := "":
	set(v):
		title = v
		if _label:
			_label.text = v
## Red count badge (top-right); hidden at 0.
var badge := 0:
	set(v):
		badge = v
		_update_badge()
var available := true

var _label: Label
var _sub: Label
var _badge: Label


func _init(app_id: StringName = &"", app_title := "", icon_texture: Texture2D = null, tint := Color("#173a3a"),
		is_available := true) -> void:
	id = app_id
	name = app_title.replace(" ", "")
	available = is_available
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, TILE_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	disabled = not available
	tooltip_text = "" if available else "%s arrives in a later update" % app_title
	for state in [&"normal", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, _tile_style(TILE_BORDER))
	add_theme_stylebox_override(&"hover", _tile_style(TILE_HOVER))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 5)
	add_child(box)

	var square := PanelContainer.new()
	square.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sq := StyleBoxFlat.new()
	sq.bg_color = tint
	sq.set_corner_radius_all(9)
	square.add_theme_stylebox_override(&"panel", sq)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_texture
	icon_rect.custom_minimum_size = ICON_MAX
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(icon_rect)
	box.add_child(square)

	_label = Label.new()
	_label.text = app_title
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	title = app_title

	_sub = Label.new()
	_sub.text = "SOON"
	_sub.visible = not available
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override(&"font_size", 9)
	_sub.add_theme_color_override(&"font_color", SUB_COLOR)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub)
	if not available:
		modulate = Color(1, 1, 1, 0.55)

	_badge = Label.new()
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override(&"font_size", 13)
	_badge.add_theme_color_override(&"font_color", Color.WHITE)
	var bs := StyleBoxFlat.new()
	bs.bg_color = BADGE_BG
	bs.set_corner_radius_all(12)
	bs.set_border_width_all(2)
	bs.border_color = Color("#0f1d1e")
	bs.content_margin_left = 5.0
	bs.content_margin_right = 5.0
	_badge.add_theme_stylebox_override(&"normal", bs)
	_badge.custom_minimum_size = Vector2(24, 24)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -18.0
	_badge.offset_top = -6.0
	_badge.offset_right = 6.0
	_badge.offset_bottom = 18.0
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_update_badge()
	pressed.connect(func(): chosen.emit(id))


func _update_badge() -> void:
	if _badge:
		_badge.text = str(badge)
		_badge.visible = badge > 0 and available


static func _tile_style(border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = TILE_BG
	st.set_border_width_all(2)
	st.border_color = border
	st.set_corner_radius_all(10)
	return st
