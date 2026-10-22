extends Node
## JSON save/load in user:// (Godot-native FileAccess). Medtycoonv1 had no persistence.
##
## Loading never destroys data: a save that is unreadable, damaged or from a newer game version is
## copied to BACKUP_DIR before the game can overwrite it, and the reason is kept in `last_error`.
## A save that loads only after repairs (bad entries skipped) is copied there too.
## Older versions are upgraded step by step (see SaveMigrator), after copying the original file.
## Writes go to a temporary file first and replace the save only once complete.

signal saved
signal loaded

const SAVE_PATH := "user://savegame.json"
const BACKUP_DIR := "user://save_backups"
const SAVE_VERSION := 1
## from_version -> Callable(state: Dictionary) -> Dictionary (state of from_version + 1).
## Version 1 is the first format, so there is nothing to upgrade yet.
const MIGRATIONS := {}

## Overridable so tests run against temporary files, never the player's save.
var save_path := SAVE_PATH
var backup_dir := BACKUP_DIR
var current_version := SAVE_VERSION
var migrations: Dictionary = MIGRATIONS
## Why the last load_game() did not load ("" = it loaded, or there was no save).
var last_error := ""
## Field-level problems repaired by the last successful load.
var last_warnings: Array[String] = []


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var data := {"version": current_version, "saved_at": Time.get_datetime_string_from_system(), "state": GameState.to_dict()}
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("SaveSystem: writing %s failed (%s)" % [tmp_path, error_string(write_error)])
		DirAccess.remove_absolute(tmp_path)
		return false
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_error("SaveSystem: cannot replace %s (%s)" % [save_path, error_string(err)])
		DirAccess.remove_absolute(tmp_path)
		return false
	saved.emit()
	return true


## Loads the save into GameState. Returns false (and leaves GameState untouched) when there is no
## save or it cannot be used; in the second case `last_error` says why and a backup copy exists.
func load_game() -> bool:
	last_error = ""
	last_warnings = []
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _reject("the save file could not be opened (%s)" % error_string(FileAccess.get_open_error()), "unreadable")
	var text := file.get_as_text()
	file.close()
	var result := SaveMigrator.parse(text, current_version, migrations)
	match result.status:
		SaveMigrator.Status.CORRUPT:
			return _reject("the save file is damaged: " + result.error, "corrupt")
		SaveMigrator.Status.UNSUPPORTED:
			return _reject("the save needs a newer game version: " + result.error, "unsupported")
	if result.version < current_version and _backup("v%d" % result.version) == "":
		# Keep the old file untouched rather than upgrade without a copy of it.
		last_error = "could not back up the save before upgrading it"
		push_error("SaveSystem: " + last_error)
		return false
	last_warnings = result.warnings
	for w in last_warnings:
		push_warning("SaveSystem: repaired " + w)
	# Repairs drop bad entries; keep the file as it was before the next save replaces it.
	if not last_warnings.is_empty() and result.version == current_version:
		_backup("repaired")
	GameState.from_dict(result.state)
	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


## Message for the player when load_game() returned false.
func load_failure_message() -> String:
	if last_error == "":
		return "No save found"
	return "Save could not be loaded. A backup copy was kept."


func _reject(reason: String, tag: String) -> bool:
	last_error = reason
	var copy := _backup(tag)
	push_warning("SaveSystem: %s. %s" % [reason, ("Backup: " + copy) if copy != "" else "Backup FAILED"])
	return false


## Copies the current save file to backup_dir and returns the copy's path ("" on failure).
func _backup(tag: String) -> String:
	var dir_path := _absolute(backup_dir)
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var target := dir_path.path_join("%s-%s-%s.json" % [save_path.get_file().get_basename(), tag, stamp])
	var n := 1
	while FileAccess.file_exists(target):
		n += 1
		target = dir_path.path_join("%s-%s-%s-%d.json" % [save_path.get_file().get_basename(), tag, stamp, n])
	if DirAccess.copy_absolute(_absolute(save_path), target) != OK:
		return ""
	return target


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
