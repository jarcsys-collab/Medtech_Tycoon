class_name ChoiceDialog
extends Control
## Modal dialog driven by UIEvents.ask(title, body, options). Used by customers, shelves, bed, finance.
## Sales Simulator handoff look (V1): the pixel-frame dialogue box (dialog-box.png) with the player
## portrait, gold title and body text at the bottom of the screen, and the replies stacked above it as
## numbered cyan cards.

const MAX_HALF_WIDTH := 380.0
const SIDE_MARGIN := 10.0
const REPLY_BORDER := Color("#7ed8f7")
const REPLY_BG := Color("#0e2129")
const REPLY_BG_HOVER := Color("#123040")
const REPLY_HEIGHT := 48.0
const BODY_COLOR := Color("#d6d3c8")

@onready var title_label: Label = %Title
@onready var body_label: RichTextLabel = %Body
@onready var buttons: VBoxContainer = %Buttons
@onready var panel: PanelContainer = $Stack/Panel
@onready var stack: VBoxContainer = $Stack


func _ready() -> void:
	hide()
	body_label.add_theme_color_override(&"default_color", BODY_COLOR)
	UIEvents.choice_requested.connect(open)


func open(title: String, body: String, options: Array) -> void:
	title_label.text = title
	body_label.text = body
	UIFactory.clear(buttons)
	var n := 0
	for opt in options:
		n += 1
		buttons.add_child(_reply(n, opt.get("label", "OK"), _choose.bind(opt.get("action", Callable())),
			opt.get("disabled", false)))
	UIAnim.pop_in(self, stack, 0.96)


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: the dialogue spans the screen width (minus a margin) up to 760 px, at the bottom.
func apply_layout(_portrait: bool) -> void:
	var half := minf(MAX_HALF_WIDTH, get_viewport_rect().size.x / 2.0 - SIDE_MARGIN)
	stack.offset_left = -half
	stack.offset_right = half


## ZIP reply card: number in a cyan square, then the reply text.
func _reply(n: int, text: String, action: Callable, disabled: bool) -> Button:
	var b := UIFactory.button("", action, disabled)
	b.custom_minimum_size.y = REPLY_HEIGHT
	b.tooltip_text = text
	for state in [&"normal", &"pressed", &"hover_pressed", &"focus"]:
		b.add_theme_stylebox_override(state, _card(REPLY_BG, REPLY_BORDER))
	b.add_theme_stylebox_override(&"hover", _card(REPLY_BG_HOVER, REPLY_BORDER))
	b.add_theme_stylebox_override(&"disabled", _card(REPLY_BG, REPLY_BORDER.darkened(0.55)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	var num := Label.new()
	num.name = "Number"
	num.text = str(n)
	num.custom_minimum_size = Vector2(26, 26)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_color_override(&"font_color", REPLY_BORDER)
	num.add_theme_font_size_override(&"font_size", 14)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(2)
	box.border_color = REPLY_BORDER
	box.set_corner_radius_all(5)
	num.add_theme_stylebox_override(&"normal", box)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num)
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override(&"font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	if disabled:
		row.modulate = Color(1, 1, 1, 0.45)
	b.add_child(row)
	return b


static func _card(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_border_width_all(2)
	st.border_color = border
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 1
	st.shadow_offset = Vector2(0, 4)
	return st


func _choose(action: Callable) -> void:
	close()
	if action.is_valid():
		# Deferred: the action may reopen this dialog, which frees the button being pressed.
		action.call_deferred()
