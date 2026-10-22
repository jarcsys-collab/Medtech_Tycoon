extends RefCounted
## Save compatibility tests. Every test runs against a fresh temp directory (see test_runner.gd).

const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"
const FIXTURE_V1_LEGACY := "res://tests/fixtures/save_v1_legacy.json"

var t  # test runner: check(), check_eq()


# --- Loading existing version 1 saves -------------------------------------------

func test_loads_v1_save_and_keeps_progress() -> void:
	_install(_read(FIXTURE_V1))
	t.check(SaveSystem.load_game(), "v1 save loads")
	t.check_eq(SaveSystem.last_error, "", "no load error")
	t.check_eq(GameState.cash, 10422, "cash")
	t.check_eq(GameState.xp, 125, "xp")
	t.check_eq(GameState.level, 2, "level derived from xp with the existing thresholds")
	t.check_eq(GameState.day, 3, "day")
	t.check_eq(GameState.minutes, 520, "clock")
	t.check_eq(GameState.reputation, 2, "reputation")
	t.check_eq(String(GameState.location_id), "coffee", "location")
	t.check_eq(GameState.inventory, {"glucose_meter": 6, "pulse_oximeter": 6}, "inventory")
	t.check_eq(GameState.leads.size(), 2, "leads")
	t.check_eq(GameState.leads[1].id, 15, "lead id stays an int")
	t.check_eq(GameState.prospects.size(), 2, "prospects")
	t.check(GameState.prospects[1].met, "prospect met flag")
	t.check_eq(GameState.customers.size(), 4, "customers")
	t.check_eq(GameState.deals.size(), 1, "deals")
	t.check_eq(GameState.deals[0].amount, 480, "deal amount")
	t.check_eq(GameState.revenue_total, 480, "revenue total")
	t.check_eq(GameState.expenses_total, 58, "expenses total")
	t.check_eq(GameState.completed_tasks.size(), 6, "completed tasks")
	t.check(GameState.completed_tasks.has("reach_lv2"), "task ids preserved")
	t.check(GameState.tutorial_done, "tutorial done")
	t.check_eq(GameState.tutorial_step, 1, "tutorial step")
	t.check_eq(GameState._next_id, 19, "next id")
	t.check_eq(SaveSystem.last_warnings.size(), 0, "a clean save needs no repairs")


func test_loads_legacy_v1_without_tutorial_version() -> void:
	_install(_read(FIXTURE_V1_LEGACY))
	t.check(SaveSystem.load_game(), "legacy v1 save loads")
	t.check_eq(GameState.cash, 9876, "cash")
	t.check_eq(GameState.xp, 20, "xp")
	t.check_eq(GameState.inventory.size(), 3, "inventory")
	# Existing rule: an unfinished V1 tip carousel restarts the V2 guided tutorial.
	t.check_eq(GameState.tutorial_step, 0, "unfinished V1 tutorial restarts")
	t.check(not GameState.tutorial_done, "tutorial not done")


func test_loading_never_rewrites_the_save_file() -> void:
	var text := _read(FIXTURE_V1)
	_install(text)
	var before := FileAccess.get_sha256(SaveSystem.save_path)
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(FileAccess.get_sha256(SaveSystem.save_path), before, "save file unchanged by loading")
	t.check(not DirAccess.dir_exists_absolute(SaveSystem.backup_dir), "no backup for a current-version save")


func test_save_without_version_key_is_treated_as_v1() -> void:
	var data: Dictionary = JSON.parse_string(_read(FIXTURE_V1))
	data.erase("version")
	_install(JSON.stringify(data))
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(GameState.cash, 10422, "cash")


# --- Saving and reloading -------------------------------------------------------

func test_save_and_reload_round_trip() -> void:
	GameState.add_cash(1234)
	GameState.add_xp(130)
	GameState.add_reputation(7)
	GameState.add_stock("ecg_patch", 2)
	GameState.complete_task("open_phone")
	GameState.advance_time(95)
	var expected := GameState.to_dict()
	t.check(SaveSystem.save_game(), "saves")
	t.check(not FileAccess.file_exists(SaveSystem.save_path + ".tmp"), "no temp file left behind")
	GameState.new_game()
	t.check(SaveSystem.load_game(), "reloads")
	t.check_eq(JSON.stringify(GameState.to_dict(), "", true), JSON.stringify(expected, "", true), "state identical after reload")
	t.check_eq(GameState.level, GameData.level_for_xp(GameState.xp), "level recomputed")


func test_saving_twice_replaces_the_file() -> void:
	t.check(SaveSystem.save_game(), "first save")
	GameState.add_cash(500)
	t.check(SaveSystem.save_game(), "second save over an existing file")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	t.check_eq(data.version, SaveSystem.SAVE_VERSION, "version written")
	t.check_eq(data.state.cash, GameState.cash, "latest cash written")


func test_v1_save_survives_load_then_save() -> void:
	_install(_read(FIXTURE_V1))
	SaveSystem.load_game()
	var loaded := GameState.to_dict()
	t.check(SaveSystem.save_game(), "re-saves")
	GameState.new_game()
	t.check(SaveSystem.load_game(), "loads the re-saved file")
	t.check_eq(JSON.stringify(GameState.to_dict(), "", true), JSON.stringify(loaded, "", true), "nothing lost in a load/save cycle")


# --- Missing optional fields ----------------------------------------------------

func test_empty_state_uses_defaults() -> void:
	_install(JSON.stringify({"version": 1, "state": {}}))
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(GameState.day, 1, "default day")
	t.check_eq(GameState.cash, GameState.START_CASH, "default cash")
	t.check_eq(GameState.minutes, GameState.START_MINUTES, "default clock")
	t.check_eq(GameState.xp, 0, "default xp")
	t.check_eq(String(GameState.location_id), "home", "default location")
	t.check_eq(GameState.leads.size(), 0, "no leads")
	t.check(not GameState.tutorial_done, "tutorial not done")


func test_partial_state_keeps_present_fields() -> void:
	_install(JSON.stringify({"version": 1, "state": {"cash": 777, "xp": 260, "day": 9}}))
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(GameState.cash, 777, "cash kept")
	t.check_eq(GameState.xp, 260, "xp kept")
	t.check_eq(GameState.level, 3, "level from xp")
	t.check_eq(GameState.day, 9, "day kept")
	t.check_eq(GameState.reputation, 0, "missing reputation defaults")


func test_unknown_location_falls_back_home() -> void:
	_install(JSON.stringify({"version": 1, "state": {"location_id": "moon_base"}}))
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(String(GameState.location_id), "home", "unknown place -> home")


# --- Malformed data -------------------------------------------------------------

func test_invalid_json_is_rejected_and_backed_up() -> void:
	_expect_rejected("{ \"version\": 1, \"state\": { \"cash\": 10", "corrupt")


func test_truncated_file_is_rejected_and_backed_up() -> void:
	var text := _read(FIXTURE_V1)
	_expect_rejected(text.substr(0, text.length() / 2), "corrupt")


func test_empty_file_is_rejected() -> void:
	_expect_rejected("", "corrupt")


func test_wrong_top_level_shapes_are_rejected() -> void:
	for text in ["[1, 2, 3]", "\"hello\"", "{\"version\": 1}", "{\"version\": 1, \"state\": [1]}", "{\"version\": \"one\", \"state\": {}}", "{\"version\": 0, \"state\": {}}"]:
		_install(text)
		GameState.new_game()
		GameState.add_cash(42)
		var cash := GameState.cash
		t.check(not SaveSystem.load_game(), "rejects %s" % text)
		t.check_eq(GameState.cash, cash, "state untouched for %s" % text)


func test_wrong_field_types_are_repaired_not_fatal() -> void:
	var data: Dictionary = JSON.parse_string(_read(FIXTURE_V1))
	data.state.cash = "lots"
	data.state.reputation = 250
	data.state.inventory = {"glucose_meter": 4, "pulse_oximeter": -3, "bp_monitor": "x"}
	data.state.leads.append("not a lead")
	data.state.leads.append({"id": 30, "name": "No Product"})
	data.state.deals.append(42)
	data.state.customers.append(7)
	data.state.tutorial_done = "yes"
	data.state.minutes = 520.0
	_install(JSON.stringify(data))
	t.check(SaveSystem.load_game(), "loads with repairs")
	t.check_eq(GameState.cash, GameState.START_CASH, "bad cash -> default")
	t.check_eq(GameState.reputation, 100, "reputation clamped")
	t.check_eq(GameState.inventory, {"glucose_meter": 4}, "only valid inventory kept")
	t.check_eq(GameState.leads.size(), 2, "malformed leads skipped, good ones kept")
	t.check_eq(GameState.deals.size(), 1, "malformed deal skipped")
	t.check_eq(GameState.customers.size(), 4, "non-text customer skipped")
	t.check(not GameState.tutorial_done, "bad tutorial flag -> default")
	t.check_eq(GameState.minutes, 520, "whole float accepted")
	t.check(SaveSystem.last_warnings.size() >= 7, "repairs reported (%d)" % SaveSystem.last_warnings.size())
	var backups := _backups()
	t.check(backups.size() == 1 and backups[0].contains("-repaired-"), "original kept as a 'repaired' backup")
	if backups.size() == 1:
		t.check_eq(FileAccess.get_file_as_string(SaveSystem.backup_dir.path_join(backups[0])), JSON.stringify(data), "backup is the unrepaired file")


func test_next_id_is_kept_above_saved_ids() -> void:
	var data: Dictionary = JSON.parse_string(_read(FIXTURE_V1))
	data.state.next_id = 2
	_install(JSON.stringify(data))
	t.check(SaveSystem.load_game(), "loads")
	t.check_eq(GameState._next_id, 18, "next id raised past the highest saved id (17)")
	t.check_eq(_backups().size(), 1, "repaired save backed up")


# --- Future versions and migrations ---------------------------------------------

func test_newer_save_version_is_refused_and_kept() -> void:
	var data: Dictionary = JSON.parse_string(_read(FIXTURE_V1))
	data.version = SaveSystem.SAVE_VERSION + 1
	_expect_rejected(JSON.stringify(data), "unsupported")
	t.check(SaveSystem.last_error.contains("newer"), "explains the newer version")


func test_migration_steps_run_in_order() -> void:
	var steps := {1: _step_1_to_2, 2: _step_2_to_3}
	var original := {"cash": 10}
	var r := SaveMigrator.migrate(original, 1, 3, steps)
	t.check_eq(r.status, SaveMigrator.Status.OK, "migrates 1 -> 3")
	t.check_eq(r.state.trail, ["1to2", "2to3"], "steps ran in order")
	t.check_eq(r.state.cash, 11, "step changes applied")
	t.check_eq(original, {"cash": 10}, "input state not modified")
	var gap := SaveMigrator.migrate({}, 1, 3, {1: _step_1_to_2})
	t.check_eq(gap.status, SaveMigrator.Status.UNSUPPORTED, "missing step is reported, not skipped")


func test_upgrade_backs_up_the_original_first() -> void:
	var original := _read(FIXTURE_V1)
	_install(original)
	SaveSystem.current_version = 2
	SaveSystem.migrations = {1: _step_1_to_2}
	t.check(SaveSystem.load_game(), "v1 save upgrades to a (test) v2")
	t.check_eq(GameState.cash, 10422, "progress kept through the upgrade")
	var backups := _backups()
	t.check_eq(backups.size(), 1, "one backup made before upgrading")
	if backups.size() == 1:
		t.check(backups[0].contains("-v1-"), "backup named after the old version")
		t.check_eq(FileAccess.get_file_as_string(SaveSystem.backup_dir.path_join(backups[0])), original, "backup is the untouched original")
	t.check_eq(FileAccess.get_file_as_string(SaveSystem.save_path), original, "original file not rewritten until the next save")


func test_real_world_fixture_parses_without_warnings() -> void:
	var r := SaveMigrator.parse(_read(FIXTURE_V1), SaveSystem.SAVE_VERSION, SaveSystem.MIGRATIONS)
	t.check_eq(r.status, SaveMigrator.Status.OK, "parses")
	t.check_eq(r.version, 1, "reports version 1")
	t.check_eq(r.warnings.size(), 0, "no repairs needed")


# --- Helpers --------------------------------------------------------------------

## Example upgrade steps for the migration tests (not real formats).
func _step_1_to_2(s: Dictionary) -> Dictionary:
	s.trail = ["1to2"]
	return s


func _step_2_to_3(s: Dictionary) -> Dictionary:
	s.trail.append("2to3")
	s.cash += 1
	return s

## A rejected save must leave GameState alone, stay on disk unchanged and get a backup copy.
func _expect_rejected(text: String, tag: String) -> void:
	_install(text)
	GameState.add_cash(321)
	var expected := GameState.to_dict()
	var before := FileAccess.get_sha256(SaveSystem.save_path)
	t.check(not SaveSystem.load_game(), "rejected")
	t.check(SaveSystem.last_error != "", "reason recorded")
	t.check_eq(SaveSystem.load_failure_message(), "Save could not be loaded. A backup copy was kept.", "player message")
	t.check_eq(JSON.stringify(GameState.to_dict(), "", true), JSON.stringify(expected, "", true), "game state untouched")
	t.check_eq(FileAccess.get_sha256(SaveSystem.save_path), before, "save file left as it was")
	var backups := _backups()
	t.check_eq(backups.size(), 1, "one backup copy")
	if backups.size() == 1:
		t.check(backups[0].contains("-%s-" % tag), "backup tagged %s" % tag)
		t.check_eq(FileAccess.get_file_as_string(SaveSystem.backup_dir.path_join(backups[0])), text, "backup is byte-identical")


func _install(text: String) -> void:
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	if DirAccess.dir_exists_absolute(SaveSystem.backup_dir):
		for b in DirAccess.get_files_at(SaveSystem.backup_dir):
			DirAccess.remove_absolute(SaveSystem.backup_dir.path_join(b))


func _backups() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(SaveSystem.backup_dir):
		return PackedStringArray()
	return DirAccess.get_files_at(SaveSystem.backup_dir)


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
