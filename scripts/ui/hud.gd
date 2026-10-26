class_name Hud
extends Control
## Always-on HUD (anchored, scales with the 1280x720 canvas_items base):
## top bar, objective card, right nav rail, toast, contextual action button, tutorial card.
## Sales Simulator handoff (B1): the top bar shows the date and time of day only (cash, reputation
## and leads stay in GameState and appear in FINANCE and the phone); TO-DO and PHONE lead the nav.

signal nav_selected(id: StringName)
## Portrait layout only: the task / tutorial cards changed size or visibility.
signal portrait_insets_changed

const TOAST_SECONDS := 2.6  # Medtycoonv1 toast timeout
## Time-of-day indicator (G2a): the clock's caption names the slot, in the slot's colour.
const SLOT_LABELS := {&"morning": "MORNING", &"afternoon": "AFTERNOON", &"evening": "EVENING"}
const SLOT_COLORS := {&"morning": Color("#f2b866"), &"afternoon": Color("#ffd27a"), &"evening": Color("#b9a3ff")}
const SLOT_NOTICES := {
	&"morning": "Morning: commuters drop by the café",
	&"afternoon": "Afternoon rush: the café is busiest now",
	&"evening": "Evening: the café is quieter now",
}
const NAV_BUTTON_SCENE := preload("res://scenes/ui/nav_button.tscn")
const TASK_ICON := preload("res://assets/ui/tasks.png")

@onready var day_block: StatBlock = %DayBlock
@onready var clock_block: StatBlock = %ClockBlock
@onready var cash_block: StatBlock = %CashBlock
@onready var rep_block: StatBlock = %RepBlock
@onready var leads_block: StatBlock = %LeadsBlock
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var xp_label: Label = %XPLabel
@onready var nav_list: BoxContainer = %NavList
@onready var objective: PanelContainer = %Objective
@onready var objective_count: Label = %ObjectiveCount
@onready var objective_title: Label = %ObjectiveTitle
@onready var objective_desc: Label = %ObjectiveDesc
@onready var toast_panel: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var prompt_panel: PanelContainer = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var tutorial: PanelContainer = %Tutorial
@onready var tip_title: Label = %TipTitle
@onready var tip_body: Label = %TipBody
@onready var hint: Control = %Hint
@onready var hint_label: Label = %HintLabel
@onready var hint_sub: Label = %HintSub
@onready var next_label: Label = %Next
@onready var step_count: Label = %StepCount
@onready var skip_button: Button = %SkipButton

@onready var top_bar: PanelContainer = $TopBar
@onready var stat_row: HBoxContainer = $TopBar/Row
@onready var level_box: VBoxContainer = $TopBar/Row/Level
@onready var nav_rail: PanelContainer = $NavRail
@onready var objective_head: Control = $Objective/VBox/Head
@onready var tutorial_portrait: Control = $Tutorial/Row/PortraitFrame/Portrait
@onready var tutorial_portrait_frame: PanelContainer = $Tutorial/Row/PortraitFrame

## Tutorial card look: Sales Simulator v3 pixel frame (default) or the original flat card.
enum TutorialFrame { PIXEL, CLASSIC }

## Tutorial highlight pulse (Medtycoonv2: warm tint on the button to press next).
const HIGHLIGHT_TINT := Color(1.3, 1.2, 0.85)
const PIXEL_TUTORIAL_FRAME := preload("res://assets/ui/tutorial_frame_style.tres")
const PIXEL_PORTRAIT_SLOT := preload("res://assets/ui/tutorial_slot_style.tres")

@export var tutorial_frame := TutorialFrame.PIXEL:
	set(value):
		tutorial_frame = value
		if is_node_ready():
			_apply_tutorial_frame()
## Portrait (phone) layout metrics, in the portrait UI's logical pixels (~ CSS pixels).
const MOBILE_MARGIN := 6.0
const MOBILE_NAV_HEIGHT := 60.0
## Extra room for the notch / status bar (top) and the home indicator / browser bar (bottom).
const SAFE_TOP := 4.0
const SAFE_BOTTOM := 8.0
## Nav items that move into the MORE sheet on portrait phones (TO-DO, PHONE, TRAVEL stay in the bar).
const MOBILE_SECONDARY: Array[StringName] = [&"inventory", &"deals", &"finance"]

## True while the portrait phone layout is applied (see apply_layout / Responsive autoload).
var portrait := false
## Mobile layouts (portrait or landscape): collapsed objective bar, overlays hide the extras.
var compact := false
## Touchscreen device: no keyboard hints. The contextual action button is shown on every platform;
## keyboard devices also get the floating [E] badge (InteractionMarker) and key hints as shortcuts.
var touch_ui := false
var _scene_row_order: Array[Node] = []
var _mobile_rows: VBoxContainer
var _mobile_spacer: Control

var _toast_timer: SceneTreeTimer
var _toast_shown_ms := -100000
var _map_mode := false
var _xp_tween: Tween
var _objective_id := ""
var _active_nav: StringName = &""
var _tutorial_shown := false

var _swapped: Array[Control] = []
var _nav_buttons: Array[NavButton] = []
var _nav_order: Array[Node] = []
var _more_button: NavButton
var _more_sheet: PanelContainer
var _more_list: HBoxContainer
var _interact_button: Button
var _prompt_target: Interactable
var _objective_expanded := false
var _obj_bar: HBoxContainer
var _obj_bar_title: Label
var _obj_bar_count: Label
var _obj_bar_toggle: Label


func _ready() -> void:
	for b in nav_list.get_children():
		if b is NavButton:
			_nav_buttons.append(b)
			b.chosen.connect(nav_selected.emit)
			b.chosen.connect(func(_id): _set_more_open(false))
	_nav_order.assign(nav_list.get_children())
	_build_mobile_controls()
	_apply_tutorial_frame()
	tutorial.gui_input.connect(_on_tutorial_input)
	skip_button.pressed.connect(Tutorial.skip)
	Tutorial.step_changed.connect(func(_step: Dictionary): _refresh_tutorial())
	objective.gui_input.connect(_on_objective_input)
	UIEvents.toast_requested.connect(show_toast)
	GameState.stats_changed.connect(refresh)
	GameState.leads_changed.connect(refresh)
	GameState.tasks_changed.connect(refresh)
	GameState.time_slot_changed.connect(_on_time_slot_changed)
	toast_panel.hide()
	prompt_panel.hide()
	refresh()


func refresh() -> void:
	# Portrait hides the stat captions, so the day number moves into the date.
	day_block.caption = "DAY %d" % GameState.day
	day_block.value = ("Day %d · " % GameState.day if portrait else "") + GameState.date_label()
	clock_block.value = GameState.time_label()
	var slot := GameState.time_slot()
	clock_block.caption = SLOT_LABELS[slot]
	clock_block.get_node("Text/Caption").add_theme_color_override(&"font_color", SLOT_COLORS[slot])
	cash_block.value = "$" + GameState.format_money(GameState.cash)
	rep_block.value = "%d%%" % GameState.reputation
	leads_block.value = str(GameState.leads.size())
	level_label.text = "LV %d" % GameState.level
	var prog := GameState.xp_progress()
	var target := 1.0
	if prog.y > 0:
		target = float(prog.x) / prog.y
		xp_label.text = "%d / %d XP" % [prog.x, prog.y]
	else:
		xp_label.text = "MAX LEVEL"
	xp_bar.max_value = 1.0
	if _xp_tween:
		_xp_tween.kill()
	if target < xp_bar.value:  # level-up wrap: fill, then restart
		xp_bar.value = 0.0
	_xp_tween = create_tween()
	_xp_tween.tween_property(xp_bar, "value", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tasks_btn := nav_list.get_node_or_null("Tasks") as NavButton
	if tasks_btn:
		tasks_btn.show_dot = GameState.has_open_tasks()
	_refresh_objective()
	_refresh_tutorial()


func set_active_nav(id: StringName) -> void:
	_active_nav = id
	if id != &"":
		_set_more_open(false)
	for b in _nav_buttons:
		b.set_active(b.id == id)
	_update_more_button()
	if compact:
		# Mobile: an open menu gets the screen; the task bar and action button step aside.
		_refresh_objective()
		_refresh_tutorial()
		_update_interact()


## Medtycoonv1 hides the tutorial while the travel map is open; the objective card would cover the map.
func set_map_mode(value: bool) -> void:
	_map_mode = value
	_refresh_objective()
	_refresh_tutorial()


func set_prompt(target: Interactable) -> void:
	_prompt_target = target
	_update_interact()


## Tap-first: whatever is in reach (or was tapped) gets the big action button, on every platform.
func _update_interact() -> void:
	var target: Interactable = _prompt_target if is_instance_valid(_prompt_target) else null
	prompt_panel.hide()  # the old "[E] Sleep" key prompt; the button and the [E] badge replace it
	# Hidden while a menu covers the room (mobile) or the MORE sheet is open (it sits in the same corner).
	if target != null and not (compact and _active_nav != &"") and not _more_sheet.visible:
		_interact_button.text = target.get_prompt()
		_interact_button.tooltip_text = "" if touch_ui else "Or press E"
		if not _interact_button.visible or _interact_button.modulate.a < 1.0:
			UIAnim.pop_in(_interact_button, _interact_button, 0.9)
	else:
		UIAnim.fade_out(_interact_button)


func show_toast(text: String) -> void:
	_toast_shown_ms = Time.get_ticks_msec()
	toast_label.text = text
	_fit_toast()
	UIAnim.pop_in(toast_panel, toast_panel, 0.9)
	_toast_timer = get_tree().create_timer(TOAST_SECONDS)
	var my_timer := _toast_timer
	my_timer.timeout.connect(func():
		if _toast_timer == my_timer:
			UIAnim.fade_out(toast_panel))


## The clock passed 12:30 PM / 4:30 PM: pulse the clock and add a short notice. Deferred, so a
## toast from the same action ("Arrived at ...") is shown first and the notice joins it.
func _on_time_slot_changed(slot: StringName, announce: bool) -> void:
	refresh()
	if announce:
		UIAnim.pulse(clock_block, 1.12)
		_show_slot_notice.call_deferred(SLOT_NOTICES[slot])


## Shrink the toast to its text. Portrait keeps the full-width band and only fits the height.
func _fit_toast() -> void:
	if portrait:
		toast_panel.offset_bottom = toast_panel.offset_top
	else:
		toast_panel.reset_size()


func _show_slot_notice(text: String) -> void:
	if toast_panel.visible and Time.get_ticks_msec() - _toast_shown_ms < 1000 and not text in toast_label.text:
		toast_label.text += "
" + text
		_fit_toast()
	else:
		show_toast(text)


func _refresh_objective() -> void:
	var next: Dictionary = {}
	var done := 0
	for t in GameData.TASKS:
		if GameState.completed_tasks.has(t.id):
			done += 1
		elif next.is_empty():
			next = t
	objective.visible = not next.is_empty() and not _map_mode and not (compact and _active_nav != &"")
	if next.is_empty():
		return
	objective_count.text = "%d / %d" % [done, GameData.TASKS.size()]
	objective_title.text = next.title
	objective_desc.text = next.desc
	_obj_bar_title.text = next.title
	_obj_bar_count.text = "%d/%d" % [done, GameData.TASKS.size()]
	if _objective_id != "" and _objective_id != next.id:
		UIAnim.pulse(objective, 1.04)
	_objective_id = next.id
	if portrait:
		_place_prompt.call_deferred()


## Medtycoonv2 tutorial card: title, body, hint + sub line, step counter, SKIP; "NEXT >" only when
## the step waits for a click on the card.
func _refresh_tutorial() -> void:
	var step := Tutorial.current()
	var tip_visible := not step.is_empty() and not _map_mode
	tutorial.visible = tip_visible
	if not tip_visible:
		_tutorial_shown = false
		if portrait:
			_place_prompt.call_deferred()
		return
	var changed: bool = tip_title.text != step.title or not _tutorial_shown
	_tutorial_shown = true
	tip_title.text = step.title
	tip_body.text = step.body
	hint_label.text = step.get("hint", "") if touch_ui else step.get("hint_keys", step.get("hint", ""))
	hint_sub.text = step.get("sub", "")
	step_count.text = Tutorial.index_label()
	var wants_click: bool = step.wait == "click"
	next_label.visible = wants_click
	tutorial.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if wants_click else Control.CURSOR_ARROW
	tutorial.tooltip_text = "Click to continue" if wants_click else ""
	if portrait:
		# Bottom sheet: with a menu open only the instruction stays (no portrait / hint lines).
		var mini := _active_nav != &""
		_swap(tutorial_portrait_frame, {"visible": not mini})
		_swap(hint, {"visible": wants_click or not mini})
	if changed:
		UIAnim.pulse(tutorial, 1.04)  # Medtycoonv2: small pop so a new step is noticed
	_place_prompt.call_deferred()


func _process(_delta: float) -> void:
	# Pulse the side-nav tile the current tutorial step points at ("phone:leads" -> PHONE until it is open).
	var target := Tutorial.highlight()
	if target.begins_with("phone:") and _active_nav == &"phone":
		target = ""
	target = target.get_slice(":", 0)
	var lit := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for b in _nav_buttons:
		b.modulate = HIGHLIGHT_TINT if (lit and target != "" and String(b.id) == target) else Color.WHITE
	# Portrait: a secondary item lives in the MORE sheet, so point at MORE while it is closed.
	var more_lit := lit and _more_button.visible and not _more_sheet.visible and StringName(target) in MOBILE_SECONDARY
	_more_button.modulate = HIGHLIGHT_TINT if more_lit else Color.WHITE


## Pixel: 9-slice frame and portrait slot from the Sales Simulator dialog box (tools/build_tutorial_frame.gd).
## Classic: the theme's flat panel and no slot frame, exactly as before G1b.
func _apply_tutorial_frame() -> void:
	if tutorial_frame == TutorialFrame.PIXEL:
		tutorial.add_theme_stylebox_override(&"panel", PIXEL_TUTORIAL_FRAME)
		tutorial_portrait_frame.add_theme_stylebox_override(&"panel", PIXEL_PORTRAIT_SLOT)
	else:
		tutorial.remove_theme_stylebox_override(&"panel")
		tutorial_portrait_frame.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())


func _on_tutorial_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Tutorial.notify("click")
		accept_event()


# --- Responsive layout --------------------------------------------------------------
# Desktop uses the scene layout unchanged. Mobile landscape keeps it but collapses the task card
# and uses the touch action button. Portrait phones get a compact two-row top bar, a one-line
# objective bar, a 5-tab bottom bar (TASKS PHONE TRAVEL INVENTORY MORE; MORE holds DEALS and
# FINANCE, the SAME nav buttons) and a bottom-sheet tutorial. LayoutSwap restores the scene values.

func apply_layout(portrait_mode: bool) -> void:
	portrait = portrait_mode
	compact = Responsive.mode != Responsive.Mode.DESKTOP
	# Keyboard hints depend on the device, not the layout (a short desktop window keeps them).
	touch_ui = DisplayServer.is_touchscreen_available()
	# Portrait -> portrait (e.g. phone -> tablet width) re-applies on top; anything else starts
	# from the scene layout. (Round-tripping through desktop leaves stale minimum sizes.)
	if not (portrait and _mobile_rows != null and _mobile_rows.visible):
		apply_desktop_layout()
	if portrait:
		apply_mobile_portrait_layout()
	elif compact:
		# Short landscape screens: keep the nav rail below the top bar (slightly shorter tiles).
		_swap(nav_rail, {"offset_top": -196.0, "offset_bottom": 262.0})
		for b in _nav_buttons:
			_swap(b, {"custom_minimum_size": Vector2(84, 62)})
	_apply_objective_mode()
	refresh()
	_update_interact()
	_place_prompt.call_deferred()


func apply_desktop_layout() -> void:
	_set_stat_rows(false)
	for c in _swapped:
		LayoutSwap.restore(c)
	_swapped.clear()
	_set_secondary_in_sheet(false)
	nav_list.vertical = true
	for b in _nav_buttons:
		b.set_compact(false)


func apply_mobile_portrait_layout() -> void:
	var m := MOBILE_MARGIN
	_set_stat_rows(true)
	var bar_style := top_bar.get_theme_stylebox(&"panel").duplicate() as StyleBox
	bar_style.content_margin_left = 10.0
	bar_style.content_margin_right = 10.0
	bar_style.content_margin_top = 5.0
	bar_style.content_margin_bottom = 5.0
	_swap(top_bar, {"offset_left": m, "offset_top": m + SAFE_TOP, "offset_right": -m, "offset_bottom": m + SAFE_TOP,
		"theme_override_styles/panel": bar_style})
	# Compact stats: no captions, small icons, one font size.
	for block: StatBlock in [day_block, clock_block, cash_block, rep_block, leads_block]:
		_swap(block, {"custom_minimum_size": Vector2.ZERO, "theme_override_constants/separation": 5})
		_swap(block.get_node("Text/Caption"), {"visible": false})
		_swap(block.get_node("Text/Value"), {"theme_override_font_sizes/font_size": 15})
		_swap(block.get_node("Icon"), {"custom_minimum_size": Vector2(18, 18)})
	# The time-of-day caption stays (small) above the clock.
	_swap(clock_block.get_node("Text/Caption"), {"visible": true, "theme_override_font_sizes/font_size": 10})
	for block in [clock_block, cash_block, rep_block, leads_block]:
		_swap(block, {"size_flags_horizontal": Control.SIZE_EXPAND_FILL})
	_swap(level_box, {"custom_minimum_size": Vector2(118, 0), "theme_override_constants/separation": 2})
	_swap(level_label, {"theme_override_font_sizes/font_size": 15})
	_swap(xp_label, {"theme_override_font_sizes/font_size": 11})
	_swap(xp_bar, {"custom_minimum_size": Vector2(0, 6)})
	var below_bar := m + SAFE_TOP + top_bar.get_combined_minimum_size().y + 4.0
	_swap(objective, {"anchor_left": 0.0, "anchor_right": 1.0,
		"offset_left": m, "offset_top": below_bar, "offset_right": -m, "offset_bottom": below_bar})
	# Toast: full width with wrapping, so long or two-line notices never run off a narrow screen.
	_swap(toast_panel, {"anchor_left": 0.0, "anchor_right": 1.0, "offset_left": m + 8.0, "offset_right": -m - 8.0,
		"offset_top": below_bar + 2.0, "offset_bottom": below_bar + 38.0})
	_swap(toast_label, {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(10, 0)})
	# Side rail -> bottom bar (same NavButtons, same signals); DEALS / FINANCE move into MORE.
	var nav_bottom := m + SAFE_BOTTOM
	_swap(nav_list, {"theme_override_constants/separation": 4})
	nav_list.vertical = false
	for b in _nav_buttons:
		b.set_compact(true)
	_set_secondary_in_sheet(true)
	_swap(nav_rail, {"anchor_left": 0.0, "anchor_top": 1.0, "anchor_right": 1.0, "anchor_bottom": 1.0,
		"offset_left": m, "offset_top": -(_nav_height() + nav_bottom), "offset_right": -m, "offset_bottom": -nav_bottom,
		"grow_vertical": Control.GROW_DIRECTION_BEGIN})
	var above_nav := _nav_height() + nav_bottom + 4.0
	_swap(_more_sheet, {"offset_right": -m, "offset_bottom": -above_nav, "offset_left": -m - 200.0, "offset_top": -above_nav - 66.0})
	# Tutorial: bottom sheet just above the bar, readable text, big SKIP target.
	_swap(tutorial, {"anchor_left": 0.0, "anchor_top": 1.0, "anchor_right": 1.0, "anchor_bottom": 1.0,
		"offset_left": m, "offset_top": -above_nav, "offset_right": -m, "offset_bottom": -above_nav})
	var sizes := {tip_title: 17, tip_body: 15, hint_label: 13, next_label: 15, skip_button: 14}
	for c in sizes:
		_swap(c, {"theme_override_font_sizes/font_size": sizes[c]})
	_swap(next_label, {"theme_type_variation": &"BlueTitle"})
	_swap(skip_button, {"custom_minimum_size": Vector2(64, 40)})
	_swap(hint_sub, {"visible": false})
	_swap(tutorial_portrait, {"custom_minimum_size": Vector2(48, 64)})


## Mobile: the task card becomes a one-line bar ("[icon] Go to Coffee Corner  2/7  +");
## tapping it shows / hides the description. Desktop keeps the full card (tap opens TASKS).
func _apply_objective_mode() -> void:
	_obj_bar.visible = compact
	if not compact:
		return
	_swap(objective_head, {"visible": false})
	_swap(objective_title, {"visible": false})
	_swap(objective_desc, {"visible": _objective_expanded})
	if not portrait:  # the scene card has a fixed height; let the bar shrink to its content
		_swap(objective, {"offset_bottom": objective.offset_top})
	_obj_bar_toggle.text = "-" if _objective_expanded else "+"
	objective.tooltip_text = "Show / hide details"


## Screen space the portrait HUD covers above / below the room (for the camera and overlays).
## Built from minimum sizes, so it is valid before the HUD's first layout pass.
func get_portrait_insets(include_cards := true) -> Vector2:
	var top := MOBILE_MARGIN + SAFE_TOP + top_bar.get_combined_minimum_size().y + 6.0
	if include_cards and objective.visible:
		top += objective.get_combined_minimum_size().y + 4.0
	var bottom := _nav_height() + MOBILE_MARGIN + SAFE_BOTTOM + 6.0
	if include_cards and tutorial.visible:
		bottom += tutorial.get_combined_minimum_size().y + 2.0
	return Vector2(top, bottom)


## Portrait bottom bar height (the real minimum size of the bar, never less than MOBILE_NAV_HEIGHT).
func _nav_height() -> float:
	return maxf(MOBILE_NAV_HEIGHT, nav_rail.get_combined_minimum_size().y)


func _swap(c: Control, values: Dictionary) -> void:
	if not _swapped.has(c):
		_swapped.append(c)
	LayoutSwap.apply(c, values)


## Portrait: split the single stat row into two rows (date + level, then time; cash, reputation
## and leads ride along hidden).
## The stat nodes are moved, not duplicated, so every existing reference keeps working.
func _set_stat_rows(two_rows: bool) -> void:
	if _scene_row_order.is_empty():
		_scene_row_order.assign(stat_row.get_children())
	if two_rows:
		if _mobile_rows == null:
			_mobile_rows = VBoxContainer.new()
			_mobile_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_mobile_rows.add_theme_constant_override(&"separation", 3)
			for i in 2:
				var row := HBoxContainer.new()
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_theme_constant_override(&"separation", 10)
				_mobile_rows.add_child(row)
			_mobile_spacer = Control.new()
			_mobile_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_mobile_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_mobile_rows.get_child(0).add_child(_mobile_spacer)
			top_bar.add_child(_mobile_rows)
		var row1: HBoxContainer = _mobile_rows.get_child(0)
		var row2: HBoxContainer = _mobile_rows.get_child(1)
		for n in [day_block, level_box]:
			n.reparent(row1, false)
		for n in [clock_block, cash_block, rep_block, leads_block]:
			n.reparent(row2, false)
		row1.move_child(day_block, 0)
		row1.move_child(_mobile_spacer, 1)
		row1.move_child(level_box, 2)
		stat_row.hide()
		_mobile_rows.show()
	elif _mobile_rows != null:
		for i in _scene_row_order.size():
			var n := _scene_row_order[i]
			if n.get_parent() != stat_row:
				n.reparent(stat_row, false)
			stat_row.move_child(n, i)
		stat_row.show()
		_mobile_rows.hide()


## Portrait: keep the action button / prompt above the bottom bar and the tutorial sheet.
func _place_prompt() -> void:
	_place_interact()
	if compact:
		# After a live resize / rotation the cards may still be sized for the previous layout:
		# shrink them back to their (new) content.
		objective.offset_bottom = objective.offset_top
	if not portrait:
		return
	top_bar.offset_bottom = top_bar.offset_top
	tutorial.offset_top = tutorial.offset_bottom
	var bottom := get_portrait_insets().y + 4.0
	_swap(prompt_panel, {"offset_top": -(bottom + 46.0), "offset_bottom": -bottom})
	portrait_insets_changed.emit()


func _place_interact() -> void:
	var b := _interact_button
	if portrait:
		var bottom := get_portrait_insets().y + 10.0
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.offset_right = -12.0
		b.offset_left = -12.0 - b.custom_minimum_size.x
		b.offset_bottom = -bottom
		b.offset_top = -bottom - b.custom_minimum_size.y
	else:
		b.anchor_left = 0.5
		b.anchor_right = 0.5
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH
		b.offset_left = -b.custom_minimum_size.x / 2.0
		b.offset_right = b.custom_minimum_size.x / 2.0
		b.offset_bottom = -18.0
		b.offset_top = -18.0 - b.custom_minimum_size.y


# --- Mobile-only controls (built at runtime, hidden on desktop) --------------------------

func _build_mobile_controls() -> void:
	# MORE tab (portrait bottom bar) + its sheet holding the secondary nav buttons.
	_more_button = NAV_BUTTON_SCENE.instantiate()
	_more_button.name = "More"
	_more_button.id = &"more"
	_more_button.label = "MORE"
	_more_button.icon_size = Vector2(0, 0)
	_more_button.tooltip_text = "Deals, Finance"
	nav_list.add_child(_more_button)
	var dots := Label.new()
	dots.text = "..."
	dots.theme_type_variation = &"GoldTitle"
	dots.add_theme_font_size_override(&"font_size", 20)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more_button.get_node("Content").add_child(dots)
	_more_button.get_node("Content").move_child(dots, 0)
	_more_button.chosen.connect(func(_id): _set_more_open(not _more_sheet.visible))
	_more_button.hide()

	_more_sheet = PanelContainer.new()
	_more_sheet.name = "MoreSheet"
	_more_sheet.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_more_sheet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_more_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_more_list = HBoxContainer.new()
	_more_list.add_theme_constant_override(&"separation", 6)
	_more_sheet.add_child(_more_list)
	add_child(_more_sheet)
	_more_sheet.hide()

	# Large contextual action button (every platform): same "interact" action as the E key.
	_interact_button = Button.new()
	_interact_button.name = "InteractButton"
	_interact_button.theme_type_variation = &"PrimaryButton"
	_interact_button.focus_mode = Control.FOCUS_NONE
	_interact_button.custom_minimum_size = Vector2(150, 56)
	_interact_button.add_theme_font_size_override(&"font_size", 20)
	_interact_button.anchor_top = 1.0
	_interact_button.anchor_bottom = 1.0
	_interact_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_interact_button.pressed.connect(_on_interact_pressed)
	add_child(_interact_button)
	_interact_button.hide()

	# One-line objective bar (mobile).
	_obj_bar = HBoxContainer.new()
	_obj_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_bar.add_theme_constant_override(&"separation", 8)
	var pin := TextureRect.new()
	pin.texture = TASK_ICON
	pin.custom_minimum_size = Vector2(18, 18)
	pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_bar.add_child(pin)
	_obj_bar_title = Label.new()
	_obj_bar_title.theme_type_variation = &"GoldTitle"
	_obj_bar_title.add_theme_font_size_override(&"font_size", 15)
	_obj_bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_bar_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_obj_bar_title.clip_text = true
	_obj_bar.add_child(_obj_bar_title)
	_obj_bar_count = Label.new()
	_obj_bar_count.theme_type_variation = &"CaptionLabel"
	_obj_bar.add_child(_obj_bar_count)
	_obj_bar_toggle = Label.new()
	_obj_bar_toggle.theme_type_variation = &"GoldTitle"
	_obj_bar_toggle.custom_minimum_size = Vector2(14, 0)
	_obj_bar_toggle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_bar.add_child(_obj_bar_toggle)
	var vbox := objective.get_node("VBox")
	vbox.add_child(_obj_bar)
	vbox.move_child(_obj_bar, 0)
	_obj_bar.hide()


## Portrait: DEALS / FINANCE live in the MORE sheet; elsewhere they are back in the nav list.
func _set_secondary_in_sheet(on: bool) -> void:
	_more_button.visible = on
	if not on:
		_set_more_open(false)
	for b in _nav_buttons:
		if not b.id in MOBILE_SECONDARY:
			continue
		var target: Node = _more_list if on else nav_list
		if b.get_parent() != target:
			b.reparent(target, false)
	if not on:
		for i in _nav_order.size():
			nav_list.move_child(_nav_order[i], i)
		nav_list.move_child(_more_button, -1)
	else:
		nav_list.move_child(_more_button, -1)


func _set_more_open(open: bool) -> void:
	if _more_sheet == null:
		return
	_more_sheet.visible = open and _more_button.visible
	_update_more_button()
	_update_interact()


func _update_more_button() -> void:
	if _more_button:
		_more_button.set_active(_more_sheet.visible or _active_nav in MOBILE_SECONDARY)


## Same path as pressing E: the player's _unhandled_input receives the "interact" action.
func _on_interact_pressed() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"interact"
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _on_objective_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if compact:
			_objective_expanded = not _objective_expanded
			_apply_objective_mode()
			_place_prompt.call_deferred()
		else:
			nav_selected.emit(&"tasks")
