extends LocationBase
## Coffee Corner: spawns today's café prospects as Customer NPCs, plus background patrons whose
## number and pace follow the time of day (GameState.CROWD, G2a). Patrons are ambience only: no
## bubble, no interaction, never a sale. The crowd updates live at 12:30 PM / 4:30 PM.

const CUSTOMER_SCENE := preload("res://scenes/npc/customer.tscn")
## Morning commuters stay this long (seconds), then the next one walks in.
const COMMUTER_STAY := Vector2(30.0, 45.0)
const COMMUTER_GAP := 3.0

@onready var customer_spots: Node2D = $CustomerSpots
@onready var exit_point: Marker2D = $ExitPoint


func _ready() -> void:
	super._ready()
	_spawn_customers()
	_spawn_patrons(false)
	_apply_pace()
	GameState.time_slot_changed.connect(_on_time_slot_changed)


func prospect_customers() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in actors.get_children():
		if c is Customer and not c.patron and not c.is_queued_for_deletion():
			out.append(c)
	return out


func patrons() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in actors.get_children():
		if c is Customer and c.patron and not c.is_queued_for_deletion() and not c.is_leaving():
			out.append(c)
	return out


func _spawn_customers() -> void:
	var seats := get_wander_spots("CustomerSpots")
	seats.shuffle()
	var i := 0
	for prospect in GameState.prospects:
		if prospect.get("sold", false) or i >= seats.size():
			continue
		_add_prospect(int(prospect.id), seats[i])
		i += 1


func _add_prospect(id: int, at: Vector2) -> void:
	var c: Customer = CUSTOMER_SCENE.instantiate()
	actors.add_child(c)
	c.global_position = at
	c.setup(id, get_wander_spots("CustomerSpots"), exit_point.global_position)
	c.set_pace(GameState.crowd().rest)


## Fill up to the slot's patron count, on free seats (the café has one seat per guest).
## `arriving` = walk in by the door instead of already sitting.
func _spawn_patrons(arriving: bool) -> void:
	var seats := get_wander_spots("CustomerSpots")
	var want := mini(int(GameState.crowd().patrons), seats.size() - prospect_customers().size())
	seats.shuffle()
	for i in maxi(0, want - patrons().size()):
		var c: Customer = CUSTOMER_SCENE.instantiate()
		actors.add_child(c)
		c.global_position = exit_point.global_position if arriving else seats[i]
		var stay := randf_range(COMMUTER_STAY.x, COMMUTER_STAY.y) if GameState.crowd().commuters else 0.0
		c.setup_patron(get_wander_spots("CustomerSpots"), exit_point.global_position, stay)
		c.set_pace(GameState.crowd().rest)
		if stay > 0.0:
			c.tree_exited.connect(_on_commuter_left)


## A commuter left: after a short gap, top the crowd back up to what the current slot wants.
func _on_commuter_left() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		get_tree().create_timer(COMMUTER_GAP).timeout.connect(_refill)


func _refill() -> void:
	if is_inside_tree():
		_spawn_patrons(true)


func _apply_pace() -> void:
	for c in actors.get_children():
		if c is Customer:
			c.set_pace(GameState.crowd().rest)


func _on_time_slot_changed(_slot: StringName, _announce: bool) -> void:
	_apply_pace()
	var extra := patrons().size() - int(GameState.crowd().patrons)
	for c in patrons():
		if extra <= 0:
			break
		c.leave()
		extra -= 1
	_spawn_patrons(true)
