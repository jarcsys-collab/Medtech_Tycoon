extends Node
## Background music: two AudioStreamPlayers on the Music bus crossfade between looping tracks.
## Requesting the track that is already playing does nothing. Location tracks resume where they
## left off (e.g. after closing the City Map). Ducking is applied as an offset on the Music bus,
## so it never fights the crossfade tweens. Track data from docs/audio/AUDIO_MANIFEST.md.

const BUS := &"Music"
const SILENT_DB := -60.0
const DIR := "res://assets/audio/music/"

## id -> [file, volume_db, fade_in, fade_out]. Ids are location ids or menu states.
const TRACKS := {
	&"home": ["apartment_theme.wav", -7.0, 1.5, 1.2],
	&"coffee": ["cafe_theme.wav", -7.0, 1.5, 1.2],
	&"warehouse": ["supplier_depot_theme.wav", -8.0, 1.5, 1.2],
	&"bank": ["city_bank_theme.wav", -8.0, 1.5, 1.2],
	&"office": ["office_park_theme.wav", -8.0, 1.5, 1.2],
	&"expo": ["trade_expo_theme.wav", -8.0, 1.0, 1.2],
	&"travel": ["travel_theme.wav", -7.0, 0.8, 0.8],
	&"finance": ["finance_theme.wav", -9.0, 1.0, 1.0],
	&"inventory": ["inventory_theme.wav", -8.0, 1.0, 1.0],
	&"meeting": ["sales_meeting_theme.wav", -9.0, 2.0, 1.5],
}

var current: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tweens := {}           # player -> Tween
var _positions := {}        # track id -> playback position (s)
var _streams := {}          # track id -> AudioStream (lazy cache)
var _bus_index := -1
var _bus_base_db := 0.0
var _duck_hold_db := 0.0    # sustained duck (phone overlay)
var _duck_hit_db := 0.0     # temporary duck under stingers
var _hit_tween: Tween
var _hold_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_index = AudioServer.get_bus_index(BUS)
	if _bus_index >= 0:
		_bus_base_db = AudioServer.get_bus_volume_db(_bus_index)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Player%s" % ["A", "B"][i]
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


func _process(_delta: float) -> void:
	if _bus_index >= 0:
		AudioServer.set_bus_volume_db(_bus_index, _bus_base_db + minf(_duck_hold_db, _duck_hit_db))


## Crossfade to `id`. No-op when it is already the current track.
func play_track(id: StringName, resume := true) -> void:
	if id == current or not TRACKS.has(id):
		return
	var info: Array = TRACKS[id]
	var stream := _stream(id)
	if stream == null:
		return
	var old := _players[_active]
	var fade_out: float = TRACKS[current][3] if TRACKS.has(current) else 0.8
	if old.playing and current != &"":
		_positions[current] = old.get_playback_position()
		_fade(old, SILENT_DB, fade_out, true)
	_active = 1 - _active
	var p := _players[_active]
	_kill(p)
	p.stream = stream
	p.volume_db = SILENT_DB
	var from: float = _positions.get(id, 0.0) if resume else 0.0
	p.play(fmod(from, maxf(stream.get_length(), 0.01)))
	_fade(p, info[1], info[2], false)
	current = id


## Fade everything out (e.g. before the end-of-day jingle).
func fade_out_all(duration := 1.5) -> void:
	var p := _players[_active]
	if p.playing and current != &"":
		_positions[current] = p.get_playback_position()
		_fade(p, SILENT_DB, duration, true)
	current = &""


## Forget resume points (new day / loaded game start tracks from the top).
func forget_positions() -> void:
	_positions.clear()


## Music bus level before ducking (player volume setting, see SfxManager.set_volume).
func set_base_volume_db(db: float) -> void:
	_bus_base_db = db


## Sustained duck, e.g. while the phone overlay is open (0 = none).
func set_hold_duck(db: float, time := 0.3) -> void:
	if _hold_tween:
		_hold_tween.kill()
	if time <= 0.0:
		_duck_hold_db = db
		return
	_hold_tween = create_tween()
	_hold_tween.tween_property(self, "_duck_hold_db", db, time)


## Short duck under a jingle: attack, hold, release.
func duck_for(db: float, hold: float) -> void:
	if _hit_tween:
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_duck_hit_db", db, 0.15)
	_hit_tween.tween_interval(hold)
	_hit_tween.tween_property(self, "_duck_hit_db", 0.0, 0.6)


func _stream(id: StringName) -> AudioStream:
	if not _streams.has(id):
		var s := load(DIR + TRACKS[id][0]) as AudioStream
		if s == null:
			push_warning("MusicManager: missing track %s" % TRACKS[id][0])
		_streams[id] = s
	return _streams[id]


func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	_kill(p)
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, maxf(time, 0.01)).set_trans(Tween.TRANS_SINE)
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[p] = t


func _kill(p: AudioStreamPlayer) -> void:
	var t: Tween = _tweens.get(p)
	if t and t.is_valid():
		t.kill()
