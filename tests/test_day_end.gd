extends RefCounted
## B2 day schedule and end of day (temp saves; see test_runner.gd): the 8:30 AM - 8:30 PM day, the
## end-of-day summary (8:30 PM or the bed), NEXT DAY starting the next morning exactly once, and
## saves made around the end of the day. The save format (version 1, same keys) does not change.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Day 3, Coffee Corner, 8:40 AM; lead 15 = 3 oximeters, 6 in stock
const DAY_END := 20 * 60 + 30
const LAYOUTS := [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]

var t  # test runner
var _summaries: Array = []
var _toasts: Array = []


func test_day_schedule_and_slots() -> void:
	t.check_eq(GameState.START_MINUTES, 8 * 60 + 30, "day starts 8:30 AM")
	t.check_eq(GameState.DAY_END_MINUTES, DAY_END, "day ends 8:30 PM")
	var cases := [[510, &"morning", false], [749, &"morning", false], [750, &"afternoon", false],
		[989, &"afternoon", false], [990, &"evening", false], [DAY_END - 1, &"evening", false], [DAY_END, &"evening", true]]
	for c in cases:
		GameState.minutes = c[0]
		var at := GameState.time_label()
		t.check_eq(GameState.time_slot(), c[1], "%s is %s" % [at, c[1]])
		t.check_eq(GameState.is_day_over(), c[2], "%s day over: %s" % [at, c[2]])
	GameState.minutes = DAY_END
	t.check_eq(GameState.time_label(), "08:30 PM", "end-of-day clock label")


func test_clock_stops_at_830_and_ends_the_day_once() -> void:
	_listen()
	GameState.minutes = DAY_END - 60
	GameState.advance_time(59)
	await _frames()
	t.check(_summaries.is_empty() and not GameState.day_closing, "8:29 PM: the day goes on")
	t.check(_toasts.has("The day ends at 08:30 PM."), "heads-up toast after 8 PM (%s)" % [_toasts])
	var day := GameState.day
	GameState.advance_time(25)  # a phone deal past 8:30 PM
	t.check_eq(GameState.minutes, DAY_END, "clock stops at 8:30 PM")
	await _frames()
	t.check_eq(_summaries.size(), 1, "summary opens once")
	t.check(GameState.day_closing, "day is closing")
	t.check_eq(_summaries[0].reason, &"time", "ended by the clock")
	GameState.advance_time(10)
	GameState.end_day(&"time")
	GameState.end_day(&"sleep")
	await _frames()
	t.check_eq(GameState.minutes, DAY_END, "clock still 8:30 PM")
	t.check_eq(_summaries.size(), 1, "no second summary")
	t.check_eq(GameState.day, day, "the day does not advance by itself")
	_unlisten()


func test_next_day_starts_exactly_once() -> void:
	GameState.location_id = &"coffee"
	var day := GameState.day
	var leads := GameState.leads.size()
	var cash := GameState.cash
	var inventory := GameState.inventory.duplicate()
	t.check(not GameState.start_next_day(), "no next day before the day has ended")
	t.check_eq(GameState.day, day, "day unchanged")
	GameState.minutes = DAY_END
	GameState.end_day(&"time")
	t.check(GameState.start_next_day(), "NEXT DAY starts the morning")
	t.check(not GameState.start_next_day(), "a second press does nothing")
	t.check_eq(GameState.day, day + 1, "one day further")
	t.check_eq(GameState.leads.size(), leads + GameState.DAILY_NEW_LEADS, "overnight leads given once")
	t.check_eq(GameState.minutes, GameState.START_MINUTES, "8:30 AM")
	t.check_eq(GameState.time_slot(), &"morning", "morning slot")
	t.check_eq(GameState.location_id, &"home", "wakes up at home")
	t.check(not GameState.day_closing and not GameState.is_day_over(), "new day open")
	t.check_eq(GameState.prospects.size(), GameState.CAFE_PROSPECTS, "fresh café prospects")
	t.check(GameState.prospects.all(func(p): return not p.met), "nobody met yet")
	t.check_eq(GameState.cash, cash, "cash kept")
	t.check_eq(GameState.inventory, inventory, "inventory kept")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	t.check(int(saved.state.day) == day + 1 and int(saved.state.minutes) == GameState.START_MINUTES, "new morning autosaved")


func test_summary_counts_today_only() -> void:
	GameState.day = 2
	GameState.deals.append({"day": 1, "customer": "Old (Clinic)", "product_id": "bp_monitor", "qty": 1, "amount": 999, "in_person": true})
	var lead: Dictionary = GameState.leads[0]
	GameState.add_stock(lead.product_id, int(lead.qty))
	var cash_before := GameState.cash
	t.check(GameState.close_deal(int(lead.id), false), "phone deal")
	var amount := GameState.cash - cash_before
	GameState.meet_prospect(int(GameState.prospects[0].id))
	var s := GameState.day_summary()
	t.check_eq(s.day, 2, "summary for today")
	t.check_eq(s.deals, 1, "today's deal only")
	t.check_eq(s.sales, amount, "today's sales")
	t.check_eq(s.units, int(lead.qty), "units sold")
	t.check_eq(s.met, 1, "one client met")
	t.check_eq(s.cash, GameState.cash, "cash on hand")
	t.check_eq(s.level, GameState.level, "level")
	t.check_eq(s.new_leads, GameState.DAILY_NEW_LEADS, "tomorrow's leads")


## A deal that runs past 8:30 PM is applied in full, exactly once, before the summary opens.
func test_deal_crossing_830_applies_once() -> void:
	_listen()
	var lead: Dictionary = GameState.leads[0]
	GameState.add_stock(lead.product_id, int(lead.qty))
	var leads := GameState.leads.size()
	var deals := GameState.deals.size()
	var cash := GameState.cash
	var expected := GameState.deal_price(lead, false)
	GameState.minutes = DAY_END - 5
	t.check(GameState.close_deal(int(lead.id), false), "phone deal at 8:25 PM")
	t.check(GameState.find_lead(int(lead.id)).is_empty() and GameState.leads.size() == leads - 1, "lead used once")
	t.check_eq(GameState.deals.size(), deals + 1, "one deal recorded")
	t.check_eq(GameState.cash - cash, expected, "paid once, existing price (no economy change)")
	await _frames()
	t.check_eq(_summaries.size(), 1, "one summary")
	t.check_eq(_summaries[0].deals, 1, "deal in today's summary")
	t.check_eq(_summaries[0].sales, expected, "gross sales = what the customer paid")
	t.check(not GameState.close_deal(int(lead.id), false), "the same lead cannot be closed again")
	t.check_eq(GameState.day_summary().deals, 1, "still one deal")
	_unlisten()


func test_bed_ends_the_day_early_with_summary() -> void:
	_listen()
	GameState.minutes = 14 * 60
	var xp := GameState.xp
	GameState.end_day(&"sleep")
	t.check_eq(_summaries.size(), 1, "bed opens the summary")
	t.check_eq(_summaries[0].reason, &"sleep", "ended at the bed")
	t.check_eq(GameState.minutes, 14 * 60, "clock untouched until morning")
	t.check(GameState.completed_tasks.has("sleep"), "'End the day' task done")
	GameState.end_day(&"sleep")
	t.check_eq(_summaries.size(), 1, "second sleep ignored")
	t.check(GameState.start_next_day(), "next morning")
	t.check_eq(GameState.xp, xp + 10, "task XP once (no repeated reward)")
	GameState.minutes = 14 * 60
	GameState.end_day(&"sleep")
	GameState.start_next_day()
	t.check_eq(GameState.xp, xp + 10, "no task XP on later nights")
	_unlisten()


func test_save_and_load_around_the_end_of_day() -> void:
	_listen()
	GameState.minutes = DAY_END - 10
	GameState.advance_time(20)
	await _frames()
	var day := GameState.day
	var keys := GameState.to_dict().keys()
	t.check(SaveSystem.save_game(), "save at 8:30 PM (e.g. quick save on the summary)")
	t.check_eq(GameState.to_dict().keys(), keys, "no new save fields")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	t.check_eq(int(saved.version), 1, "save version 1")
	GameState.new_game()
	_summaries.clear()
	t.check(SaveSystem.load_game(), "load the 8:30 PM save")
	await _frames()
	t.check_eq(GameState.day, day, "same day")
	t.check_eq(GameState.minutes, DAY_END, "still 8:30 PM")
	t.check_eq(_summaries.size(), 1, "summary reopens after loading")
	t.check(GameState.day_closing, "day closing after load")
	var leads := GameState.leads.size()
	t.check(GameState.start_next_day(), "NEXT DAY after loading")
	GameState.new_game()
	_summaries.clear()
	t.check(SaveSystem.load_game(), "load the new morning")
	await _frames()
	t.check_eq(GameState.day, day + 1, "next day kept")
	t.check_eq(GameState.minutes, GameState.START_MINUTES, "morning kept")
	t.check_eq(GameState.leads.size(), leads + GameState.DAILY_NEW_LEADS, "overnight leads saved once")
	t.check(_summaries.is_empty() and not GameState.day_closing, "no summary in the morning")
	_unlisten()


## Quitting on the summary before NEXT DAY loses nothing and gives nothing twice.
func test_quit_on_the_summary_does_not_advance() -> void:
	GameState.minutes = 15 * 60
	t.check(SaveSystem.save_game(), "afternoon save")
	var leads := GameState.leads.size()
	GameState.end_day(&"sleep")
	GameState.new_game()
	t.check(SaveSystem.load_game(), "reload")
	await _frames()
	t.check(not GameState.day_closing, "back in the afternoon, day still open")
	t.check_eq(GameState.minutes, 15 * 60, "same time")
	t.check_eq(GameState.leads.size(), leads, "no overnight leads yet")


## Saves from before B2 could run past 8:30 PM (until 10 PM+): they load unchanged and end the day.
func test_old_late_save_loads_and_ends_the_day() -> void:
	_listen()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	data.state.minutes = 21 * 60 + 40
	_write_save(data)
	t.check(SaveSystem.load_game(), "late v1 save loads")
	t.check(SaveSystem.last_warnings.is_empty(), "no repairs needed")
	await _frames()
	t.check_eq(GameState.minutes, 21 * 60 + 40, "time kept as saved")
	t.check_eq(GameState.cash, int(data.state.cash), "cash kept")
	t.check_eq(GameState.xp, int(data.state.xp), "xp kept")
	t.check_eq(_summaries.size(), 1, "the day is over: summary")
	t.check(GameState.start_next_day(), "next day")
	t.check_eq(GameState.day, int(data.state.day) + 1, "day 4")
	t.check_eq(GameState.cash, int(data.state.cash), "cash still kept")
	t.check_eq(GameState.inventory.size(), data.state.inventory.size(), "inventory kept")
	_unlisten()


func test_bed_flow_in_the_game() -> void:
	var main := await _boot({"location_id": "home"})
	var bed: Interactable = main.current_location.get_node("Bed")
	var day := GameState.day
	bed.interact(main.player)
	await _frames()
	t.check(main.choice_dialog.visible, "bed asks 'Go to sleep?'")
	(main.choice_dialog.buttons.get_child(0) as Button).pressed.emit()  # Sleep
	await _wait(0.3)
	var summary: DaySummary = main.day_summary
	t.check(summary.visible, "summary shown")
	t.check(not main.choice_dialog.visible, "dialog closed")
	t.check(not main.player.input_enabled, "player cannot walk behind the summary")
	t.check_eq(summary.title_label.text, "Day %d complete" % day, "summary title")
	t.check_eq(GameState.day, day, "day not advanced yet")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	main._unhandled_input(esc)
	var key_p := InputEventAction.new()
	key_p.action = &"toggle_phone"
	key_p.pressed = true
	main._unhandled_input(key_p)
	await _wait(0.3)
	t.check(summary.visible, "Escape does not skip the summary")
	t.check_eq(main.active, &"", "P does not open the phone over the summary")
	summary.next_button.pressed.emit()
	summary.next_button.pressed.emit()
	await _wait(1.0)
	t.check_eq(GameState.day, day + 1, "NEXT DAY (pressed twice) advances one day")
	t.check(not summary.visible, "summary closed")
	t.check(main.player.input_enabled, "player can move again")
	t.check_eq(main.current_location.location_data.id, &"home", "home in the morning")
	t.check_eq(main.hud.clock_block.value, "08:30 AM", "HUD clock shows the morning")
	await _shutdown(main)


func test_830_pm_at_the_cafe_ends_the_day() -> void:
	var main := await _boot()
	main.select(&"phone")
	GameState.minutes = DAY_END - 5
	var day := GameState.day
	t.check(GameState.close_deal(15, false), "phone deal at 8:25 PM")
	await _wait(0.3)
	var summary: DaySummary = main.day_summary
	t.check(summary.visible, "summary at 8:30 PM")
	t.check_eq(main.active, &"", "phone closed under the summary")
	t.check(summary.reason_label.text.contains("08:30 PM"), "reason mentions 8:30 PM (%s)" % summary.reason_label.text)
	t.check(_row_values(summary).has("1"), "deal counted in the summary")
	t.check(_row_labels(summary).has("Gross sales"), "sales row labelled as gross sales (%s)" % [_row_labels(summary)])
	summary.next_button.pressed.emit()
	await _wait(1.0)
	t.check_eq(GameState.day, day + 1, "next day")
	t.check_eq(GameState.location_id, &"home", "woke up at home")
	t.check_eq(main.current_location.location_data.id, &"home", "home scene loaded")
	await _shutdown(main)


func test_summary_fits_portrait_landscape_desktop() -> void:
	var main := await _boot()
	var win: Window = t.get_window()
	var orig_size := win.size
	var orig_min := win.min_size
	var summary: DaySummary = main.day_summary
	GameState.minutes = DAY_END
	GameState.end_day(&"time")
	for size in LAYOUTS:
		win.min_size = Vector2i.ZERO
		win.size = size
		Responsive.update_responsive_layout()
		main.update_responsive_layout()
		await _wait(0.5)
		var at := "%dx%d" % [size.x, size.y]
		var view := main.get_viewport().get_visible_rect()
		t.check(summary.visible, at + " summary visible")
		t.check(view.encloses(summary.panel.get_global_rect()), "%s card fits (%s in %s)" % [at, summary.panel.get_global_rect(), view.size])
		var b := summary.next_button.get_global_rect()
		t.check(view.encloses(b) and b.size.y >= 40.0, at + " NEXT DAY on screen and tappable size")
		var vp := main.get_viewport()
		var move := InputEventMouseMotion.new()
		move.position = b.get_center()
		move.global_position = b.get_center()
		vp.push_input(move, true)
		t.check(vp.gui_get_hovered_control() == summary.next_button, at + " NEXT DAY not covered")
	win.min_size = Vector2i.ZERO
	win.size = orig_size
	win.min_size = orig_min
	Responsive.update_responsive_layout()
	GameState.start_next_day()
	await _shutdown(main)


# --- Helpers --------------------------------------------------------------------

func _listen() -> void:
	_summaries.clear()
	_toasts.clear()
	GameState.day_finished.connect(_on_summary)
	UIEvents.toast_requested.connect(_on_toast)


func _unlisten() -> void:
	GameState.day_finished.disconnect(_on_summary)
	UIEvents.toast_requested.disconnect(_on_toast)


func _on_summary(s: Dictionary) -> void:
	_summaries.append(s)


func _on_toast(text: String) -> void:
	_toasts.append(text)


static func _row_values(summary: DaySummary) -> Array:
	var out := []
	for row in summary.rows.get_children():
		out.append((row.get_child(2) as Label).text)
	return out


static func _row_labels(summary: DaySummary) -> Array:
	var out := []
	for row in summary.rows.get_children():
		out.append((row.get_child(1) as Label).text)
	return out


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _boot(overrides := {}) -> Node:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	for k in overrides:
		data.state[k] = overrides[k]
	_write_save(data)
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	return main


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _frames() -> void:
	await t.get_tree().process_frame
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
