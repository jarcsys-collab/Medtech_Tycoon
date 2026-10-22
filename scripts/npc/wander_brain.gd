class_name WanderBrain
extends RefCounted
## Idle wandering between spots using a NavigationAgent2D.
## Native replacement for Medtycoonv1's spots/via + clearPath wander AI. Used by Player and Customer.
##
## Style.STEPS (default, Sales Simulator v3): short strides with pauses. Each trip toward a spot is
## 1-2 strides of STEP_TIME at the step speed, a STEP_PAUSE between strides, then a rest before the
## next spot (whether or not it was reached). Style.CONTINUOUS is the original V1 behaviour: walk
## all the way to the spot, then rest min_wait..max_wait.

enum Style { STEPS, CONTINUOUS }

## Sales Simulator v3 values (godot/SalesSimulator/scripts/player.gd).
const STEP_TIME := 0.5
const STEP_PAUSE := Vector2(0.6, 1.5)
const STEP_REST := Vector2(2.5, 6.5)
const MAX_EXTRA_STRIDES := 1

var agent: NavigationAgent2D
var spots: Array[Vector2] = []
var style := Style.STEPS
## Multiplies step speed and divides stride time, so each stride covers the same distance.
var step_rate := 1.0
var min_wait := 2.5
var max_wait := 7.0
var min_hop := 60.0
var walking := false

var _wait := 0.0
var _stuck := 0.0
var _stride_left := 0.0      ## STEPS: seconds left in the current stride (0 = pausing)
var _strides_left := 0        ## STEPS: strides still to take after the current one


func _init(nav_agent: NavigationAgent2D, first_wait := 2.5) -> void:
	agent = nav_agent
	_wait = first_wait


func hold(seconds: float) -> void:
	walking = false
	_wait = seconds
	_stride_left = 0.0
	_strides_left = 0


func go_to(point: Vector2) -> void:
	agent.target_position = point
	walking = true
	_stuck = 0.0
	if style == Style.STEPS:
		_stride_left = STEP_TIME / step_rate
		_strides_left = randi_range(0, MAX_EXTRA_STRIDES)


## Returns the velocity the body should move with this frame. In STEPS style `speed` is the step
## speed (before step_rate); in CONTINUOUS style it is the walking speed.
func get_velocity(body: Node2D, delta: float, speed: float) -> Vector2:
	if not walking:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target(body.global_position)
		return Vector2.ZERO
	if agent.is_navigation_finished():
		hold(_rest_time())
		return Vector2.ZERO
	if style == Style.STEPS:
		if _stride_left <= 0.0:
			# Pausing between strides.
			_wait -= delta
			if _wait <= 0.0:
				_stride_left = STEP_TIME / step_rate
			return Vector2.ZERO
		_stride_left -= delta
		if _stride_left <= 0.0:
			_stride_left = 0.0
			if _strides_left <= 0:
				hold(randf_range(STEP_REST.x, STEP_REST.y))
				return Vector2.ZERO
			_strides_left -= 1
			_wait = randf_range(STEP_PAUSE.x, STEP_PAUSE.y)
		speed *= step_rate
	var next := agent.get_next_path_position()
	return body.global_position.direction_to(next) * speed


## Call after move_and_slide so a blocked walker gives up instead of grinding into a wall.
func report_motion(moved: float, expected: float, delta: float) -> void:
	if not walking or expected <= 0.0:
		return
	if moved < expected * 0.2:
		_stuck += delta
		if _stuck > 0.8:
			hold(1.0)
	else:
		_stuck = 0.0


func _rest_time() -> float:
	return randf_range(STEP_REST.x, STEP_REST.y) if style == Style.STEPS else randf_range(min_wait, max_wait)


func _pick_target(from: Vector2) -> void:
	var options := spots.filter(func(p: Vector2): return p.distance_to(from) > min_hop)
	if options.is_empty():
		hold(min_wait)
		return
	go_to(options.pick_random())
