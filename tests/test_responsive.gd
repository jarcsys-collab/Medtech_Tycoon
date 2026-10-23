extends RefCounted
## G1c mobile portrait layout on the real main scene (temp saves; see test_runner.gd): the UI base
## for phone widths and pixel ratios, nothing past the screen edges, and the important controls
## reachable and clickable (real mouse events pushed into the viewport, so a covered button fails).

const MAIN_SCENE := "res://scenes/main/main.tscn"
const MAIN_SCRIPT := "res://scripts/main/main.gd"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Coffee Corner, 8:40 AM, level 2
## Phone CSS widths from the G1c brief (small Android, iPhone 12-15, iPhone Pro Max), portrait.
const PHONES := [Vector2i(360, 780), Vector2i(390, 844), Vector2i(430, 932)]
## Short portrait screen (browser bars showing) for the vertical checks.
const SHORT_PHONE := Vector2i(360, 640)

var t  # test runner
var _orig_size: Vector2i
var _orig_min: Vector2i


func test_layout_base_for_phone_widths_and_pixel_ratios() -> void:
	var desktop := Vector2i(1280, 720)
	for css in PHONES:
		for dpr in [1.0, 2.0, 3.0, 2.625]:
			var r: Array = Responsive.layout_for(Vector2(css) * dpr, dpr, desktop)
			var label := "%dx%d @%sx" % [css.x, css.y, dpr]
			t.check_eq(r[0], Responsive.Mode.MOBILE_PORTRAIT, label + " is portrait")
			t.check_eq(r[1].x, roundi(maxf(css.x, Responsive.PORTRAIT_MIN_WIDTH)), label + " UI width follows the CSS width")
	t.check_eq(Responsive.layout_for(Vector2(1280, 720), 1.0, desktop), [Responsive.Mode.DESKTOP, desktop], "desktop base unchanged")
	t.check_eq(Responsive.layout_for(Vector2(1688, 780), 2.0, desktop), [Responsive.Mode.MOBILE_LANDSCAPE, Responsive.LANDSCAPE_BASE],
		"phone landscape base unchanged")


## Root cause of the portrait overflow: the desktop minimum window (960x540) also applied on the
## web, so Godot laid out for a 960 px window while a phone canvas is 720-1290 px wide.
func test_no_minimum_window_on_the_web() -> void:
	var main_script := load(MAIN_SCRIPT)
	t.check_eq(main_script.min_window_size(true), Vector2i.ZERO, "web: no minimum window size")
	t.check_eq(main_script.min_window_size(false), Vector2i(960, 540), "desktop keeps its 960x540 minimum")


func test_portrait_nothing_past_the_screen_edges() -> void:
	var main := await _boot()
	for css in PHONES + [SHORT_PHONE]:
		await _resize(main, css)
		var at := "%dx%d" % [css.x, css.y]
		t.check(Responsive.is_portrait(), at + " portrait layout")
		Tutorial.restart()
		await _settle()
		_check_fits(main, at + " home + tutorial")
		main.select(&"phone")
		await _settle()
		_check_fits(main, at + " phone")
		main.phone.open_page(&"leads")
		await _settle()
		_check_fits(main, at + " phone leads page")
		main.select(&"tasks")
		await _settle()
		_check_fits(main, at + " tasks")
		main.select(&"travel")
		await _settle()
		_check_fits(main, at + " travel map", true)
		for pin: MapPin in main.travel_map._pins.values():
			var tip_x := pin.position.x + pin.size.x / 2.0 + pin._pin_shift
			t.check(absf(tip_x - pin.anchor_point.x) < 0.5, "%s pin %s tip stays on its spot" % [at, pin.location.id])
		main.select(&"travel")
		main.hud._set_more_open(true)
		await _settle()
		_check_fits(main, at + " MORE sheet")
		main.hud._set_more_open(false)
		UIEvents.ask("Go to sleep?", "End the day and wake up tomorrow morning.", [UIEvents.option("Sleep", Callable(), false, true), UIEvents.option("Not yet")])
		await _settle()
		_check_fits(main, at + " dialog")
		main.choice_dialog.close()
		Tutorial.skip()
		await _settle()
	await _shutdown(main)


func test_portrait_controls_reachable_and_clickable() -> void:
	var main := await _boot()
	var hud: Hud = main.hud
	for css in PHONES + [SHORT_PHONE]:
		await _resize(main, css)
		var at := "%dx%d " % [css.x, css.y]
		main._close_overlays()
		Tutorial.restart()
		await _settle()
		# Five bottom-bar controls: each one opens (or toggles) its menu.
		for id in [&"tasks", &"phone", &"travel", &"inventory"]:
			await _click(hud.nav_list.get_node(String(id).capitalize()), at + String(id))
			await _settle()
			t.check_eq(main.active, id, at + "%s tab opens its menu" % id)
			main._close_overlays()
			await _settle()
		await _click(hud._more_button, at + "MORE")
		await _settle()
		t.check(hud._more_sheet.visible, at + "MORE opens its sheet")
		for b: NavButton in hud._more_list.get_children():
			_check_on_screen(b, at + "MORE sheet " + b.label)
		await _click(hud._more_list.get_node("Finance"), at + "MORE > FINANCE")
		await _settle()
		t.check_eq(main.active, &"finance", at + "FINANCE opens from the MORE sheet")
		await _click(main.info_panel.close_button, at + "panel close X")
		await _settle()
		t.check_eq(main.active, &"", at + "close X closes the panel")
		# Sales Phone: open a page, then back.
		main.select(&"phone")
		await _settle()
		await _click(main.phone.home.get_node("Collections"), at + "last phone row")
		await _settle()
		t.check(main.phone.page.visible, at + "phone page opens")
		await _click(main.phone.back_button, at + "phone back")
		await _settle()
		t.check(not main.phone.page.visible, at + "back returns to the phone home")
		main._close_overlays()
		# Dialog buttons.
		UIEvents.ask("Go to sleep?", "End the day and wake up tomorrow morning.", [UIEvents.option("Sleep", Callable(), false, true), UIEvents.option("Not yet")])
		await _settle()
		var buttons: Array = main.choice_dialog.buttons.get_children()
		await _click(buttons[buttons.size() - 1], at + "dialog button")
		await _settle()
		t.check(not main.choice_dialog.visible, at + "dialog button closes the dialog")
		Tutorial.skip()
	await _shutdown(main)


## The full tutorial loop with clicks only: SKIP on the card, TASKS in the bottom bar, REPLAY in the panel.
func test_portrait_skip_tasks_replay_by_clicks() -> void:
	var main := await _boot()
	var hud: Hud = main.hud
	for css in PHONES + [SHORT_PHONE]:
		await _resize(main, css)
		var at := "%dx%d " % [css.x, css.y]
		main._close_overlays()
		Tutorial.restart()
		await _settle()
		t.check(hud.tutorial.visible, at + "tutorial card showing")
		await _click(hud.skip_button, at + "SKIP")
		await _settle()
		t.check(not hud.tutorial.visible and not Tutorial.is_active(), at + "SKIP hides the tutorial")
		await _click(hud.nav_list.get_node("Tasks"), at + "TASKS")
		await _settle()
		t.check(main.info_panel.visible and main.info_panel.mode == &"tasks", at + "TASKS opens the task list")
		var replay: Button = main.info_panel.footer.get_node_or_null("ReplayButton")
		t.check(replay != null, at + "REPLAY button present")
		if replay == null:
			continue
		t.check(not _in_scroll(replay), at + "REPLAY pinned below the list (never scrolled away)")
		await _click(replay, at + "REPLAY")
		await _settle()
		t.check(Tutorial.is_active() and hud.tutorial.visible and hud.step_count.text.begins_with("1/"), at + "REPLAY restarts the tutorial at step 1")
		t.check(not main.info_panel.visible, at + "REPLAY closes the panel")
		Tutorial.skip()
	await _shutdown(main)


## Touch action button (replaces the [E] prompt on phones) sits above the bottom bar and works.
func test_portrait_interaction_button() -> void:
	var main := await _boot({"location_id": "home"})
	for css in PHONES:
		await _resize(main, css)
		var at := "%dx%d " % [css.x, css.y]
		main._close_overlays()
		main.player.wander_when_idle = false
		main.player.global_position = Vector2(330, 1150)  # next to the bed
		await _settle()
		var b: Button = main.hud._interact_button
		t.check(b.visible, at + "action button shown in reach of the bed")
		_check_on_screen(b, at + "action button")
		t.check(b.get_global_rect().end.y <= main.hud.nav_rail.get_global_rect().position.y, at + "action button above the bottom bar")
		await _click(b, at + "action button")
		await _settle()
		t.check(main.choice_dialog.visible, at + "action button opens 'Go to sleep?'")
		main.choice_dialog.close()
		main.player.global_position = Vector2(470, 900)
		await _settle()
	await _shutdown(main)


## Desktop and phone-landscape layouts come back exactly as they were after a trip through portrait.
func test_desktop_and_landscape_layouts_unchanged() -> void:
	var main := await _boot()
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		await _resize(main, size)
		Tutorial.restart()
		await _settle()
		var before := _layout_snapshot(main)
		t.check(not Responsive.is_portrait(), "%s is not portrait" % size)
		await _resize(main, PHONES[1])
		await _resize(main, size)
		Tutorial.restart()
		await _settle()
		t.check_eq(_layout_snapshot(main), before, "%s layout identical after portrait" % size)
		Tutorial.skip()
		main.select(&"travel")
		await _settle()
		for pin: MapPin in main.travel_map._pins.values():
			t.check_eq(pin._pin_shift, 0.0, "%s map: pin %s name tag still centred on its pin" % [size, pin.location.id])
		main._close_overlays()
	await _shutdown(main)


# --- Helpers --------------------------------------------------------------------

func _boot(overrides := {}) -> Node:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	for k in overrides:
		data.state[k] = overrides[k]
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var win: Window = t.get_window()
	_orig_size = win.size
	_orig_min = win.min_size
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	return main


## Headless stand-in for a browser resize (CSS px at devicePixelRatio 1; see the base test for 2-3x).
func _resize(main: Node, css: Vector2i) -> void:
	var win: Window = t.get_window()
	win.min_size = Vector2i.ZERO  # as on the web
	win.size = css
	Responsive.update_responsive_layout()
	main.update_responsive_layout()
	await _settle()


func _settle() -> void:
	await _wait(0.45)


## Every visible UI control lies inside the screen horizontally; outside scroll areas also vertically.
func _check_fits(main: Node, what: String, map := false) -> void:
	var view := main.get_viewport().get_visible_rect()
	var bad: Array[String] = []
	for c in main.get_node("UI").find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size == Vector2.ZERO:
			continue
		var r := ctl.get_global_rect()
		var horiz_ok := r.position.x >= -0.5 and r.end.x <= view.size.x + 0.5
		var vert_ok := _in_scroll(ctl) or (r.position.y >= -0.5 and r.end.y <= view.size.y + 0.5)
		# The map art is a moving picture behind the pins; only its frame has to fit.
		if map and (ctl.name in [&"Backdrop", &"MapImage"]):
			continue
		if not (horiz_ok and vert_ok):
			bad.append("%s %s" % [main.get_path_to(ctl), r])
	t.check(bad.is_empty(), "%s: everything on screen (%s)" % [what, ", ".join(bad.slice(0, 6))])


func _check_on_screen(c: Control, what: String) -> void:
	var view := c.get_viewport().get_visible_rect()
	t.check(c.is_visible_in_tree() and view.encloses(c.get_global_rect().grow(-0.5)), "%s on screen (%s)" % [what, c.get_global_rect()])


## Scroll the control into view if needed, check it is on screen, then click its centre with real
## mouse events. Whatever is on top receives the click, so a covered control is reported here.
func _click(c: Control, what: String) -> void:
	var scroll := _scroll_parent(c)
	if scroll:
		scroll.ensure_control_visible(c)
		await t.get_tree().process_frame
		await t.get_tree().process_frame
	_check_on_screen(c, what)
	if scroll:
		t.check(scroll.get_global_rect().grow(0.5).encloses(c.get_global_rect()), what + " scrolled into view")
	var pos := c.get_global_rect().get_center()
	var vp := c.get_viewport()
	t.check(_topmost_at(vp, pos, c), what + " is not covered")
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	vp.push_input(move, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev, true)
		await t.get_tree().process_frame


## The control (or one of its children) is what the GUI would hit at `pos`.
static func _topmost_at(vp: Viewport, pos: Vector2, c: Control) -> bool:
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	vp.push_input(move, true)
	var hit := vp.gui_get_hovered_control()
	return hit != null and (hit == c or c.is_ancestor_of(hit))


static func _scroll_parent(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


static func _in_scroll(c: Node) -> bool:
	return _scroll_parent(c) != null


static func _layout_snapshot(main: Node) -> Dictionary:
	var hud: Hud = main.hud
	var out := {"base": main.get_window().content_scale_size}
	for c: Control in [hud.top_bar, hud.nav_rail, hud.objective, hud.tutorial, hud.skip_button, main.phone.get_node("Frame"),
			main.info_panel, main.choice_dialog.panel]:
		out[c.name] = [c.anchor_left, c.anchor_right, c.offset_left, c.offset_top, c.offset_right, c.offset_bottom, c.custom_minimum_size]
	for b in hud._nav_buttons:
		out[b.name] = [b.get_parent().name, b.custom_minimum_size]
	return out


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame
	var win: Window = t.get_window()
	win.min_size = Vector2i.ZERO
	win.size = _orig_size
	win.min_size = _orig_min
	Responsive.update_responsive_layout()


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
