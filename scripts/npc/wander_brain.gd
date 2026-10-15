class_name WanderBrain
extends RefCounted
## Idle wandering between spots using a NavigationAgent2D.
## Native replacement for Medtycoonv1's spots/via + clearPath wander AI. Used by Player and Customer.

var agent: NavigationAgent2D
var spots: Array[Vector2] = []
var min_wait := 2.5
var max_wait := 7.0
var min_hop := 60.0
var walking := false

var _wait := 0.0
var _stuck := 0.0


func _init(nav_agent: NavigationAgent2D, first_wait := 2.5) -> void:
	agent = nav_agent
	_wait = first_wait


func hold(seconds: float) -> void:
	walking = false
	_wait = seconds


func go_to(point: Vector2) -> void:
	agent.target_position = point
	walking = true
	_stuck = 0.0


## Returns the velocity the body should move with this frame.
func get_velocity(body: Node2D, delta: float, speed: float) -> Vector2:
	if not walking:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target(body.global_position)
		return Vector2.ZERO
	if agent.is_navigation_finished():
		hold(randf_range(min_wait, max_wait))
		return Vector2.ZERO
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


func _pick_target(from: Vector2) -> void:
	var options := spots.filter(func(p: Vector2): return p.distance_to(from) > min_hop)
	if options.is_empty():
		hold(min_wait)
		return
	go_to(options.pick_random())
