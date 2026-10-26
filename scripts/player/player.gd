class_name Player
extends CharacterBody2D
## Top-down player. Tap-first (Sales Simulator handoff): tap the floor to walk there, tap a person
## or object to walk up and select it, then use the HUD's action button. Optional on desktop:
## WASD/arrows to walk and E to use. Idle auto-wander (Medtycoonv1 "wander").

signal interactable_changed(target: Interactable)
## Medtycoonv2: fires each time the player has walked MOVED_EVENT_DISTANCE px with the keys (tutorial "moved").
signal moved_enough

const MOVED_EVENT_DISTANCE := 120.0
## Tap/click-to-move (touch screens): how close (world px) a tap must land to an object's
## feet-to-badge line to count as "use this", and when a blocked walk gives up.
const TAP_PICK_RADIUS := 90.0
const TAP_STUCK_SECONDS := 0.8
## Outfits: indoor sheet at home, outdoor sheet everywhere else (Sales Simulator v3). Same frame
## height and feet line, so the sprite offset is shared.
const INDOOR_FRAMES := preload("res://assets/characters/char_frames.tres")
const OUTDOOR_FRAMES := preload("res://assets/characters/char_out_frames.tres")

@export var walk_speed := 110.0          # Medtycoonv1: sp = 110 px/s
@export var wander_when_idle := true
@export var idle_before_wander := 4.0    # Medtycoonv1: ai.until = now + 4000
## STEPS = short strides with pauses (Sales Simulator v3); CONTINUOUS = the original V1 wander.
@export var wander_style := WanderBrain.Style.STEPS
@export var wander_step_speed := 26.0    # Sales Simulator v3: WANDER_SPEED := 26.0
## Sales Simulator v3 "wanderSpeed" (0.5-2.5x): faster strides, same stride length.
@export_range(0.5, 2.5, 0.1) var wander_step_rate := 1.0
@export var wander_speed := 75.0         # CONTINUOUS only. Medtycoonv1: wander sp = 75 px/s

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interaction_area: Area2D = $InteractionArea
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var marker: PlayerMarker = $Marker

var input_enabled := true:
	set(value):
		input_enabled = value
		if not value:
			velocity = Vector2.ZERO

var _wander: WanderBrain
var _focus: Interactable
var _keyed_distance := 0.0
var _tap_active := false
var _tap_target: Interactable
var _tap_stuck := 0.0
## Tapped object, kept as the focus while it is in reach (the action button acts on it).
var _selected: Interactable
## Object told to wait for the player (customers): the tap target, then the selection.
var _engaged: Interactable


func _ready() -> void:
	add_to_group(&"actors")
	_wander = WanderBrain.new(nav_agent, idle_before_wander)
	_wander.style = wander_style
	_wander.step_rate = wander_step_rate
	sprite.play(&"idle")


## Outdoor outfit everywhere except home. Keeps the current animation and facing.
func set_outdoor(outdoor: bool) -> void:
	var frames := OUTDOOR_FRAMES if outdoor else INDOOR_FRAMES
	if sprite.sprite_frames == frames:
		return
	var anim := sprite.animation
	sprite.sprite_frames = frames
	sprite.play(anim)


## Called by a location when the player is placed in it. (Framing is handled by Main's GameCamera.)
func enter_location(spots: Array[Vector2]) -> void:
	_wander.spots = spots
	_wander.hold(idle_before_wander)
	velocity = Vector2.ZERO
	z_index = 0  # a DepthOverlay in the previous location may have raised it
	_cancel_tap()
	_set_focus(null)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var keyed := input != Vector2.ZERO
	if keyed or not input_enabled:
		_cancel_tap()
	if keyed:
		_selected = null
	if keyed:
		velocity = input.normalized() * walk_speed
		_wander.hold(idle_before_wander)
	elif _tap_active:
		velocity = _tap_velocity()
		_wander.hold(idle_before_wander)
	elif wander_when_idle and input_enabled and _selected == null:
		# A tapped object keeps the player beside it until it is used or something else is tapped.
		var speed := wander_step_speed if wander_style == WanderBrain.Style.STEPS else wander_speed
		velocity = _wander.get_velocity(self, delta, speed)
	else:
		velocity = Vector2.ZERO

	var before := global_position
	move_and_slide()
	_wander.report_motion(global_position.distance_to(before), velocity.length() * delta, delta)
	if _tap_active:
		_tap_report_motion(global_position.distance_to(before), velocity.length() * delta, delta)
		keyed = true  # walk at the keyed pace/animation while following a tap
	if keyed:
		_keyed_distance += global_position.distance_to(before)
		if _keyed_distance > MOVED_EVENT_DISTANCE:
			_keyed_distance = 0.0
			moved_enough.emit()
	_update_animation(keyed)
	_update_focus()
	_update_engaged()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed(&"interact") and _focus != null:
		get_viewport().set_input_as_handled()
		_use(_focus)
	# Tap/click on the world (touch is delivered as an emulated left click). GUI controls get the
	# event first, so this only fires for taps that land on the room itself.
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		tap_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)


func _use(target: Interactable) -> void:
	_cancel_tap()
	# Talking to a customer (button or E) selects them, so they wait through the conversation.
	if target.get_parent().has_method(&"wait_for_player"):
		_selected = target
	_wander.hold(idle_before_wander)
	_bounce()
	target.interact(self)


# --- Tap / click to move ----------------------------------------------------------

## Walk to a world point. If the tap lands on an object (customer, shelf, bed), walk up to it and
## select it: the HUD then shows its action button (the handoff's "tap a person, then the action").
func tap_at(point: Vector2) -> void:
	_selected = null
	_tap_target = _pick_interactable(point)
	_tap_active = true
	_tap_stuck = 0.0
	nav_agent.target_position = _tap_target.global_position if _tap_target else point


func _cancel_tap() -> void:
	_tap_active = false
	_tap_target = null


func _tap_velocity() -> Vector2:
	if _tap_target and (not is_instance_valid(_tap_target) or not _tap_target.can_interact()):
		_cancel_tap()
		return Vector2.ZERO
	if _tap_target:
		if _tap_in_reach():
			_select_tapped()
			return Vector2.ZERO
		# Customers move: keep the path pointed at them (re-path only after they drift a bit).
		if nav_agent.target_position.distance_to(_tap_target.global_position) > 16.0:
			nav_agent.target_position = _tap_target.global_position
	if nav_agent.is_navigation_finished():
		_tap_arrived()
		return Vector2.ZERO
	return global_position.direction_to(nav_agent.get_next_path_position()) * walk_speed


func _tap_report_motion(moved: float, expected: float, delta: float) -> void:
	if expected <= 0.0:
		return
	_tap_stuck = _tap_stuck + delta if moved < expected * 0.2 else 0.0
	if _tap_stuck > TAP_STUCK_SECONDS:
		_tap_arrived()


func _tap_arrived() -> void:
	if _tap_target and _tap_in_reach():
		_select_tapped()
	else:
		_cancel_tap()


func _select_tapped() -> void:
	_selected = _tap_target
	_cancel_tap()
	_wander.hold(idle_before_wander)


## A tapped or selected customer waits for the player (no timeout) instead of wandering out of
## reach; it is released when the player taps elsewhere, walks off with the keys, or it leaves.
func _update_engaged() -> void:
	var want: Interactable = _tap_target if is_instance_valid(_tap_target) else _selected
	if not is_instance_valid(want):
		want = null
	if not is_instance_valid(_engaged):
		_engaged = null
	if want == _engaged:
		return
	if _engaged and _engaged.get_parent().has_method(&"wait_for_player"):
		_engaged.get_parent().wait_for_player(false)
	_engaged = want
	if _engaged and _engaged.get_parent().has_method(&"wait_for_player"):
		_engaged.get_parent().wait_for_player(true)


func _tap_in_reach() -> bool:
	return is_instance_valid(_tap_target) and interaction_area.get_overlapping_areas().has(_tap_target)


## The usable object closest to the tap: measured to its reach area (e.g. the whole bed or shelf
## front) and to its body line (feet up to the floating [E] badge, e.g. a standing customer).
func _pick_interactable(point: Vector2) -> Interactable:
	var location := get_parent()
	while location and not location is LocationBase:
		location = location.get_parent()
	if location == null:
		return null
	var best: Interactable = null
	var best_d := TAP_PICK_RADIUS
	for node in location.find_children("*", "Interactable", true, false):
		var it := node as Interactable
		if it == null or not it.can_interact():
			continue
		var feet := it.global_position
		var d := point.distance_to(Geometry2D.get_closest_point_to_segment(point, feet, it.get_marker_position()))
		d = minf(d, _distance_to_reach(it, point))
		# A tap on the visible object (e.g. the bed's pillow) always picks it over near-misses; where
		# artwork overlaps, the object whose tap line / reach is closest to the tap wins.
		if it.is_on_artwork(point):
			d -= TAP_PICK_RADIUS
		if d < best_d:
			best_d = d
			best = it
	return best


## Distance from a world point to an Interactable's reach shapes (0 when inside).
static func _distance_to_reach(it: Interactable, point: Vector2) -> float:
	var best := INF
	for child in it.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var local := cs.global_transform.affine_inverse() * point
		if cs.shape is RectangleShape2D:
			var half: Vector2 = cs.shape.size / 2.0
			best = minf(best, Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0)).length())
		elif cs.shape is CircleShape2D:
			best = minf(best, maxf(local.length() - cs.shape.radius, 0.0))
	return best


func _update_animation(keyed: bool) -> void:
	var walking := velocity.length() > 1.0
	if absf(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0.0
	var anim := &"walk" if walking else &"idle"
	if walking and not keyed and wander_style == WanderBrain.Style.STEPS:
		# Sales Simulator v3: idle wandering holds the first step frame; keys and taps keep the cycle.
		if sprite.animation != anim or sprite.frame != 0 or sprite.is_playing():
			sprite.animation = anim
			sprite.frame = 0
			sprite.pause()
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
	# Medtycoonv1: 11 fps when keyed, 8 fps when auto-walking.
	sprite.speed_scale = 8.0 / 11.0 if (walking and not keyed) else 1.0


func _update_focus() -> void:
	var best: Interactable = null
	var best_d := INF
	var in_reach := interaction_area.get_overlapping_areas()
	if not (is_instance_valid(_selected) and _selected.can_interact() and in_reach.has(_selected)):
		_selected = null
	if input_enabled and _selected:
		best = _selected
	elif input_enabled:
		for area in in_reach:
			if area is Interactable and area.can_interact():
				var d := global_position.distance_squared_to(area.global_position)
				if d < best_d:
					best_d = d
					best = area
	_set_focus(best)


func _set_focus(target: Interactable) -> void:
	if target == _focus:
		return
	if is_instance_valid(_focus):
		_focus.set_highlighted(false)
	_focus = target
	if _focus:
		_focus.set_highlighted(true)
	# The [E] badge and customer bubbles use the space above heads while something is in reach.
	marker.suppressed = _focus != null
	interactable_changed.emit(target)


## Small squash on interact so the key press feels acknowledged.
func _bounce() -> void:
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.06)
	t.tween_property(sprite, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func current_focus() -> Interactable:
	return _focus
