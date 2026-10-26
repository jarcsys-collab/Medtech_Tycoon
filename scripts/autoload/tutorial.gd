extends Node
## In-game player tutorial (Medtycoonv2): guided steps through day 1. Replaces the Medtycoonv1 tip carousel.
## Each step waits for ONE event; game code reports events with notify("<event>").
## Progress lives in GameState (tutorial_step / tutorial_done), so it is saved and loaded with the game.
##
## Step keys:
##   title, body  -> tutorial card (keep body <= 90 chars)
##   hint, sub    -> hint line under the body (tap-first wording)
##   hint_keys    -> optional hint shown instead on keyboard devices (desktop shortcuts)
##   wait         -> event that completes the step ("click" = player clicks the card)
##   also         -> optional second event that also completes the step
##   highlight    -> side-nav id ("phone", "travel", "inventory") or "phone:<row>" to pulse
##
## Steps follow Medtycoonv2 autoload/tutorial.gd. Where V2 refers to systems this game does not have
## (meeting booking, pitch/offer dialog, online ordering) the step is reworded to the existing equivalent.

signal step_changed(step: Dictionary)
## Presentation hook (audio): a step was completed; `final` = the whole tutorial is finished.
signal step_completed(final: bool)

const STEPS := [
	{"id": "welcome", "title": "Start at Home", "body": "You sell medical diagnostics. Tap here to begin your first day.",
		"hint": "Tap to continue", "hint_keys": "Click to continue", "sub": "The arrow means this box is waiting for you.", "wait": "click"},
	{"id": "move", "title": "Move Around", "body": "Tap the floor to walk around your apartment.",
		"hint": "Tap to walk", "hint_keys": "Click to walk, or WASD / Arrows", "sub": "He wanders on his own when you let go.", "wait": "moved"},
	{"id": "phone", "title": "Check Your Phone", "body": "Tap PHONE. It's your sales hub.",
		"hint": "Phone = Main Navigation", "hint_keys": "Phone = Main Navigation (P)", "sub": "Manage your sales activities from your phone.", "wait": "phone_opened", "highlight": "phone"},
	{"id": "leads", "title": "Open Leads", "body": "Tap Leads to see who is ready to buy today.",
		"hint": "Leads", "sub": "Call & close a lead when you have the stock.", "wait": "leads_opened", "highlight": "phone:leads"},
	{"id": "clients", "title": "Find New Clients", "body": "More clients wait at Coffee Corner. Customers marked ? are new prospects.",
		"hint": "Meet clients in person", "sub": "In-person deals pay 15% more.", "wait": "click"},
	{"id": "travel", "title": "Travel", "body": "Tap TRAVEL, pick Coffee Corner, then tap TRAVEL.",
		"hint": "Trips cost time + fare", "hint_keys": "Trips cost time + fare (M opens the map)", "sub": "Locked pins open as you level up.", "wait": "arrived_coffee", "highlight": "travel"},
	{"id": "talk", "title": "Meet the Client", "body": "Tap a customer marked ?, then tap the action button.",
		"hint": "Tap, then the button", "hint_keys": "Click, then the button (or E)", "sub": "The button shows what you can do.", "wait": "sale_opened"},
	{"id": "sell", "title": "Close the Deal", "body": "Introduce yourself, then use the button again and close the deal.",
		"hint": "$ = Ready to buy", "sub": "You can also close leads by phone.", "wait": "sale_won"},
	{"id": "inventory", "title": "Check Stock", "body": "Each sale uses stock. Open INVENTORY to see what is left.",
		"hint": "Inventory", "sub": "No stock, no sale.", "wait": "inventory_opened", "highlight": "inventory"},
	{"id": "restock", "title": "Restock", "body": "Buy stock from a shelf at the Supplier Depot. It opens at Level 2.",
		"hint": "Wholesale restocks", "sub": "Tap here to continue, or restock now.", "wait": "click", "also": "restocked"},
	{"id": "home", "title": "Head Home", "body": "Close the panel, open TRAVEL and go back Home.",
		"hint": "Rest to end the day", "sub": "You can only sleep at home.", "wait": "arrived_home", "highlight": "travel"},
	{"id": "sleep", "title": "End the Day", "body": "Tap your bed, then Sleep. The game saves automatically.",
		"hint": "Bed = End Day", "sub": "New leads arrive overnight.", "wait": "day_ended"},
	{"id": "done", "title": "You're Ready", "body": "Find leads, sell smart, level up to unlock the city. Good luck!",
		"hint": "Tap to finish", "hint_keys": "Click to finish", "sub": "Replay the tutorial any time from TO-DO.", "wait": "click"},
]

var _overlay: StringName = &""
var _phone_page: StringName = &""


func _ready() -> void:
	GameState.state_reset.connect(_on_state_reset)
	GameState.location_changed.connect(func(id: StringName): notify("arrived_" + String(id)))
	GameState.deal_closed.connect(func(_amount: int, _in_person: bool): notify("sale_won"))
	GameState.stock_purchased.connect(func(_product_id: String, _qty: int): notify("restocked"))
	GameState.day_ended.connect(func(_day: int): notify("day_ended"))


func is_active() -> bool:
	return not GameState.tutorial_done


func current() -> Dictionary:
	return {} if GameState.tutorial_done else STEPS[clampi(GameState.tutorial_step, 0, STEPS.size() - 1)]


func highlight() -> String:
	return str(current().get("highlight", ""))


func index_label() -> String:
	return "%d/%d" % [clampi(GameState.tutorial_step, 0, STEPS.size() - 1) + 1, STEPS.size()]


## Report a tutorial-relevant event. Completes the current step if it is waiting for it.
func notify(event: String) -> void:
	var s := current()
	if not s.is_empty() and (s.wait == event or s.get("also", "") == event):
		advance()


func advance() -> void:
	GameState.tutorial_step += 1
	if GameState.tutorial_step >= STEPS.size():
		GameState.tutorial_done = true
		step_completed.emit(true)
		step_changed.emit({})
		return
	step_completed.emit(false)
	step_changed.emit(current())
	if _already_done(current().wait):
		advance()


func skip() -> void:
	GameState.tutorial_done = true
	step_changed.emit({})


func restart() -> void:
	GameState.tutorial_done = false
	GameState.tutorial_step = 0
	step_changed.emit(current())


# --- Events reported by Main ----------------------------------------------------

func on_overlay_changed(active: StringName) -> void:
	_overlay = active
	if active != &"phone":
		_phone_page = &""
	match active:
		&"phone": notify("phone_opened")
		&"inventory": notify("inventory_opened")


func on_phone_page(page: StringName) -> void:
	_phone_page = page
	if page == &"leads":
		notify("leads_opened")


## A step whose condition already holds when it starts completes on its own
## (e.g. the phone is already open, or the player is already at the café).
func _already_done(wait: String) -> bool:
	if wait.begins_with("arrived_"):
		return String(GameState.location_id) == wait.trim_prefix("arrived_")
	match wait:
		"phone_opened": return _overlay == &"phone"
		"leads_opened": return _overlay == &"phone" and _phone_page == &"leads"
		"inventory_opened": return _overlay == &"inventory"
	return false


func _on_state_reset() -> void:
	step_changed.emit(current())
