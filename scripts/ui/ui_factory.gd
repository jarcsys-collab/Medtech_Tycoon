class_name UIFactory
extends RefCounted
## Small builders for list content that is generated at runtime (phone pages, info panels).

## Pass as `color` to keep the theme's font color.
const NONE := Color(0, 0, 0, 0)


static func label(text: String, variation := &"", font_size := 0, color := NONE, wrap_text := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override(&"font_size", font_size)
	if color.a > 0.0:
		l.add_theme_color_override(&"font_color", color)
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 10
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func row_panel() -> Array:
	## Returns [PanelContainer, VBoxContainer] — add content to the VBox.
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"RowPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	panel.add_child(box)
	return [panel, box]


static func button(text: String, on_pressed: Callable, disabled := false, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## Small square check indicator (filled mint with a tick when done).
static func check_box(done: bool) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(16, 16)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_color = Color("#3dffc0") if done else Color("#3d5a5e")
	style.bg_color = Color("#3dffc0") if done else Color(0, 0, 0, 0)
	box.add_theme_stylebox_override(&"panel", style)
	if done:
		box.draw.connect(func():
			box.draw_polyline(PackedVector2Array([Vector2(4, 8.5), Vector2(7, 11.5), Vector2(12.5, 5)]), Color("#0b1211"), 2.2))
	return box


static func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


static func product_swatch(product: ProductData, size := Vector2(40, 32)) -> Control:
	## Small colored square with the short code, or the product icon if one is set.
	if product.icon:
		var rect := TextureRect.new()
		rect.texture = product.icon
		rect.custom_minimum_size = size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect
	var swatch := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = product.color
	style.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override(&"panel", style)
	swatch.custom_minimum_size = size
	var l := Label.new()
	l.text = product.short_code
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 14)
	l.add_theme_color_override(&"font_color", Color(0.05, 0.07, 0.07))
	swatch.add_child(l)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return swatch
