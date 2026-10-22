extends RefCounted
## G1b environments and UI on the real main scene (temp saves; see test_runner.gd): time-of-day
## visuals, apartment/café collision, travel map pins, phone banner, tutorial frame, bed glow.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # Coffee Corner, 8:40 AM, level 2
const DAY_CAFE := "res://assets/environment/cafe-bg.png"
const EVENING_CAFE := "res://assets/environment/cafe-bg-evening.png"
const DAY_MAP := "res://assets/environment/city-map.png"
const EVENING_MAP := "res://assets/environment/city-map-evening.png"

var t  # test runner


func test_time_slot_boundaries() -> void:
	var cases := [[510, &"morning"], [749, &"morning"], [750, &"afternoon"], [989, &"afternoon"],
		[990, &"evening"], [1230, &"evening"], [1500, &"evening"]]
	for c in cases:
		GameState.minutes = c[0]
		t.check_eq(GameState.time_slot(), c[1], "%s at %s" % [c[1], GameState.time_label()])
	GameState.minutes = 989
	t.check(not GameState.is_evening(), "4:29 PM is not evening")
	GameState.minutes = 990
	t.check(GameState.is_evening(), "4:30 PM is evening")
	t.check(not GameState.to_dict().has("time_slot"), "save format unchanged")


func test_cafe_switches_to_evening_with_crossfade() -> void:
	var main := await _boot_from_fixture()
	var cafe: LocationBase = main.current_location
	var bg: Sprite2D = cafe.get_node("Background")
	var backdrop: Sprite2D = cafe.get_node("Backdrop")
	t.check_eq(bg.texture.resource_path, DAY_CAFE, "day café in the morning")
	var walls_before := _polygons(cafe)
	GameState.advance_time(16 * 60 + 29 - GameState.minutes)
	await t.get_tree().process_frame
	t.check_eq(bg.texture.resource_path, DAY_CAFE, "still day at 4:29 PM")
	GameState.advance_time(1)
	await t.get_tree().process_frame
	t.check_eq(bg.texture.resource_path, EVENING_CAFE, "evening café at 4:30 PM")
	t.check_eq(backdrop.texture.resource_path, EVENING_CAFE, "blurred backdrop follows")
	t.check(cafe.has_node("BackgroundFadeOut"), "old art cross-fades out on top")
	await _wait(0.9)
	t.check(not cafe.has_node("BackgroundFadeOut"), "cross-fade copy removed afterwards")
	t.check_eq(_polygons(cafe), walls_before, "café collision shapes unchanged by the evening art")
	t.check(main.player.is_inside_tree() and _customers(main).size() == 2, "player and customers still in the café")
	await _shutdown(main)


func test_cafe_loads_directly_in_the_evening() -> void:
	var main := await _boot_from_fixture({"minutes": 18 * 60})
	var cafe: LocationBase = main.current_location
	t.check_eq(cafe.get_node("Background").texture.resource_path, EVENING_CAFE, "evening art on arrival after 4:30 PM")
	t.check(not cafe.has_node("BackgroundFadeOut"), "no cross-fade when the scene opens")
	await _shutdown(main)


func test_apartment_touchup_keeps_collision_and_bed() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var home: LocationBase = main.current_location
	t.check_eq(String(home.location_data.id), "home", "apartment loaded")
	t.check_eq(home.get_node("Background").texture.get_size(), Vector2(941, 1672), "background still 941x1672")
	var walk: CollisionPolygon2D = home.get_node("Walls/WalkBounds")
	t.check(walk.polygon.size() >= 4, "walk bounds present")
	var overlay: Sprite2D = home.get_node("BedOverlay")
	var mat := overlay.material as ShaderMaterial
	t.check(mat != null and mat.shader.resource_path.ends_with("bed_glow.gdshader"), "bed overlay uses the glow shader (not replaced by the edge fade)")
	t.check(overlay.texture.get_size() == home.get_node("Background").texture.get_size(), "bed overlay still matches the room art size")
	await _shutdown(main)


func test_bed_glow_only_in_reach() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var home: LocationBase = main.current_location
	var player: Player = main.player
	var mat := home.get_node("BedOverlay").material as ShaderMaterial
	player.wander_when_idle = false
	await _wait(0.3)
	t.check_eq(player.current_focus(), null, "nothing in reach at the spawn point")
	t.check_eq(_glow(mat), 0.0, "no glow out of reach")
	var spawn := player.global_position
	player.global_position = Vector2(330, 1150)
	await _wait(0.4)
	t.check(player.current_focus() == home.get_node("Bed"), "bed in reach")
	t.check(_glow(mat) > 0.99, "gold glow on while in reach")
	t.check(not player.marker.visible, "player marker steps aside for the bed prompt")
	player.global_position = spawn
	await _wait(0.4)
	t.check_eq(_glow(mat), 0.0, "glow off again out of reach")
	await _shutdown(main)


func test_bed_interaction_unchanged() -> void:
	var main := await _boot_from_fixture({"location_id": "home"})
	var bed: Interactable = main.current_location.get_node("Bed")
	t.check(bed.get_script().resource_path.ends_with("bed.gd"), "found the bed")
	var day := GameState.day
	bed.interact(main.player)
	await t.get_tree().process_frame
	t.check(main.choice_dialog.visible, "bed still asks 'Go to sleep?'")
	GameState.sleep()
	await _wait(0.6)
	t.check_eq(GameState.day, day + 1, "sleeping still ends the day")
	await _shutdown(main)


func test_travel_map_evening_keeps_six_pins() -> void:
	var main := await _boot_from_fixture()
	main.select(&"travel")
	await _wait(0.3)
	var map: TravelMap = main.travel_map
	t.check_eq(map.map_image.texture.resource_path, DAY_MAP, "day map in the morning")
	var day_pins := _pin_positions(map)
	t.check_eq(day_pins.size(), 6, "six pins")
	GameState.advance_time(16 * 60 + 30 - GameState.minutes)
	await _wait(0.2)
	t.check_eq(map.map_image.texture.resource_path, EVENING_MAP, "evening map from 4:30 PM")
	t.check_eq(map.get_node("Backdrop").texture.resource_path, EVENING_MAP, "map backdrop follows")
	t.check_eq(map.map_image.texture.get_size(), Vector2(941, 1672), "evening map has the same size")
	var evening_pins := _pin_positions(map)
	var worst := 0.0
	for id in day_pins:
		t.check(evening_pins.has(id) and evening_pins[id][0] == day_pins[id][0], "pin %s keeps its map position" % id)
		worst = maxf(worst, (evening_pins[id][1] as Vector2).distance_to(day_pins[id][1]))
	t.check(worst < 0.5, "all six pins are laid out in the same place (max drift %.3f px)" % worst)
	await _shutdown(main)


func test_coming_soon_screen_in_the_evening() -> void:
	var main := await _boot_from_fixture({"minutes": 17 * 60})
	GameState.travel_to(GameData.get_location(&"bank"))
	await _wait(0.9)
	var place: LocationBase = main.current_location
	t.check_eq(String(place.location_data.id), "bank", "at City Bank (coming soon)")
	t.check_eq(place.get_node("Background").texture.resource_path, EVENING_MAP, "coming-soon art uses the evening map")
	await _shutdown(main)


func test_phone_banner_and_messages_icon() -> void:
	var main := await _boot_from_fixture()
	var phone: Phone = main.phone
	var expected := {510: "phone-sunrise", 800: "phone-afternoon", 1000: "phone-evening"}
	for m in expected:
		GameState.minutes = m
		phone.refresh()
		t.check(phone.banner.texture.resource_path.ends_with(expected[m] + ".png"), "%s banner at %s" % [expected[m], GameState.time_label()])
	var row: PhoneRow = phone.home.get_node("Messages")
	t.check(row.row_icon.resource_path.ends_with("pMsg-centered.png"), "centered Messages icon")
	t.check_eq(row.subtitle, "2 unread", "unread text unchanged")
	var badge: Label = row.get_node("Row/Icon/Badge")
	t.check(badge.visible and badge.text == "2", "red unread badge shows 2 (was painted into the old icon)")
	phone.open_page(&"messages")
	await t.get_tree().process_frame
	t.check(phone.page.visible, "messages page still opens")
	t.check_eq(row.subtitle, "0 unread", "reading messages still clears the count")
	t.check(not badge.visible, "badge clears after reading")
	phone.show_home()
	await _shutdown(main)


func test_tutorial_frame_pixel_default_and_classic() -> void:
	var main := await _boot_from_fixture()
	var hud: Hud = main.hud
	Tutorial.restart()
	await t.get_tree().process_frame
	t.check(hud.tutorial.visible, "replayed tutorial shows the card")
	t.check_eq(hud.tutorial_frame, Hud.TutorialFrame.PIXEL, "pixel frame is the default")
	t.check(hud.tutorial.get_theme_stylebox(&"panel") == Hud.PIXEL_TUTORIAL_FRAME, "card uses the 9-slice pixel frame")
	t.check(hud.tutorial_portrait_frame.get_theme_stylebox(&"panel") == Hud.PIXEL_PORTRAIT_SLOT, "portrait sits in the pixel slot")
	t.check_eq(hud.tip_title.text, Tutorial.STEPS[0].title, "step text unchanged")
	hud.tutorial_frame = Hud.TutorialFrame.CLASSIC
	t.check(not hud.tutorial.has_theme_stylebox_override(&"panel"), "classic: theme panel restored")
	t.check(hud.tutorial_portrait_frame.get_theme_stylebox(&"panel") is StyleBoxEmpty, "classic: no slot frame")
	t.check_eq(hud.tip_title.text, Tutorial.STEPS[0].title, "classic keeps the same text")
	hud.tutorial_frame = Hud.TutorialFrame.PIXEL
	Tutorial.skip()
	await t.get_tree().process_frame
	t.check(not hud.tutorial.visible, "SKIP still hides the card")
	Tutorial.restart()
	await t.get_tree().process_frame
	t.check(hud.tutorial.visible and hud.step_count.text.begins_with("1/"), "REPLAY restarts at step 1")
	# Mobile portrait layout keeps the frame and the slot.
	hud.apply_layout(true)
	await t.get_tree().process_frame
	t.check(hud.tutorial.get_theme_stylebox(&"panel") == Hud.PIXEL_TUTORIAL_FRAME, "portrait layout keeps the pixel frame")
	hud.apply_layout(false)
	Tutorial.skip()
	await _shutdown(main)


# --- Helpers --------------------------------------------------------------------

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


## Shader parameters read back as null until first set; unset means 0.
static func _glow(mat: ShaderMaterial) -> float:
	var v = mat.get_shader_parameter(&"highlight")
	return 0.0 if v == null else float(v)


static func _polygons(location: Node) -> Array:
	var out := []
	for n in location.get_node("Walls").get_children():
		if n is CollisionPolygon2D:
			out.append([n.name, n.polygon])
	return out


static func _pin_positions(map: TravelMap) -> Dictionary:
	var out := {}
	for id in map._pins:
		var pin := map._pins[id] as MapPin
		out[id] = [pin.location.map_position, pin.position]
	return out


static func _customers(main: Node) -> Array:
	return main.current_location.find_children("*", "Customer", true, false)


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
