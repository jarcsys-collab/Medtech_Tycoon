extends Node
## Minimal headless test runner (no addon needed). Runs as a normal scene so every game autoload
## exists exactly as in play; the main scene is NOT loaded, so nothing autosaves.
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = a failure. Each test_* method gets a fresh temp directory and
## SaveSystem pointed into it; the player's real save is checked to be byte-identical afterwards.

const SUITES := ["res://tests/test_save_system.gd", "res://tests/test_main_smoke.gd", "res://tests/test_characters.gd",
	"res://tests/test_environments.gd", "res://tests/test_responsive.gd"]

var tmp_root := ""
var _failures: Array[String] = []
var _current := ""
var _checks := 0
var _script_errors := ScriptErrorLog.new()


## A script error inside a test ends that test's function silently; this logger records it so the
## test fails instead of passing with its remaining checks skipped.
class ScriptErrorLog extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_lock.lock()
			errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
			_lock.unlock()

	func take() -> Array[String]:
		_lock.lock()
		var out := errors.duplicate()
		errors.clear()
		_lock.unlock()
		return out


func _ready() -> void:
	OS.add_logger(_script_errors)
	_run.call_deferred()


func _run() -> void:
	var real_save := ProjectSettings.globalize_path(SaveSystem.SAVE_PATH)
	var real_backups := ProjectSettings.globalize_path(SaveSystem.BACKUP_DIR)
	var before := _fingerprint(real_save, real_backups)
	tmp_root = OS.get_temp_dir().path_join("medtycoon-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var passed := 0
	var total := 0
	for path in SUITES:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			_current = path
			check(false, "test suite failed to load (parse error?)")
			total += 1
			continue
		var suite: Object = script.new()
		suite.set("t", self)
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			_current = "%s::%s" % [path.get_file().get_basename(), name]
			var failures_before := _failures.size()
			_isolate(name)
			_script_errors.take()
			await suite.call(name)
			for e in _script_errors.take():
				check(false, "script error: " + e)
			if _failures.size() == failures_before:
				passed += 1
				print("  PASS  ", _current)
			else:
				print("  FAIL  ", _current)
	_remove_tree(tmp_root)
	check(_fingerprint(real_save, real_backups) == before, "player's real save and backups were not touched")
	print("\n%d/%d tests passed, %d checks, %d failures" % [passed, total, _checks, _failures.size()])
	for f in _failures:
		print("  - ", f)
	get_tree().quit(0 if _failures.is_empty() and total > 0 else 1)


## Fresh temp directory and default SaveSystem settings, pointed away from user://.
func _isolate(test_name: String) -> void:
	var dir := tmp_root.path_join(test_name)
	DirAccess.make_dir_recursive_absolute(dir)
	SaveSystem.save_path = dir.path_join("savegame.json")
	SaveSystem.backup_dir = dir.path_join("save_backups")
	SaveSystem.current_version = SaveSystem.SAVE_VERSION
	SaveSystem.migrations = SaveSystem.MIGRATIONS
	if SaveSystem.save_path.begins_with("user://") or SaveSystem.backup_dir.begins_with("user://"):
		push_error("Test isolation failed; refusing to run against user://")
		get_tree().quit(2)
	GameState.new_game()


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append("%s: %s" % [_current, what])
		push_error("FAILED %s: %s" % [_current, what])


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(_same(actual, expected), "%s (expected %s, got %s)" % [what, str(expected), str(actual)])


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return a == b
	return typeof(a) == typeof(b) and a == b


static func _fingerprint(save_file: String, backup_dir: String) -> String:
	var parts := [FileAccess.get_sha256(save_file) if FileAccess.file_exists(save_file) else "none"]
	if DirAccess.dir_exists_absolute(backup_dir):
		parts.append_array(DirAccess.get_files_at(backup_dir))
	return ",".join(parts)


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
