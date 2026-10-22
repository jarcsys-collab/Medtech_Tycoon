extends RefCounted
## G1a character visuals and movement, checked on the real main scene (temp saves; see test_runner.gd).
## Wandering is observed with Engine.time_scale raised so a few real seconds cover ~20 game seconds.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const FIXTURE_V1 := "res://tests/fixtures/save_v1.json"  # saved at Coffee Corner, 2 café prospects
const TIME_SCALE := 4.0
## Sales Simulator v3 design values, checked independently of the code's constants.
const DESIGN_STRIDE := 0.5
const DESIGN_STEP_SPEED := 26.0
const DESIGN_MIN_PAUSE := 0.6

var t  # test runner


func test_outfit_switches_between_home_and_outside() -> void:
	var main := await _boot_from_fixture()
	var player: Player = main.player
	t.check_eq(String(GameState.location_id), "coffee", "starts at the café")
	t.check(player.sprite.sprite_frames == Player.OUTDOOR_FRAMES, "outdoor outfit at the café")
	await _travel(&"home")
	t.check(player.sprite.sprite_frames == Player.INDOOR_FRAMES, "indoor outfit at home")
	t.check(player.sprite.is_playing() and player.sprite.animation == &"idle", "idle animation keeps playing after the swap")
	await _travel(&"coffee")
	t.check(player.sprite.sprite_frames == Player.OUTDOOR_FRAMES, "outdoor outfit again after leaving home")
	await _shutdown(main)


func test_outdoor_frames_have_expected_layout() -> void:
	var f: SpriteFrames = Player.OUTDOOR_FRAMES
	t.check_eq(f.get_frame_count(&"idle"), 4, "4 outdoor idle frames")
	t.check_eq(f.get_frame_count(&"walk"), 8, "8 outdoor walk frames")
	t.check_eq(f.get_frame_texture(&"idle", 0).get_size(), Vector2(100, 235), "idle frame size")
	t.check_eq(f.get_frame_texture(&"walk", 0).get_size(), Vector2(130, 235), "walk frame size (130 px wide, centred on the feet)")
	t.check_eq(f.get_animation_speed(&"idle"), Player.INDOOR_FRAMES.get_animation_speed(&"idle"), "same idle fps as indoors")
	t.check_eq(f.get_animation_speed(&"walk"), Player.INDOOR_FRAMES.get_animation_speed(&"walk"), "same walk fps as indoors")


func test_cafe_customers_wear_outdoor_outfits_and_still_talk() -> void:
	var main := await _boot_from_fixture()
	var customers := _customers(main)
	t.check_eq(customers.size(), 2, "both unsold café prospects are present")
	for c in customers:
		t.check(c.sprite.sprite_frames == Player.OUTDOOR_FRAMES, "customer %d uses the outdoor sheet" % c.lead_id)
		t.check(c.sprite.modulate != Color.WHITE, "customer %d keeps its tint" % c.lead_id)
		t.check(c.talk.can_interact(), "customer %d can be talked to" % c.lead_id)
	var unmet := customers.filter(func(c: Customer): return not GameState.find_prospect(c.lead_id).met)
	t.check(unmet.size() == 1 and unmet[0].talk.prompt.begins_with("Talk to"), "unmet prospect offers 'Talk to'")
	if unmet.size() == 1:
		unmet[0]._introduce()  # same call as choosing "Introduce yourself" in the dialog
		await t.get_tree().process_frame
		t.check(GameState.find_prospect(unmet[0].lead_id).met, "introducing still turns a prospect into a lead")
		t.check(unmet[0].talk.prompt.begins_with("Pitch"), "prompt switches to 'Pitch'")
		t.check(main.choice_dialog.visible, "the pitch dialog opens as before")
	await _shutdown(main)


func test_player_step_wander_short_strides_first_frame() -> void:
	var main := await _boot_from_fixture()
	var player: Player = main.player
	await _travel(&"home")
	seed(1234)
	player._wander.hold(0.2)
	var log := await _record(player, 22.0)
	var strides := _strides(log)
	t.check(strides.size() >= 2, "player took several strides (%d)" % strides.size())
	for s in strides:
		t.check(s.duration <= DESIGN_STRIDE + 2.0 * s.dt, "stride lasts at most ~0.5 s (%.2f)" % s.duration)
	t.check(_max_speed(log) <= DESIGN_STEP_SPEED * 1.05, "wander speed <= 26 px/s (max %.1f)" % _max_speed(log))
	t.check(_min_gap(strides) >= DESIGN_MIN_PAUSE - 0.1, "pauses of at least 0.6 s between strides (%.2f)" % _min_gap(strides))
	t.check(log.filter(func(e): return e.moving).all(func(e): return e.anim == &"walk" and e.frame == 0 and not e.playing),
		"walk holds the first step frame while wandering")
	t.check(log.filter(func(e): return not e.moving and e.anim == &"idle").any(func(e): return e.playing), "idle animation plays between strides")
	await _shutdown(main)


func test_keyboard_walking_keeps_full_speed_and_cycle() -> void:
	var main := await _boot_from_fixture()
	var player: Player = main.player
	await _travel(&"home")
	var start := player.global_position
	var frames_seen := {}
	var max_speed := 0.0
	Input.action_press(&"move_left")
	for i in 40:
		await t.get_tree().physics_frame
		frames_seen[player.sprite.frame] = true
		max_speed = maxf(max_speed, player.velocity.length())
	Input.action_release(&"move_left")
	t.check(player.global_position.distance_to(start) > 40.0, "WASD moves the player")
	t.check(absf(max_speed - player.walk_speed) < 1.0, "keyboard speed unchanged (%.1f)" % max_speed)
	t.check(frames_seen.size() >= 3, "keyboard walking cycles through walk frames (%d seen)" % frames_seen.size())
	t.check(player.sprite.sprite_frames == Player.INDOOR_FRAMES, "still the indoor outfit")
	await _shutdown(main)


func test_tap_to_move_keeps_full_cycle() -> void:
	var main := await _boot_from_fixture()
	var player: Player = main.player
	await _travel(&"home")
	var spot: Vector2 = main.current_location.get_wander_spots()[0]
	var target: Vector2 = spot if spot.distance_to(player.global_position) > 80.0 else main.current_location.get_wander_spots()[-1]
	player.tap_at(target)
	var frames_seen := {}
	var max_speed := 0.0
	for i in 40:
		await t.get_tree().physics_frame
		frames_seen[player.sprite.frame] = true
		max_speed = maxf(max_speed, player.velocity.length())
	t.check(max_speed > DESIGN_STEP_SPEED * 2.0, "tap-to-move walks at walking speed (%.1f)" % max_speed)
	t.check(frames_seen.size() >= 3, "tap-to-move cycles through walk frames (%d seen)" % frames_seen.size())
	await _shutdown(main)


func test_continuous_wander_fallback() -> void:
	var main := await _boot_from_fixture()
	var player: Player = main.player
	await _travel(&"home")
	player.wander_style = WanderBrain.Style.CONTINUOUS
	player._wander.style = WanderBrain.Style.CONTINUOUS
	seed(99)
	player._wander.hold(0.2)
	var log := await _record(player, 10.0)
	var strides := _strides(log)
	t.check(strides.size() >= 1, "fallback still wanders")
	t.check(strides.any(func(s): return s.duration > DESIGN_STRIDE + 0.3), "fallback walks continuously (longest %.2f s)" % strides.reduce(func(m, s): return maxf(m, s.duration), 0.0))
	t.check(_max_speed(log) > DESIGN_STEP_SPEED * 2.0, "fallback uses the original 75 px/s (max %.1f)" % _max_speed(log))
	t.check(log.filter(func(e): return e.moving).any(func(e): return e.playing), "fallback plays the walk cycle")
	await _shutdown(main)


func test_customers_step_wander() -> void:
	var main := await _boot_from_fixture()
	var customers := _customers(main)
	if customers.is_empty():
		t.check(false, "no customers to observe")
		await _shutdown(main)
		return
	var c: Customer = customers[0]
	seed(7)
	c._wander.hold(0.2)
	main.player.wander_when_idle = false
	var log := await _record(c, 22.0)
	var strides := _strides(log)
	t.check(strides.size() >= 1, "customer took strides (%d)" % strides.size())
	for s in strides:
		t.check(s.duration <= DESIGN_STRIDE + 2.0 * s.dt, "customer stride lasts at most ~0.5 s (%.2f)" % s.duration)
	t.check(_max_speed(log) <= DESIGN_STEP_SPEED * 1.05, "customer wander speed <= 26 px/s (max %.1f)" % _max_speed(log))
	t.check(log.filter(func(e): return e.moving).all(func(e): return e.frame == 0 and not e.playing), "customer holds the first step frame")
	await _shutdown(main)


# --- Helpers --------------------------------------------------------------------

func _boot_from_fixture() -> Node:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE_V1), SaveSystem.save_path)
	var main: Node = load(MAIN_SCENE).instantiate()
	t.add_child(main)
	await _wait(0.8)
	return main


func _travel(id: StringName) -> void:
	if GameState.location_id != id:
		GameState.travel_to(GameData.get_location(id))
		await _wait(0.9)


## Samples a body every physics frame for `game_seconds` of (sped-up) game time.
func _record(body: Node2D, game_seconds: float) -> Array:
	var sprite: AnimatedSprite2D = body.sprite
	var log := []
	Engine.time_scale = TIME_SCALE
	var prev := body.global_position
	var elapsed := 0.0
	while elapsed < game_seconds:
		await t.get_tree().physics_frame
		var dt := Engine.time_scale / Engine.physics_ticks_per_second
		elapsed += dt
		var step := body.global_position.distance_to(prev)
		prev = body.global_position
		log.append({"dt": dt, "moving": step > 0.01, "speed": step / dt, "anim": sprite.animation,
			"frame": sprite.frame, "playing": sprite.is_playing()})
	Engine.time_scale = 1.0
	return log


## Groups consecutive moving samples into strides: {duration, start, dt}.
static func _strides(log: Array) -> Array:
	var out := []
	var time := 0.0
	var current = null
	for e in log:
		if e.moving:
			if current == null:
				current = {"start": time, "duration": 0.0, "dt": e.dt}
				out.append(current)
			current.duration += e.dt
		else:
			current = null
		time += e.dt
	return out


static func _min_gap(strides: Array) -> float:
	var gap := INF
	for i in range(1, strides.size()):
		gap = minf(gap, strides[i].start - (strides[i - 1].start + strides[i - 1].duration))
	return gap


static func _max_speed(log: Array) -> float:
	return log.reduce(func(m, e): return maxf(m, e.speed), 0.0)


static func _customers(main: Node) -> Array:
	return main.current_location.find_children("*", "Customer", true, false)


func _shutdown(main: Node) -> void:
	Engine.time_scale = 1.0
	main.queue_free()
	await t.get_tree().process_frame


func _wait(seconds: float) -> void:
	await t.get_tree().create_timer(seconds).timeout
