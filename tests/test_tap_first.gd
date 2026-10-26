extends RefCounted
## B1 (Sales Simulator handoff): tap-first play on the real main scene (temp saves; see test_runner.gd).
## Tap a person or object to walk up and select it, then use the action button; keyboard (WASD + E)
## stays optional on desktop. Top bar shows date and time of day only; navigation leads with TO-DO
## and PHONE without stranding any feature. Headless runs as a desktop without a touchscreen.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Coffee Corner, 8:40 AM, level 2, cash 10,422
const BED_SPOT := Vector2(330, 1150)
const HOME_SPAWN_AREA := Vector2(470, 900)
## Words that only make sense with a keyboard; must not appear in tap-first text.
const KEYBOARD_WORDS := ["WASD", "press E", "(E)", "Arrow", "arrow keys", "press P", "press M", "Space"]

var t  # test runner


func test_top_bar_shows_date_and_time_only() -> void:
	var main := await _boot_from_fixture()
	var hud: Hud = main.hud
	for portrait in [false, true]:
		hud.apply_layout(portrait)
		await t.get_tree().process_frame
		var at := "portrait" if portrait else "desktop"
		t.check(hud.day_block.is_visible_in_tree() and hud.clock_block.is_visible_in_tree(), at + ": date and clock shown")
		t.check(hud.clock_block.get_node("Text/Caption").is_visible_in_tree(), at + ": time of day shown")
		for block: StatBlock in [hud.cash_block, hud.rep_block, hud.leads_block]:
			t.check(not block.is_visible_in_tree(), "%s: %s not in the top bar" % [at, block.name])
		# Energy and stamina are cancelled (2026-10-26): nothing in the top bar reserves space for them.
		for n in hud.top_bar.find_children("*", "", true, false):
			t.check(not n.name.to_lower().contains("energy"), "%s: no energy placeholder (%s)" % [at, n.name])
	hud.apply_layout(false)
	# The values still exist and stay current; they are shown elsewhere.
	t.check_eq(hud.cash_block.value, "$10,422", "cash value still tracked")
	GameState.add_cash(100)
	await t.get_tree().process_frame
	t.check_eq(hud.cash_block.value, "$10,522", "cash value still updates")
	main.select(&"finance")
	await _wait(0.3)
	t.check(_panel_mentions(main.info_panel, "$10,522"), "FINANCE shows the cash")
	t.check(_panel_mentions(main.info_panel, "%d%%" % GameState.reputation), "FINANCE shows the reputation")
	t.check(_panel_mentions(main.info_panel, "Leads"), "FINANCE shows the lead count")
	main.select(&"phone")
	await _wait(0.3)
	t.check_eq((main.phone.home.get_node("Leads") as PhoneRow).subtitle, "%d open leads" % GameState.leads.size(), "phone shows the lead count")
	await _shutdown(main)


func test_navigation_leads_with_todo_and_phone() -> void:
	var main := await _boot_from_fixture()
	var hud: Hud = main.hud
	var tasks: NavButton = hud.nav_list.get_node("Tasks")
	t.check_eq(tasks.label, "TO-DO", "TASKS is now TO-DO")
	var order: Array = hud.nav_list.get_children().filter(func(b): return b.visible).map(func(b): return String(b.name))
	t.check_eq(order.slice(0, 2), ["Tasks", "Phone"], "desktop: TO-DO and PHONE first")
	t.check_eq(order.size(), 6, "desktop: every feature still has its tile")
	for id in [&"tasks", &"phone", &"travel", &"deals", &"inventory", &"finance"]:
		main.select(id)
		await _wait(0.25)
		t.check_eq(main.active, id, "desktop: %s still opens" % id)
		main._close_overlays()
	await _shutdown(main)


func test_tap_selects_then_action_button_acts() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var player: Player = main.player
	var hud: Hud = main.hud
	var bed: Interactable = main.current_location.get_node("Bed")
	player.wander_when_idle = false
	player.global_position = HOME_SPAWN_AREA
	await _wait(0.3)
	t.check_eq(player.current_focus(), null, "nothing in reach at the start")
	player.tap_at(bed.global_position)
	for i in 240:
		await t.get_tree().physics_frame
		if player.current_focus() == bed:
			break
	await _wait(0.3)
	t.check(player.current_focus() == bed, "tapping the bed walks up and selects it")
	t.check(not main.choice_dialog.visible, "selecting does not act by itself (the handoff's tap-then-button)")
	t.check(hud._interact_button.visible and hud._interact_button.text == bed.get_prompt(), "action button shows '%s'" % bed.get_prompt())
	t.check(not hud.prompt_panel.visible, "no '[E] Sleep' key prompt; the button replaces it")
	await _click(hud._interact_button)
	await _wait(0.2)
	t.check(main.choice_dialog.visible, "action button opens 'Go to sleep?' (no keyboard needed)")
	main.choice_dialog.close()
	await _shutdown(main)


## Found in the browser smoke test: the player wandered off a tapped bed after the 4 s idle hold,
## the button faded and the next click fell through to the floor.
func test_selection_keeps_player_beside_target() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var player: Player = main.player
	var bed: Interactable = main.current_location.get_node("Bed")
	player.wander_when_idle = true
	player.tap_at(bed.global_position)
	for i in 240:
		await t.get_tree().physics_frame
		if player.current_focus() == bed:
			break
	var at := player.global_position
	await _wait(player.idle_before_wander + 2.5)
	t.check(player.current_focus() == bed, "bed still selected after the idle time")
	t.check(player.global_position.distance_to(at) < 2.0, "player waits beside the bed (moved %.1f px)" % player.global_position.distance_to(at))
	t.check(main.hud._interact_button.visible, "action button still there")
	player.tap_at(HOME_SPAWN_AREA)
	await _wait(1.0)
	t.check(player.global_position.distance_to(at) > 20.0, "tapping the floor releases the selection and walks")
	await _shutdown(main)


## Found in the browser smoke test: in portrait the action button covered the MORE sheet's tiles.
func test_more_sheet_is_not_covered_by_the_action_button() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var hud: Hud = main.hud
	var win: Window = t.get_window()
	var size := win.size
	var min_size := win.min_size
	win.min_size = Vector2i.ZERO
	win.size = Vector2i(390, 844)
	Responsive.update_responsive_layout()
	main.update_responsive_layout()
	main.player.wander_when_idle = false
	main.player.global_position = BED_SPOT
	await _wait(0.6)
	t.check(hud._interact_button.visible, "portrait: action button for the bed")
	await _click(hud._more_button)
	await _wait(0.4)
	t.check(hud._more_sheet.visible and not hud._interact_button.visible, "MORE open: the action button steps aside")
	await _click(hud._more_list.get_node("Inventory"))
	await _wait(0.4)
	t.check_eq(main.active, &"inventory", "INVENTORY in the MORE sheet is clickable")
	t.check(not main.choice_dialog.visible, "the tap did not reach the bed's action")
	main._close_overlays()
	await _wait(0.4)
	t.check(hud._interact_button.visible, "action button back after closing")
	win.size = size
	win.min_size = min_size
	Responsive.update_responsive_layout()
	await _shutdown(main)


func test_keyboard_stays_optional_on_desktop() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var player: Player = main.player
	var hud: Hud = main.hud
	t.check(not hud.touch_ui, "headless desktop counts as a keyboard device")
	t.check(not main.marker.touch_mode, "keyboard devices keep the [E] badge")
	player.wander_when_idle = false
	player.global_position = BED_SPOT
	await _wait(0.4)
	t.check(player.current_focus() == main.current_location.get_node("Bed"), "bed in reach")
	t.check_eq(hud._interact_button.tooltip_text, "Or press E", "button mentions the E shortcut on desktop")
	await _press_action(&"interact")
	await _wait(0.2)
	t.check(main.choice_dialog.visible, "E still uses what is in reach")
	main.choice_dialog.close()
	await _wait(0.2)
	var start := player.global_position
	Input.action_press(&"move_up")
	for i in 20:
		await t.get_tree().physics_frame
	Input.action_release(&"move_up")
	t.check(player.global_position.distance_to(start) > 20.0, "WASD still walks (moved %.0f px)" % player.global_position.distance_to(start))
	await _shutdown(main)


func test_touch_devices_get_no_keyboard_hints() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var hud: Hud = main.hud
	hud.touch_ui = true
	main.marker.touch_mode = true
	Tutorial.restart()
	for i in Tutorial.STEPS.size():
		var step: Dictionary = Tutorial.STEPS[i]
		for key in ["title", "body", "hint", "sub"]:
			for word in KEYBOARD_WORDS:
				t.check(not String(step.get(key, "")).contains(word), "step %s %s has no '%s'" % [step.id, key, word])
	for task in GameData.TASKS:
		for word in KEYBOARD_WORDS:
			t.check(not String(task.desc).contains(word), "task %s has no '%s'" % [task.id, word])
	Tutorial.skip()
	Tutorial.restart()
	Tutorial.notify("click")  # step 2: "Move Around"
	await t.get_tree().process_frame
	t.check_eq(hud.hint_label.text, Tutorial.STEPS[1].hint, "touch: tap hint")
	hud.touch_ui = false
	hud.refresh()
	t.check_eq(hud.hint_label.text, Tutorial.STEPS[1].hint_keys, "keyboard: hint adds the key shortcut")
	Tutorial.skip()
	player_bed_button_on_touch(main)
	await _shutdown(main)


func player_bed_button_on_touch(main: Node) -> void:
	main.hud.touch_ui = true
	main.hud._update_interact()
	t.check_eq(main.hud._interact_button.tooltip_text, "", "touch: the button has no key hint")


func test_patrons_cannot_be_selected() -> void:
	var main := await _boot_from_fixture({"minutes": 13 * 60})
	var cafe = main.current_location
	var player: Player = main.player
	player.wander_when_idle = false
	for patron: Customer in cafe.patrons():
		for offset in [Vector2.ZERO, Vector2(0, -60), Vector2(0, -120)]:
			t.check(player._pick_interactable(patron.global_position + offset) != patron.talk, "a tap on a patron never picks the patron")
	var c: Customer = cafe.prospect_customers()[0]
	player.tap_at(c.global_position)
	for i in 900:  # the café path around the tables can take ~8 s
		await t.get_tree().physics_frame
		if player.current_focus() == c.talk:
			break
	t.check(player.current_focus() == c.talk, "tapping a café prospect selects them")
	t.check(c._wander._wait > 0.0 and not c._wander.walking, "the selected prospect waits for the player")
	t.check(main.hud._interact_button.visible and main.hud._interact_button.text == c.talk.get_prompt(), "action button: '%s'" % c.talk.get_prompt())
	await _shutdown(main)


## B1 review: the old 6 s hold started only on arrival and could run out mid-walk or mid-dialog.
## A tapped customer now waits from the tap, through selection and the conversation, until released.
func test_engaged_customer_waits_until_released() -> void:
	var main := await _boot_from_fixture()
	var cafe = main.current_location
	var player: Player = main.player
	player.wander_when_idle = false
	var c: Customer = cafe.prospect_customers()[0]
	player.tap_at(c.global_position)
	await t.get_tree().physics_frame
	await t.get_tree().physics_frame
	t.check(not c._wander.walking, "the customer stops as soon as they are tapped")
	var spot := c.global_position
	for i in 900:
		await t.get_tree().physics_frame
		if player.current_focus() == c.talk:
			break
	t.check(player.current_focus() == c.talk, "player reaches and selects the customer")
	await _wait(7.0)
	t.check(c.global_position.distance_to(spot) < 2.0 and not c._wander.walking, "still waiting after the old 6 s hold")
	t.check(player.current_focus() == c.talk, "still selected")
	await _click(main.hud._interact_button)
	await _wait(0.3)
	t.check(main.choice_dialog.visible, "action button opens the conversation")
	await _wait(1.0)
	t.check(c.global_position.distance_to(spot) < 2.0, "customer waits during the conversation")
	main.choice_dialog.close()
	await _wait(0.3)
	t.check(c._wander._wait > 100.0, "still engaged after closing the dialog while selected")
	player.tap_at(player.global_position + Vector2(0, 80))
	await _wait(0.2)
	t.check(c._wander._wait <= Customer.RELEASE_PAUSE, "tapping elsewhere releases the customer to wander")
	await _shutdown(main)


# --- Helpers --------------------------------------------------------------------

static func _panel_mentions(panel: Node, text: String) -> bool:
	for l in panel.find_children("*", "Label", true, false):
		if (l as Label).text.contains(text):
			return true
	return false


func _click(c: Control) -> void:
	var pos := c.get_global_rect().get_center()
	var vp := c.get_viewport()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev, true)
		await t.get_tree().process_frame


func _press_action(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await t.get_tree().process_frame


func _boot_from_fixture(overrides := {}) -> Node:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	for k in overrides:
		data.state[k] = overrides[k]
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	main._close_overlays()
	await _wait(0.3)
	return main


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
