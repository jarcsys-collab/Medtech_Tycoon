extends RefCounted
## V1 visual shell (Sales Simulator handoff look) on the real main scene (temp saves; see test_runner.gd):
## the top bar without level / XP, the phone app grid (working apps, SOON tiles, Profile & Progress),
## the pixel-frame dialogue, the three layouts, and the JARC Web loading shell's integration.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Day 3, Coffee Corner, 8:40 AM, 125 XP (level 2)
const SHELL := "res://web/loading_shell.html"
const LAYOUTS := [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]
const APP_ORDER: Array[StringName] = [&"leads", &"messages", &"customers", &"deals", &"inventory", &"finance",
	&"schedule", &"quotes", &"collections", &"profile", &"one_jarc", &"tickets", &"itinerary"]
const SOON: Array[StringName] = [&"one_jarc", &"tickets", &"itinerary"]
const PAGES: Array[StringName] = [&"leads", &"messages", &"customers", &"schedule", &"quotes", &"collections", &"profile"]
const SCREENS: Array[StringName] = [&"deals", &"inventory", &"finance"]

var t  # test runner
var _ran := []


func test_top_bar_shows_date_and_time_only() -> void:
	var main := await _boot()
	var hud: Hud = main.hud
	for gone in ["LevelLabel", "XPBar", "XPLabel", "Level"]:
		t.check(hud.top_bar.find_child(gone, true, false) == null, "top bar has no %s" % gone)
	t.check_eq(hud.day_block.caption, "DAY 3", "DAY N")
	t.check_eq(hud.day_block.value, GameState.date_label(), "date")
	t.check_eq(hud.clock_block.value, "08:40 AM", "time")
	t.check_eq(hud.clock_block.caption, "MORNING", "time-of-day slot kept")
	t.check_eq(hud.clock_block.get_node("Text/Value").get_theme_color(&"font_color"), Hud.TIME_COLOR, "time in gold (ZIP)")
	for cell in Hud.BLANK_CELLS:
		t.check(hud.stat_row.get_node(NodePath(cell)).visible, "desktop: blank cell %s shown" % cell)
	t.check(absf(hud.top_bar.get_global_rect().position.y) < 0.5, "top bar flush with the top (ZIP)")
	var lv := GameState.level
	var xp := GameState.xp
	GameState.add_xp(5)
	t.check_eq(GameState.xp, xp + 5, "XP still counts (progression unchanged)")
	t.check_eq(GameState.level, GameData.level_for_xp(GameState.xp), "level still follows XP")
	t.check(GameState.level >= lv, "level kept")
	await _shutdown(main)


func test_phone_app_grid() -> void:
	var main := await _boot()
	var phone: Phone = main.phone
	_open_phone(main)
	await _wait(0.4)
	var ids: Array[StringName] = []
	for tile: PhoneApp in phone.home.get_children():
		ids.append(tile.id)
	t.check_eq(ids, APP_ORDER, "app order")
	t.check_eq(phone.home.columns, 3, "3-column grid (ZIP)")
	for tile: PhoneApp in phone.home.get_children():
		var soon := tile.id in SOON
		t.check_eq(tile.disabled, soon, "%s %s" % [tile.id, "is a disabled SOON tile" if soon else "is tappable"])
		var labels := tile.find_children("*", "Label", true, false).map(func(l: Label): return l.text if l.visible else "")
		t.check(labels.has("SOON") == soon, "%s SOON caption only when unavailable" % tile.id)
		var icon: TextureRect = tile.find_children("*", "TextureRect", true, false)[0]
		t.check(icon.texture != null and icon.texture.resource_path.begins_with("res://assets/ui/"), "%s uses a ZIP icon" % tile.id)
		t.check(tile.get_global_rect().size.y >= 44.0, "%s touch target >= 44 px" % tile.id)
	t.check(phone.app(&"one_jarc").find_children("*", "TextureRect", true, false)[0].texture.resource_path.ends_with("pTicket.png"), "One Jarc uses pTicket")
	t.check_eq(phone.app(&"leads").badge, GameState.leads.size(), "Leads badge = open leads")
	t.check(phone.greeting.text == "Good morning", "ZIP greeting (%s)" % phone.greeting.text)
	await _shutdown(main)


func test_phone_apps_open_their_screens() -> void:
	var main := await _boot()
	var phone: Phone = main.phone
	for id in PAGES:
		_open_phone(main)
		await _wait(0.3)
		phone.app(id).pressed.emit()
		await t.get_tree().process_frame
		t.check(phone.page.visible and phone.page_list.get_child_count() > 0, "%s opens its page" % id)
		phone.show_home()
	for id in SCREENS:
		_open_phone(main)
		await _wait(0.3)
		phone.app(id).pressed.emit()
		await _wait(0.3)
		t.check_eq(main.active, id, "%s app opens its screen" % id)
		t.check(main.info_panel.visible and not phone.visible, "%s: panel shown, phone closed" % id)
		main._close_overlays()
	# SOON apps open nothing, even through the page path.
	_open_phone(main)
	await _wait(0.3)
	for id in SOON:
		phone.open_page(id)
		t.check(not phone.page.visible and phone.home.visible, "%s opens nothing (no fake app)" % id)
		t.check_eq(main.active, &"phone", "%s opens no screen" % id)
	await _shutdown(main)


func test_profile_shows_level_and_xp() -> void:
	var main := await _boot()
	var phone: Phone = main.phone
	_open_phone(main)
	await _wait(0.3)
	var xp := GameState.xp
	phone.open_page(&"profile")
	await t.get_tree().process_frame
	var prog := GameState.xp_progress()
	t.check_eq(phone.page_title.text, "Profile & Progress", "page title")
	t.check_eq((phone.page_list.find_child("Level", true, false) as Label).text, "LEVEL %d" % GameState.level, "level shown")
	t.check_eq((phone.page_list.find_child("XP", true, false) as Label).text, "%d / %d XP" % [prog.x, prog.y], "XP shown")
	var bar: ProgressBar = phone.page_list.find_child("XPBar", true, false)
	t.check(is_equal_approx(bar.value, float(prog.x) / prog.y), "XP bar fill")
	t.check_eq(GameState.xp, xp, "viewing the profile changes nothing")
	GameState.add_xp(10)
	await _wait(0.1)
	t.check_eq((phone.page_list.find_child("XP", true, false) as Label).text, "%d / %d XP" % [GameState.xp_progress().x, GameState.xp_progress().y], "profile follows new XP")
	await _shutdown(main)


func test_pixel_frame_dialogue() -> void:
	var main := await _boot()
	var dlg: ChoiceDialog = main.choice_dialog
	_ran.clear()
	UIEvents.ask("Go to sleep?", "End the day.", [UIEvents.option("Sleep", func(): _ran.append("sleep"), false, true),
		UIEvents.option("Locked", Callable(), true), UIEvents.option("Not now")])
	await _wait(0.3)
	t.check(dlg.visible, "dialog shown")
	t.check(dlg.panel.get_theme_stylebox(&"panel").resource_path.ends_with("tutorial_frame_style.tres"), "pixel frame from dialog-box.png")
	var portrait: TextureRect = dlg.panel.find_child("Portrait", true, false)
	t.check(portrait.texture.resource_path.ends_with("portrait.png") and portrait.is_visible_in_tree(), "player portrait in the slot")
	t.check_eq(dlg.buttons.get_child_count(), 3, "three replies")
	for i in 3:
		var b: Button = dlg.buttons.get_child(i)
		t.check_eq((b.find_child("Number", true, false) as Label).text, str(i + 1), "reply %d numbered" % (i + 1))
		t.check(b.size.y >= 44.0, "reply %d touch target" % (i + 1))
	t.check_eq((dlg.buttons.get_child(0).find_child("Text", true, false) as Label).text, "Sleep", "reply text")
	t.check((dlg.buttons.get_child(1) as Button).disabled, "disabled reply stays disabled")
	t.check(dlg.stack.get_global_rect().end.y <= main.get_viewport().get_visible_rect().size.y, "dialogue sits at the bottom, on screen")
	(dlg.buttons.get_child(0) as Button).pressed.emit()
	await _wait(0.3)
	t.check_eq(_ran, ["sleep"], "reply runs its action (logic unchanged)")
	t.check(not dlg.visible, "dialog closes")
	await _shutdown(main)


func test_shell_fits_portrait_landscape_desktop() -> void:
	var main := await _boot()
	var win: Window = t.get_window()
	var orig_size := win.size
	var orig_min := win.min_size
	for size in LAYOUTS:
		win.min_size = Vector2i.ZERO
		win.size = size
		Responsive.update_responsive_layout()
		main.update_responsive_layout()
		await _wait(0.5)
		var at := "%dx%d" % [size.x, size.y]
		var view := main.get_viewport().get_visible_rect()
		var hud: Hud = main.hud
		t.check(view.encloses(hud.top_bar.get_global_rect()), at + " top bar on screen")
		t.check(hud.clock_block.get_node("Text/Caption").is_visible_in_tree(), at + " slot caption visible")
		t.check_eq(hud.stat_row.get_node(^"Cell2").visible, not Responsive.is_portrait(), at + " blank cells only on wide layouts")
		_open_phone(main)
		await _wait(0.4)
		var frame: Control = main.phone.get_node("Frame")
		t.check(view.encloses(frame.get_global_rect()), at + " phone on screen")
		for tile: PhoneApp in main.phone.home.get_children():
			var r := tile.get_global_rect()
			t.check(r.position.x >= frame.get_global_rect().position.x and r.end.x <= frame.get_global_rect().end.x, "%s %s tile inside the phone" % [at, tile.id])
		var first: PhoneApp = main.phone.app(&"leads")
		var vp := main.get_viewport()
		var move := InputEventMouseMotion.new()
		move.position = first.get_global_rect().get_center()
		move.global_position = move.position
		vp.push_input(move, true)
		var hit := vp.gui_get_hovered_control()
		t.check(hit == first or first.is_ancestor_of(hit), "%s Leads tile tappable (not covered; hit %s at %s, tile %s)" % [at, hit.get_path() if hit else "none", move.position, first.get_global_rect()])
		main._close_overlays()
		UIEvents.ask("Title", "Body text", [UIEvents.option("One"), UIEvents.option("Two")])
		await _wait(0.4)
		t.check(view.encloses(main.choice_dialog.stack.get_global_rect()), at + " dialogue on screen (%s)" % main.choice_dialog.stack.get_global_rect())
		main.choice_dialog.close()
		await _wait(0.2)
	win.min_size = Vector2i.ZERO
	win.size = orig_size
	win.min_size = orig_min
	Responsive.update_responsive_layout()
	await _shutdown(main)


## V1 is visual only: a v1 save loads, the save format is unchanged, the real save is never touched
## (test_runner fingerprints it).
func test_v1_save_round_trip() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	var keys: Array = data.state.keys()
	var main := await _boot()
	t.check_eq(GameState.cash, int(data.state.cash), "v1 save loaded")
	t.check(SaveSystem.save_game(), "saved")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	t.check_eq(int(saved.version), 1, "save version 1")
	var out: Array = saved.state.keys()
	out.sort()
	keys.sort()
	t.check_eq(out, keys, "same save keys")
	await _shutdown(main)


## The Web loading shell is HTML outside the game: it keeps Godot's startup contract and touches no
## game or save storage.
func test_web_loading_shell_integration() -> void:
	var cfg := ConfigFile.new()
	t.check_eq(cfg.load("res://export_presets.cfg"), OK, "export presets readable")
	t.check_eq(cfg.get_value("preset.0.options", "html/custom_html_shell"), SHELL, "Web preset uses the JARC shell")
	t.check(str(cfg.get_value("preset.0", "exclude_filter")).contains("web/*"), "shell folder kept out of the PCK")
	var html := FileAccess.get_file_as_string(SHELL)
	for token in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED", "$GODOT_HEAD_INCLUDE", "$GODOT_PROJECT_NAME"]:
		t.check(html.contains(token), "keeps Godot placeholder " + token)
	for part in ["Loading MedTech Tycoon...", "onProgress", "status-retry", "window.location.reload()", "id=\"status\"",
			"data:image/webp;base64,", "Engine.getMissingFeatures"]:
		t.check(html.contains(part), "shell has " + part)
	for banned in ["indexedDB", "localStorage", "sessionStorage", "http://", "https://"]:
		t.check(not html.contains(banned), "shell does not use " + banned)
	t.check(html.length() < 400 * 1024, "shell under 400 KB (%d bytes)" % html.length())


# --- Helpers --------------------------------------------------------------------

func _boot() -> Node:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	data.state.tutorial_done = true
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	return main


## The game opens the phone on start and PHONE toggles it, so close everything first.
func _open_phone(main: Node) -> void:
	main._close_overlays()
	main.select(&"phone")


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
