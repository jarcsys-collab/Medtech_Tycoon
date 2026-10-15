extends Node
## JSON save/load in user:// (Godot-native FileAccess). Medtycoonv1 had no persistence.

signal saved
signal loaded

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	var data := {"version": SAVE_VERSION, "saved_at": Time.get_datetime_string_from_system(), "state": GameState.to_dict()}
	file.store_string(JSON.stringify(data, "\t"))
	saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("state")) != TYPE_DICTIONARY:
		push_warning("SaveSystem: save file is corrupt, ignoring it")
		return false
	GameState.from_dict(data.state)
	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
