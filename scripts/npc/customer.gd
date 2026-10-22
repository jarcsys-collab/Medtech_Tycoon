class_name Customer
extends CharacterBody2D
## Café prospect. E to introduce yourself (becomes a lead), E again to close the deal in person.
## Bubble: "?" = not met yet, "$" = lead you can fulfil now, "..." = lead but not enough stock.

const TINT_SOFTEN := 0.7

@export var walk_speed := 60.0          # leaving, and CONTINUOUS wandering
## STEPS = short strides with pauses (Sales Simulator v3); CONTINUOUS = the original V1 wander.
@export var wander_style := WanderBrain.Style.STEPS
@export var wander_step_speed := 26.0

var lead_id := -1
var _wander: WanderBrain
var _leaving := false
var _exit := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var talk: Interactable = $Talk
@onready var bubble: Label = $Bubble


func _ready() -> void:
	add_to_group(&"actors")
	_wander = WanderBrain.new(agent, randf_range(2.0, 6.0))
	_wander.min_wait = 4.0
	_wander.max_wait = 10.0
	_wander.style = wander_style
	sprite.play(&"idle")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count(&"idle")
	talk.interacted.connect(_on_talk)
	GameState.leads_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)


func setup(prospect_id: int, spots: Array[Vector2], exit_point: Vector2) -> void:
	lead_id = prospect_id
	_exit = exit_point
	_wander.spots = spots
	var p := GameState.find_prospect(lead_id)
	if p.has("tint"):
		# Softened so tints read as "different person" without discolouring skin. The outdoor sheet's
		# white shirt shows tint strongly, so it is lighter than the V1 value (0.45).
		sprite.modulate = Color.html(p.tint).lerp(Color.WHITE, TINT_SOFTEN)
	_refresh()


func _process(_delta: float) -> void:
	# Gentle bob so the status bubble reads as "something to do here".
	bubble.position.y = -292.0 + sin(Time.get_ticks_msec() / 320.0 + lead_id) * 4.0


func _physics_process(delta: float) -> void:
	if _leaving:
		if agent.is_navigation_finished() or global_position.distance_to(_exit) < 12.0:
			_fade_out()
			return
		velocity = global_position.direction_to(agent.get_next_path_position()) * walk_speed * 1.4
	else:
		var speed := wander_step_speed if wander_style == WanderBrain.Style.STEPS else walk_speed
		velocity = _wander.get_velocity(self, delta, speed)
	var before := global_position
	move_and_slide()
	if not _leaving:
		_wander.report_motion(global_position.distance_to(before), velocity.length() * delta, delta)
	if absf(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0.0
	var walking := velocity.length() > 1.0
	var anim := &"walk" if walking else &"idle"
	if walking and not _leaving and wander_style == WanderBrain.Style.STEPS:
		# Sales Simulator v3: wandering holds the first step frame.
		if sprite.animation != anim or sprite.frame != 0 or sprite.is_playing():
			sprite.animation = anim
			sprite.frame = 0
			sprite.pause()
	elif sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	talk.enabled = false
	talk.set_highlighted(false)
	bubble.hide()
	agent.target_position = _exit


func _fade_out() -> void:
	if is_queued_for_deletion() or has_meta(&"fading"):
		return
	set_meta(&"fading", true)
	set_physics_process(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)


func _refresh() -> void:
	if _leaving or not is_inside_tree():
		return
	var p := GameState.find_prospect(lead_id)
	if p.is_empty() or p.get("sold", false):
		leave()
		return
	var old_text := bubble.text
	if not p.met:
		bubble.text = "?"
		bubble.modulate = Color("#e8c25a")
		talk.prompt = "Talk to %s" % p.name
	else:
		var lead := GameState.find_lead(lead_id)
		var can_sell := not lead.is_empty() and GameState.can_fulfil(lead)
		bubble.text = "$" if can_sell else "..."
		bubble.modulate = Color("#3dffc0") if can_sell else Color("#9fb0ad")
		talk.prompt = "Pitch %s" % p.name
	if bubble.text != old_text:
		bubble.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_talk(_player: Node) -> void:
	_wander.hold(6.0)
	var p := GameState.find_prospect(lead_id)
	if p.is_empty():
		return
	Tutorial.notify("sale_opened")
	var title := "%s · %s" % [p.name, p.business]
	if not p.met:
		UIEvents.ask(title,
			"Runs a [b]%s[/b] and is between meetings.\nIntroduce yourself to find out what they need?\n[color=#9fb0ad](takes %d min)[/color]"
				% [p.business, GameState.MEET_MINUTES],
			[UIEvents.option("Introduce yourself", _introduce, false, true), UIEvents.option("Not now")])
		return
	var lead := GameState.find_lead(lead_id)
	if lead.is_empty():
		leave()
		return
	var product := GameData.get_product(lead.product_id)
	var price := GameState.deal_price(lead, true)
	var have := GameState.stock_of(lead.product_id)
	var ok := GameState.can_fulfil(lead)
	var body := "Needs [b]%d× %s[/b]\nIn-person offer: [color=#e8c25a]$%s[/color] (+%d%% vs phone)\nYou have: %d in stock" % [
		int(lead.qty), product.display_name, GameState.format_money(price),
		roundi(GameState.IN_PERSON_BONUS * 100), have]
	if not ok:
		body += "\n[color=#e04a3c]Not enough stock. Restock at the Supplier Depot.[/color]"
	UIEvents.ask(title, body, [
		UIEvents.option("Close deal  $%s" % GameState.format_money(price), _close_deal, not ok, true),
		UIEvents.option("Not now"),
	])


func _introduce() -> void:
	GameState.meet_prospect(lead_id)
	_on_talk(null)


func _close_deal() -> void:
	if GameState.close_deal(lead_id, true):
		leave()
