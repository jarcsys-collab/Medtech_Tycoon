extends Node
## One-shot sound effects through a small round-robin pool of AudioStreamPlayers.
## Per-sound cooldown stops stacking on rapid clicks; groups pick a random variant without
## repeating the last one (footsteps). Volumes/buses from docs/audio/AUDIO_MANIFEST.md.

const POOL_SIZE := 8
const COOLDOWN := 0.05

## id -> [path, bus, volume_db, pitch_jitter]
const SOUNDS := {
	&"ui_click": ["res://assets/audio/ui/ui_click.wav", &"UI", -12.0, 0.05],
	&"ui_hover": ["res://assets/audio/ui/ui_hover.wav", &"UI", -18.0, 0.0],
	&"ui_tab_select": ["res://assets/audio/ui/ui_tab_select.wav", &"UI", -11.0, 0.0],
	&"ui_panel_open": ["res://assets/audio/ui/ui_panel_open.wav", &"UI", -10.0, 0.0],
	&"ui_panel_close": ["res://assets/audio/ui/ui_panel_close.wav", &"UI", -11.0, 0.0],
	&"ui_locked": ["res://assets/audio/ui/ui_locked.wav", &"UI", -9.0, 0.0],
	&"map_open": ["res://assets/audio/ui/map_open.wav", &"UI", -8.0, 0.0],
	&"map_pin_select": ["res://assets/audio/ui/map_pin_select.wav", &"UI", -9.0, 0.0],
	&"travel_confirm": ["res://assets/audio/ui/travel_confirm.wav", &"UI", -7.0, 0.0],
	&"sale_success": ["res://assets/audio/sfx/sales/sale_success.wav", &"SFX", -5.0, 0.0],
	&"purchase": ["res://assets/audio/sfx/sales/purchase.wav", &"SFX", -7.0, 0.0],
	&"notification_message": ["res://assets/audio/sfx/notifications/notification_message.wav", &"SFX", -7.0, 0.0],
	&"new_lead": ["res://assets/audio/sfx/notifications/new_lead.wav", &"SFX", -6.0, 0.0],
	&"level_up": ["res://assets/audio/sfx/progression/level_up.wav", &"SFX", -4.0, 0.0],
	&"reputation_up": ["res://assets/audio/sfx/progression/reputation_up.wav", &"SFX", -6.0, 0.0],
	&"task_complete": ["res://assets/audio/sfx/progression/task_complete.wav", &"SFX", -7.0, 0.0],
	&"achievement_unlocked": ["res://assets/audio/sfx/progression/achievement_unlocked.wav", &"SFX", -4.0, 0.0],
	&"day_end": ["res://assets/audio/sfx/progression/day_end.wav", &"SFX", -5.0, 0.0],
	&"day_start": ["res://assets/audio/sfx/progression/day_start.wav", &"SFX", -5.0, 0.0],
	&"location_unlocked": ["res://assets/audio/sfx/progression/location_unlocked.wav", &"SFX", -5.0, 0.0],
}

## group id -> [paths, bus, volume_db, pitch_jitter]
const GROUPS := {
	&"footstep_wood": [[
		"res://assets/audio/ambient/footstep_wood_01.wav", "res://assets/audio/ambient/footstep_wood_02.wav",
		"res://assets/audio/ambient/footstep_wood_03.wav", "res://assets/audio/ambient/footstep_wood_04.wav",
	], &"Ambient", -16.0, 0.08],
	&"footstep_tile": [[
		"res://assets/audio/ambient/footstep_tile_01.wav", "res://assets/audio/ambient/footstep_tile_02.wav",
		"res://assets/audio/ambient/footstep_tile_03.wav", "res://assets/audio/ambient/footstep_tile_04.wav",
	], &"Ambient", -16.0, 0.08],
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}        # path -> AudioStream
var _last_time := {}    # id -> msec
var _last_variant := {} # group -> index

## Medtycoonv2: player volume settings (0..1 per bus), persisted to user://settings.json.
const SETTINGS_PATH := "user://settings.json"
var volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
var _bus_base_db := {}  # bus -> mix level from default_bus_layout.tres


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)
	for bus in volumes:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			_bus_base_db[bus] = AudioServer.get_bus_volume_db(idx)
	_load_settings()


## Set a bus volume (0..1) on top of the mix level, and save it. No settings UI exists yet.
func set_volume(bus: String, linear: float) -> void:
	if not volumes.has(bus):
		return
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus)
	_save_settings()


func _apply_volume(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v: float = volumes[bus]
	var db: float = float(_bus_base_db.get(bus, 0.0)) + linear_to_db(maxf(v, 0.001))
	AudioServer.set_bus_mute(idx, v <= 0.001)
	if bus == "Music":
		MusicManager.set_base_volume_db(db)  # MusicManager owns the Music bus level (ducking)
	else:
		AudioServer.set_bus_volume_db(idx, db)


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"volumes": volumes}))


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY and typeof(d.get("volumes")) == TYPE_DICTIONARY:
			for k in d.volumes:
				if volumes.has(k):
					volumes[k] = clampf(float(d.volumes[k]), 0.0, 1.0)
	for k in volumes:
		_apply_volume(k)


func play(id: StringName) -> void:
	if not SOUNDS.has(id) or _cooling(id):
		return
	var s: Array = SOUNDS[id]
	_play_stream(_load(s[0]), s[1], s[2], s[3])


func play_group(group: StringName) -> void:
	if not GROUPS.has(group) or _cooling(group):
		return
	var g: Array = GROUPS[group]
	var paths: Array = g[0]
	var i := randi() % paths.size()
	if paths.size() > 1 and i == _last_variant.get(group, -1):
		i = (i + 1 + randi() % (paths.size() - 1)) % paths.size()
	_last_variant[group] = i
	_play_stream(_load(paths[i]), g[1], g[2], g[3])


func _cooling(id: StringName) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_time.get(id, -100000)) < int(COOLDOWN * 1000.0):
		return true
	_last_time[id] = now
	return false


func _play_stream(stream: AudioStream, bus: StringName, volume_db: float, jitter: float) -> void:
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stop()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter) if jitter > 0.0 else 1.0
	p.play()


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
