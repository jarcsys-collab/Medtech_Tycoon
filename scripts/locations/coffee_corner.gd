extends LocationBase
## Coffee Corner: spawns today's café prospects as Customer NPCs.

const CUSTOMER_SCENE := preload("res://scenes/npc/customer.tscn")

@onready var customer_spots: Node2D = $CustomerSpots
@onready var exit_point: Marker2D = $ExitPoint


func _ready() -> void:
	super._ready()
	_spawn_customers()


func _spawn_customers() -> void:
	var seats := get_wander_spots("CustomerSpots")
	seats.shuffle()
	var i := 0
	for prospect in GameState.prospects:
		if prospect.get("sold", false) or i >= seats.size():
			continue
		var c: Customer = CUSTOMER_SCENE.instantiate()
		actors.add_child(c)
		c.global_position = seats[i]
		c.setup(int(prospect.id), get_wander_spots("CustomerSpots"), exit_point.global_position)
		i += 1
