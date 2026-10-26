extends RefCounted
## Time of day on the real main scene (temp saves; see test_runner.gd): café ambience by slot
## (background patrons are visual only and never sell), the clock's time-of-day caption and notice,
## and save compatibility. Counts are fixed per slot, so nothing here is random.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Coffee Corner, 8:40 AM, prospects 16 (new) and 17 (met)
const NOON := 12 * 60 + 30
const EVENING := 16 * 60 + 30
## Save keys before the time-of-day work: the format must not change.
const SAVE_KEYS := ["day", "minutes", "cash", "reputation", "xp", "location_id", "inventory", "leads",
	"prospects", "customers", "deals", "revenue_total", "expenses_total", "completed_tasks",
	"tutorial_step", "tutorial_done", "tutorial_version", "next_id"]

var t  # test runner
var _slots: Array = []


func test_slot_boundaries_and_crowd_table() -> void:
	var cases := [[510, &"morning", 1, 0.6], [749, &"morning", 1, 0.6], [750, &"afternoon", 2, 1.0],
		[989, &"afternoon", 2, 1.0], [990, &"evening", 0, 1.8], [1300, &"evening", 0, 1.8]]
	for c in cases:
		GameState.minutes = c[0]
		var at := GameState.time_label()
		t.check_eq(GameState.time_slot(), c[1], "%s is %s" % [at, c[1]])
		t.check_eq(GameState.crowd().patrons, c[2], "%s: %d background patrons" % [at, c[2]])
		t.check_eq(GameState.crowd().rest, c[3], "%s: customer pace x%s" % [at, c[3]])
	t.check(GameState.CROWD[&"afternoon"].patrons > GameState.CROWD[&"morning"].patrons
		and GameState.CROWD[&"morning"].patrons > GameState.CROWD[&"evening"].patrons, "afternoon busiest, evening quietest")


func test_morning_cafe_crowd() -> void:
	var main := await _boot_from_fixture()
	var cafe = main.current_location
	t.check_eq(GameState.time_slot(), &"morning", "8:40 AM is morning")
	t.check_eq(cafe.prospect_customers().size(), 2, "both saved prospects in the café")
	var patrons: Array = cafe.patrons()
	t.check_eq(patrons.size(), 1, "one morning commuter")
	for p: Customer in patrons:
		t.check(not p.talk.enabled and not p.bubble.visible and p.lead_id == -1, "commuter is a background guest (no bubble, no talk)")
	for c: Customer in cafe.prospect_customers():
		t.check(c.talk.enabled and c.bubble.visible, "prospect %d still talkable" % c.lead_id)
		t.check_eq(c._wander.rest_scale, 0.6, "brisk morning pace")
	await _shutdown(main)


func test_crowd_follows_the_clock_without_new_sales() -> void:
	var main := await _boot_from_fixture()
	var cafe = main.current_location
	var prospects_before := GameState.prospects.duplicate(true)
	var leads_before := GameState.leads.size()
	GameState.advance_time(NOON - GameState.minutes)
	await _wait(0.3)
	t.check_eq(GameState.time_slot(), &"afternoon", "12:30 PM is afternoon")
	t.check_eq(GameState.prospects, prospects_before, "the clock adds no prospects (no walk-ins)")
	t.check_eq(cafe.prospect_customers().size(), 2, "same two prospects in the afternoon")
	t.check_eq(cafe.patrons().size(), 2, "two patrons: the busiest crowd")
	for c: Customer in cafe.prospect_customers():
		t.check_eq(c._wander.rest_scale, 1.0, "normal afternoon pace")
	GameState.advance_time(EVENING - GameState.minutes)
	await _wait(0.3)
	t.check_eq(GameState.time_slot(), &"evening", "4:30 PM is evening")
	t.check_eq(cafe.patrons().size(), 0, "patrons head home in the evening")
	t.check_eq(cafe.prospect_customers().size(), 2, "every prospect stays in the evening")
	for c: Customer in cafe.prospect_customers():
		t.check_eq(c._wander.rest_scale, 1.8, "relaxed evening pace")
		t.check(c.talk.enabled, "prospect %d still talkable in the evening" % c.lead_id)
	t.check_eq(GameState.prospects, prospects_before, "still no new prospects in the evening")
	t.check_eq(GameState.leads.size(), leads_before, "the clock adds no leads")
	await _shutdown(main)


func test_patrons_never_sell_and_introductions_unchanged() -> void:
	var main := await _boot_from_fixture({"minutes": 13 * 60})
	var cafe = main.current_location
	t.check_eq(cafe.patrons().size(), 2, "afternoon patrons present")
	for p: Customer in cafe.patrons():
		t.check(not p.talk.enabled, "patron cannot be talked to")
		t.check(GameState.find_prospect(p.lead_id).is_empty() and GameState.find_lead(p.lead_id).is_empty(), "patron is not a prospect or lead")
	var prospect: Dictionary = GameState.prospects.filter(func(p): return not p.met)[0]
	var c: Customer
	for x: Customer in cafe.prospect_customers():
		if x.lead_id == int(prospect.id):
			c = x
	c.talk.interact(main.player)
	await t.get_tree().process_frame
	t.check(main.choice_dialog.visible and main.choice_dialog.body_label.text.contains("takes 10 min"), "introduction still takes 10 min")
	main.choice_dialog.close()
	GameState.completed_tasks["meet_prospect"] = true  # the task's own one-off XP is not part of this
	GameState.minutes = 9 * 60
	var xp := GameState.xp
	GameState.meet_prospect(int(prospect.id))
	t.check_eq(GameState.minutes, 9 * 60 + GameState.MEET_MINUTES, "morning introduction: still 10 min")
	t.check_eq(GameState.xp - xp, 5, "introduction XP unchanged (+5)")
	await _shutdown(main)


func test_slot_signal_and_new_day() -> void:
	_slots.clear()
	GameState.time_slot_changed.connect(_record_slot)
	GameState.minutes = NOON - 10
	GameState.advance_time(5)
	t.check(_slots.is_empty(), "no signal inside a slot")
	GameState.advance_time(5)
	t.check_eq(_slots, [[&"afternoon", true]], "afternoon announced at 12:30 PM")
	GameState.advance_time(EVENING - GameState.minutes)
	t.check_eq(_slots[-1], [&"evening", true], "evening announced at 4:30 PM")
	GameState.sleep()
	t.check_eq(_slots[-1], [&"morning", false], "new day starts in the morning (no notice)")
	t.check_eq(GameState.prospects.size(), GameState.CAFE_PROSPECTS, "new day: the usual prospects")
	GameState.time_slot_changed.disconnect(_record_slot)


func test_time_indicator_and_notice() -> void:
	var main := await _boot_from_fixture()
	var hud: Hud = main.hud
	var caption: Label = hud.clock_block.get_node("Text/Caption")
	t.check_eq(caption.text, "MORNING", "clock caption shows the slot")
	t.check_eq(caption.get_theme_color(&"font_color"), Hud.SLOT_COLORS[&"morning"], "morning colour")
	GameState.minutes = NOON - 10
	GameState.travel_to(GameData.get_location(&"warehouse"))  # 35 min trip, unlocked at level 2
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check_eq(caption.text, "AFTERNOON", "caption follows the clock")
	t.check(hud.toast_panel.visible and hud.toast_label.text.contains("Arrived at") and hud.toast_label.text.contains("Afternoon rush"),
		"notice joins the travel toast instead of replacing it (%s)" % hud.toast_label.text.c_escape())
	await _wait(3.2)
	GameState.advance_time(EVENING - GameState.minutes)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check_eq(caption.text, "EVENING", "evening caption")
	t.check(hud.toast_label.text == Hud.SLOT_NOTICES[&"evening"], "evening notice on its own")
	# Narrowest phone: caption shown, notice and top bar inside the screen.
	var win: Window = t.get_window()
	var size := win.size
	var min_size := win.min_size
	win.min_size = Vector2i.ZERO
	win.size = Vector2i(360, 640)
	Responsive.update_responsive_layout()
	main.update_responsive_layout()
	await _wait(0.5)
	hud.show_toast("Arrived at Supplier Depot  (+30 min)")
	hud._show_slot_notice(Hud.SLOT_NOTICES[&"afternoon"])
	await _wait(0.4)
	var view := main.get_viewport().get_visible_rect()
	t.check(caption.is_visible_in_tree(), "portrait: slot caption visible")
	t.check(view.encloses(hud.top_bar.get_global_rect()), "portrait: top bar fits (%s)" % hud.top_bar.get_global_rect())
	t.check(view.encloses(hud.toast_panel.get_global_rect()), "portrait: two-line toast fits (%s)" % hud.toast_panel.get_global_rect())
	win.size = size
	win.min_size = min_size
	Responsive.update_responsive_layout()
	await _shutdown(main)


func test_save_format_unchanged() -> void:
	GameState.minutes = NOON - 5
	var prospects := GameState.prospects.size()
	GameState.advance_time(10)
	var d := GameState.to_dict()
	var keys := d.keys()
	keys.sort()
	var expected := SAVE_KEYS.duplicate()
	expected.sort()
	t.check_eq(keys, expected, "save keys unchanged")
	t.check_eq(SaveSystem.SAVE_VERSION, 1, "save version unchanged")
	t.check_eq(GameState.prospects.size(), prospects, "crossing noon adds nothing to the save")
	t.check(SaveSystem.save_game(), "save in the afternoon")
	GameState.new_game()
	t.check(SaveSystem.load_game() and GameState.time_slot() == &"afternoon", "load it back in the afternoon")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	t.check(SaveSystem.load_game() and GameState.cash == int(data.state.cash), "existing v1 save still loads")


# --- Helpers --------------------------------------------------------------------

func _record_slot(slot: StringName, announce: bool) -> void:
	_slots.append([slot, announce])


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
	return main


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
