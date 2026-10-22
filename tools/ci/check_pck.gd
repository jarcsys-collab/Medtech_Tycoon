extends SceneTree
## CI guard for the Web export (run from an empty throwaway project, never this one):
##   godot --headless --path <empty_project> -s check_pck.gd -- <export_dir>/index.pck
## Fails if development-only MCP files, addons, tests, reference packs or secrets reached the PCK,
## or if the MCP runtime autoload is still registered in the exported project settings.

const REQUIRED_AUTOLOADS := ["GameData", "GameState", "SaveSystem", "UIEvents", "Tutorial",
	"Responsive", "MusicManager", "SfxManager", "AudioDirector"]
const FORBIDDEN_AUTOLOADS := ["MCPRuntimeServer"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("usage: -- <path/to/index.pck>")
		return
	if not ProjectSettings.load_resource_pack(args[0], true):
		_fail("cannot load %s" % args[0])
		return

	var files: Array[String] = []
	_walk("res://", files)
	var flagged := 0
	for f in files:
		var lf := f.to_lower()
		if lf.contains("mcp") or lf.begins_with("res://addons/") or lf.begins_with("res://tests/") or lf.contains("import demo") \
				or lf.begins_with("res://builds/") or lf.get_file().begins_with(".env") \
				or lf.ends_with("mcp_token"):
			print("FORBIDDEN FILE: ", f)
			flagged += 1

	var settings := _printable(FileAccess.get_file_as_bytes("res://project.binary"))
	if settings.is_empty():
		print("MISSING: res://project.binary")
		flagged += 1
	for n in FORBIDDEN_AUTOLOADS:
		if settings.contains("autoload/" + n):
			print("FORBIDDEN AUTOLOAD: ", n)
			flagged += 1
	for n in REQUIRED_AUTOLOADS:
		if not settings.contains("autoload/" + n):
			print("MISSING AUTOLOAD: ", n)
			flagged += 1
	if not settings.contains("res://scenes/main/main.tscn"):
		print("MISSING: main scene setting")
		flagged += 1

	print("PCK files: %d, problems: %d" % [files.size(), flagged])
	quit(1 if flagged > 0 else 0)


func _fail(msg: String) -> void:
	printerr("check_pck: ", msg)
	quit(2)


## project.binary is binary; keep printable ASCII so key names can be searched.
func _printable(raw: PackedByteArray) -> String:
	var out := PackedStringArray()
	for b in raw:
		out.append(char(b) if b >= 32 and b < 127 else " ")
	return "".join(out)


func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)
