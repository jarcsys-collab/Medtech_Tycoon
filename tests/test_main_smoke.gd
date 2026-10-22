extends RefCounted
## Boots the real main scene against temp save files (see test_runner.gd) to check that existing
## gameplay still starts, travels and autosaves.

const MAIN_SCENE := "res://scenes/main/main.tscn"

var t  # test runner


func test_main_boots_from_v1_save_and_autosaves_on_travel() -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/save_v1.json"), SaveSystem.save_path)
	var main := await _boot()
	t.check_eq(SaveSystem.last_error, "", "save loaded at startup")
	t.check_eq(GameState.cash, 10422, "progress restored")
	t.check(main.current_location != null, "a location scene is loaded")
	t.check_eq(String(GameState.location_id), "coffee", "starts where the save left off")
	t.check(main.player != null and main.player.is_inside_tree(), "player spawned")
	var cash := GameState.cash
	t.check(GameState.travel_to(GameData.get_location(&"home")), "can travel home")
	await _wait(1.0)
	t.check_eq(String(main.current_location.location_data.id), "home", "home scene loaded")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	t.check_eq(saved.state.location_id, "home", "travel autosaved to the (temp) save")
	t.check_eq(saved.state.cash, cash, "fare to home is free, cash unchanged")
	await _shutdown(main)


func test_main_boots_with_damaged_save_and_keeps_a_backup() -> void:
	var damaged := "{ \"version\": 1, \"state\": { \"cash\": 99"
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(damaged)
	f.close()
	var main := await _boot()
	t.check(SaveSystem.last_error != "", "damaged save reported")
	t.check_eq(GameState.cash, GameState.START_CASH, "falls back to a new game")
	t.check(main.current_location != null, "game still starts")
	# Autosave (travel) overwrites the damaged file; the backup must still hold the original.
	GameState.travel_to(GameData.get_location(&"coffee"))
	await _wait(1.0)
	var backups := DirAccess.get_files_at(SaveSystem.backup_dir)
	t.check_eq(backups.size(), 1, "one backup")
	if backups.size() == 1:
		t.check_eq(FileAccess.get_file_as_string(SaveSystem.backup_dir.path_join(backups[0])), damaged, "original damaged save preserved")
	await _shutdown(main)


func _boot() -> Node:
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	return main


func _shutdown(main: Node) -> void:
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
