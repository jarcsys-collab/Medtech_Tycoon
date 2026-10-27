extends Node
## Runtime game state and the rules that change it.
## World and UI never mutate these fields directly; they call the methods below and listen to signals.

signal stats_changed        ## cash, reputation, xp, level, day, time
signal inventory_changed
signal leads_changed        ## leads and café prospects
signal deals_changed        ## closed deals / customers
signal tasks_changed
signal location_changed(location_id: StringName)
signal level_up(new_level: int)
signal state_reset          ## new game or load: everything should refresh
# Presentation-only deltas (floating "+$" / "+XP" feedback). No game logic listens to these.
signal cash_delta(amount: int)
signal xp_gained(amount: int)
signal reputation_delta(amount: int)
# Presentation-only event hooks (audio). Emitted at existing moments; no logic depends on them.
signal day_ended(new_day: int)
## The day is over (8:30 PM, or the player went to bed): show the end-of-day summary. Nothing
## advances until start_next_day() is called. Emitted once per day.
signal day_finished(summary: Dictionary)
signal leads_added(count: int)
signal stock_purchased(product_id: String, qty: int)
signal deal_closed(amount: int, in_person: bool)
signal task_completed(task_id: String)
## Morning -> afternoon -> evening as the clock advances (G2a); also on a new day / load.
## `announce` is true only when the clock passed a boundary during play (shows a notice).
signal time_slot_changed(slot: StringName, announce: bool)

const START_CASH := 10000          # Medtycoonv1: cash: 10000
const START_MINUTES := 8 * 60 + 30 # Medtycoonv1: minutes: 510 (08:30 AM)
## The working day ends at 8:30 PM (Sales Simulator handoff: DAY = { start: 510, end: 1230 }).
const DAY_END_MINUTES := 20 * 60 + 30
## A heads-up toast half an hour before the day ends.
const LATE_MINUTES := 20 * 60
## Time-of-day boundaries (Sales Simulator v3 slots). Derived from `minutes`; not saved.
const AFTERNOON_START := 12 * 60 + 30   # 12:30 PM
const EVENING_START := 16 * 60 + 30     # 4:30 PM
## Café ambience by time of day (G2a). patrons = background guests: visual only, nothing to sell,
## never prospects; rest = customers' pause length (x the step-wander rest). Sales are unaffected.
const CROWD := {
	&"morning": {"patrons": 1, "rest": 0.6, "commuters": true},
	&"afternoon": {"patrons": 2, "rest": 1.0, "commuters": false},
	&"evening": {"patrons": 0, "rest": 1.8, "commuters": false},
}
const STARTING_LEADS := 5          # Medtycoonv1 HUD: LEADS 5
const DAILY_NEW_LEADS := 2
const CAFE_PROSPECTS := 3

# Minutes each action takes.
const MEET_MINUTES := 10
const DEAL_IN_PERSON_MINUTES := 15
const DEAL_PHONE_MINUTES := 25
const RESTOCK_MINUTES := 5

const IN_PERSON_BONUS := 0.15
## Chance a new lead asks for a product you currently stock.
const LEAD_STOCK_BIAS := 0.75
## Save-format version of tutorial_step (2 = Medtycoonv2 guided steps, see Tutorial autoload).
const TUTORIAL_VERSION := 2

var day := 1
var minutes := START_MINUTES
var cash := START_CASH
var reputation := 0          ## 0..100 (%)
var xp := 0
var level := 1
var location_id: StringName = &"home"
var inventory := {}          ## product id (String) -> units
var leads: Array = []        ## Array[Dictionary] (see _make_lead)
var prospects: Array = []    ## café NPCs for today, same shape as leads + "met"
var customers: Array = []    ## account names
var deals: Array = []        ## { day, customer, product_id, qty, amount, in_person }
var revenue_total := 0
var expenses_total := 0
var completed_tasks := {}    ## task id -> true
var tutorial_step := 0      ## index into Tutorial.STEPS
var tutorial_done := false
var _next_id := 1
## True from the end of the day until the next morning starts; guards against advancing twice.
## Not saved: a save made at 8:30 PM reopens the summary when loaded (see from_dict).
var day_closing := false
## Why the day ended: &"time" (8:30 PM) or &"sleep" (the bed).
var day_end_reason: StringName = &""


func _ready() -> void:
	new_game()


# --- Lifecycle -----------------------------------------------------------------

func new_game() -> void:
	day_closing = false
	day = 1
	minutes = START_MINUTES
	cash = START_CASH
	reputation = 0
	xp = 0
	level = 1
	location_id = &"home"
	inventory = GameData.STARTING_INVENTORY.duplicate()
	customers = GameData.STARTING_CUSTOMERS.duplicate()
	deals = []
	revenue_total = 0
	expenses_total = 0
	completed_tasks = {}
	tutorial_step = 0
	tutorial_done = false
	_next_id = 1
	leads = []
	for i in STARTING_LEADS:
		leads.append(_make_lead("phone"))
	_roll_prospects()
	_emit_all()


## Go to bed and wake up tomorrow in one step (no summary in between).
func sleep() -> void:
	end_day(&"sleep")
	start_next_day()


## Ends today: the bed (&"sleep") or the 8:30 PM clock (&"time"). Opens the end-of-day summary;
## the new day starts only from start_next_day(). Calling it again the same day does nothing.
func end_day(reason: StringName = &"sleep") -> void:
	if day_closing or (reason == &"time" and not is_day_over()):
		return
	day_closing = true
	day_end_reason = reason
	if reason == &"sleep":
		complete_task("sleep")
	day_finished.emit(day_summary())


## Next morning: day + 1 at 8:30 AM at home, overnight leads and today's café prospects, autosave.
## Only after end_day(); returns false (and changes nothing) otherwise, so it cannot run twice.
func start_next_day() -> bool:
	if not day_closing:
		return false
	day_closing = false
	day += 1
	day_ended.emit(day)
	minutes = START_MINUTES
	location_id = &"home"
	for i in DAILY_NEW_LEADS:
		leads.append(_make_lead("phone"))
	leads_added.emit(DAILY_NEW_LEADS)
	_roll_prospects()
	UIEvents.toast("Day %d begins. +%d new leads" % [day, DAILY_NEW_LEADS])
	_emit_all()
	time_slot_changed.emit(time_slot(), false)
	SaveSystem.save_game()
	return true


## Today's results for the end-of-day summary. Built from saved state only (deals are stamped
## with their day; prospects are today's café guests), so it is the same after a reload.
func day_summary() -> Dictionary:
	var count := 0
	var sales := 0
	var units := 0
	for d in deals:
		if int(d.day) == day:
			count += 1
			sales += int(d.amount)
			units += int(d.qty)
	return {
		"day": day, "date": date_label(), "reason": day_end_reason, "time": time_label(),
		"deals": count, "sales": sales, "units": units,
		"met": prospects.filter(func(p: Dictionary): return p.get("met", false)).size(),
		"cash": cash, "level": level, "reputation": reputation, "leads": leads.size(),
		"new_leads": DAILY_NEW_LEADS,
	}


# --- Time ----------------------------------------------------------------------

## The clock stops at 8:30 PM; reaching it ends the day once the current action has finished
## (deferred, so a deal's XP and reputation are in before the summary opens).
func advance_time(mins: int) -> void:
	var was_late := minutes >= LATE_MINUTES
	var old_slot := time_slot()
	minutes = mini(minutes + mins, maxi(minutes, DAY_END_MINUTES))
	if not was_late and minutes >= LATE_MINUTES and not is_day_over():
		UIEvents.toast("The day ends at 08:30 PM.")
	var slot := time_slot()
	stats_changed.emit()
	if slot != old_slot:
		time_slot_changed.emit(slot, true)
	if is_day_over():
		end_day.call_deferred(&"time")


func is_day_over() -> bool:
	return minutes >= DAY_END_MINUTES


func time_label() -> String:
	var h := floori(minutes / 60.0) % 24
	var h12 := ((h + 11) % 12) + 1
	return "%02d:%02d %s" % [h12, minutes % 60, "AM" if h < 12 else "PM"]


## &"morning" before 12:30 PM, &"afternoon" until 4:30 PM, &"evening" after.
func time_slot() -> StringName:
	if minutes >= EVENING_START:
		return &"evening"
	if minutes >= AFTERNOON_START:
		return &"afternoon"
	return &"morning"


func is_evening() -> bool:
	return time_slot() == &"evening"


func crowd() -> Dictionary:
	return CROWD[time_slot()]


func date_label() -> String:
	# Day 1 = Mon, Apr 1 (Medtycoonv1 HUD).
	const WEEKDAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	const MONTHS := ["Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar"]
	const MONTH_DAYS := [30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 28, 31]
	var d := day - 1
	var m := 0
	while d >= MONTH_DAYS[m % 12]:
		d -= MONTH_DAYS[m % 12]
		m += 1
	return "%s, %s %d" % [WEEKDAYS[(day - 1) % 7], MONTHS[m % 12], d + 1]


# --- Money / progression -------------------------------------------------------

func add_cash(amount: int) -> void:
	cash += amount
	if amount > 0:
		revenue_total += amount
	else:
		expenses_total -= amount
	cash_delta.emit(amount)
	stats_changed.emit()


func add_reputation(amount: int) -> void:
	var before := reputation
	reputation = clampi(reputation + amount, 0, 100)
	if reputation != before:
		reputation_delta.emit(reputation - before)
	stats_changed.emit()


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	xp_gained.emit(amount)
	var new_level := GameData.level_for_xp(xp)
	if new_level > level:
		level = new_level
		level_up.emit(level)
		UIEvents.toast("LEVEL %d! New places and products unlocked." % level)
		if level >= 2:
			complete_task("reach_lv2")
	stats_changed.emit()


func xp_progress() -> Vector2i:
	## x = xp into current level, y = xp needed for next level (0 at max level).
	var table := GameData.LEVEL_XP
	if level >= table.size():
		return Vector2i(xp - table[-1], 0)
	return Vector2i(xp - table[level - 1], table[level] - table[level - 1])


# --- Inventory -----------------------------------------------------------------

func stock_of(product_id: Variant) -> int:
	return int(inventory.get(String(product_id), 0))


func add_stock(product_id: Variant, qty: int) -> void:
	var key := String(product_id)
	inventory[key] = maxi(0, stock_of(key) + qty)
	if inventory[key] == 0:
		inventory.erase(key)
	inventory_changed.emit()


func buy_stock(product: ProductData, qty: int) -> bool:
	if product.unlock_level > level:
		UIEvents.toast("Requires Level %d" % product.unlock_level)
		return false
	var cost := product.wholesale_cost * qty
	if cost > cash:
		UIEvents.toast("Not enough cash ($%s needed)" % format_money(cost))
		return false
	add_cash(-cost)
	add_stock(product.id, qty)
	advance_time(RESTOCK_MINUTES)
	stock_purchased.emit(String(product.id), qty)
	complete_task("restock")
	UIEvents.toast("Bought %d× %s  (-$%s)" % [qty, product.display_name, format_money(cost)])
	return true


# --- Leads, prospects, deals ---------------------------------------------------

func find_lead(lead_id: int) -> Dictionary:
	for l in leads:
		if int(l.id) == lead_id:
			return l
	return {}


func find_prospect(lead_id: int) -> Dictionary:
	for p in prospects:
		if int(p.id) == lead_id:
			return p
	return {}


func deal_price(lead: Dictionary, in_person: bool) -> int:
	var product := GameData.get_product(lead.product_id)
	if product == null:
		return 0
	var mult := 1.0 + reputation / 200.0
	if in_person:
		mult += IN_PERSON_BONUS
	return roundi(product.retail_price * int(lead.qty) * mult)


func can_fulfil(lead: Dictionary) -> bool:
	return stock_of(lead.product_id) >= int(lead.qty)


## Café prospect -> lead. Takes time, gives a little XP.
func meet_prospect(lead_id: int) -> void:
	var p := find_prospect(lead_id)
	if p.is_empty() or p.met:
		return
	p.met = true
	leads.append(p.duplicate())
	leads_added.emit(1)
	advance_time(MEET_MINUTES)
	add_xp(5)
	complete_task("meet_prospect")
	leads_changed.emit()


func close_deal(lead_id: int, in_person: bool) -> bool:
	var lead := find_lead(lead_id)
	if lead.is_empty():
		return false
	var product := GameData.get_product(lead.product_id)
	if product == null or not can_fulfil(lead):
		UIEvents.toast("Not enough stock")
		return false
	var amount := deal_price(lead, in_person)
	add_stock(product.id, -int(lead.qty))
	add_cash(amount)
	add_reputation(product.reputation_reward * (2 if in_person else 1))
	advance_time(DEAL_IN_PERSON_MINUTES if in_person else DEAL_PHONE_MINUTES)
	leads.erase(lead)
	var p := find_prospect(lead_id)
	if not p.is_empty():
		p.sold = true
	var account := "%s (%s)" % [lead.name, lead.business]
	if not customers.has(account):
		customers.append(account)
	deals.append({"day": day, "customer": account, "product_id": String(product.id),
		"qty": int(lead.qty), "amount": amount, "in_person": in_person})
	deal_closed.emit(amount, in_person)
	UIEvents.toast("Deal closed! +$%s" % format_money(amount))
	add_xp(product.xp_reward * int(lead.qty))
	complete_task("first_deal")
	leads_changed.emit()
	deals_changed.emit()
	return true


func _make_lead(source: String) -> Dictionary:
	var pool := GameData.products_for_level(level)
	# Leads usually ask for something you carry, so early game can't soft-lock before the depot unlocks.
	var stocked := pool.filter(func(p: ProductData): return stock_of(p.id) > 0)
	if not stocked.is_empty() and randf() < LEAD_STOCK_BIAS:
		pool.assign(stocked)
	var product: ProductData = pool.pick_random()
	var lead := {
		"id": _next_id,
		"name": "%s %s" % [GameData.FIRST_NAMES.pick_random(), GameData.LAST_NAMES.pick_random()],
		"business": GameData.BUSINESSES.pick_random(),
		"product_id": String(product.id),
		"qty": randi_range(1, product.max_order_qty),
		"source": source,
		"met": false,
		"sold": false,
		"tint": Color.from_hsv(randf(), randf_range(0.35, 0.6), randf_range(0.85, 1.0)).to_html(),
	}
	_next_id += 1
	return lead


func _roll_prospects() -> void:
	prospects = []
	for i in CAFE_PROSPECTS:
		prospects.append(_make_lead("cafe"))


# --- Travel --------------------------------------------------------------------

## Returns "" on success, or a reason the trip is not possible.
func travel_check(loc: LocationData) -> String:
	if loc == null:
		return "Pick a destination"
	if loc.id == location_id:
		return "You are here"
	if loc.unlock_level > level:
		return "Requires Level %d" % loc.unlock_level
	if loc.fare > cash:
		return "Not enough cash"
	return ""


func travel_to(loc: LocationData) -> bool:
	if travel_check(loc) != "":
		return false
	location_id = loc.id
	add_cash(-loc.fare)
	advance_time(loc.travel_minutes)
	if loc.id == &"coffee":
		complete_task("visit_cafe")
	UIEvents.toast("Arrived at %s  (+%d min)" % [loc.display_name, loc.travel_minutes])
	location_changed.emit(location_id)
	return true


# --- Tasks / tutorial ----------------------------------------------------------

func complete_task(task_id: String) -> void:
	if completed_tasks.has(task_id):
		return
	completed_tasks[task_id] = true
	task_completed.emit(task_id)
	for t in GameData.TASKS:
		if t.id == task_id:
			if t.xp > 0:
				add_xp(t.xp)
			break
	tasks_changed.emit()


func has_open_tasks() -> bool:
	return completed_tasks.size() < GameData.TASKS.size()


# --- Save data -----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"day": day, "minutes": minutes, "cash": cash, "reputation": reputation, "xp": xp,
		"location_id": String(location_id), "inventory": inventory, "leads": leads,
		"prospects": prospects, "customers": customers, "deals": deals,
		"revenue_total": revenue_total, "expenses_total": expenses_total,
		"completed_tasks": completed_tasks.keys(), "tutorial_step": tutorial_step,
		"tutorial_done": tutorial_done, "tutorial_version": TUTORIAL_VERSION, "next_id": _next_id,
	}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minutes = int(d.get("minutes", START_MINUTES))
	cash = int(d.get("cash", START_CASH))
	reputation = int(d.get("reputation", 0))
	xp = int(d.get("xp", 0))
	level = GameData.level_for_xp(xp)
	location_id = StringName(d.get("location_id", "home"))
	if GameData.get_location(location_id) == null:
		location_id = &"home"
	inventory = {}
	for k in d.get("inventory", {}):
		inventory[String(k)] = int(d.inventory[k])
	leads = _fix_leads(d.get("leads", []))
	prospects = _fix_leads(d.get("prospects", []))
	customers = Array(d.get("customers", []))
	deals = []
	for deal in d.get("deals", []):
		deal.day = int(deal.day)
		deal.qty = int(deal.qty)
		deal.amount = int(deal.amount)
		deals.append(deal)
	revenue_total = int(d.get("revenue_total", 0))
	expenses_total = int(d.get("expenses_total", 0))
	completed_tasks = {}
	for t in d.get("completed_tasks", []):
		completed_tasks[String(t)] = true
	tutorial_step = int(d.get("tutorial_step", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	# V1 saves count tips of the old 4-tip carousel; an unfinished V1 tutorial restarts the V2 steps.
	if int(d.get("tutorial_version", 1)) < TUTORIAL_VERSION and not tutorial_done:
		tutorial_step = 0
	_next_id = int(d.get("next_id", 1))
	day_closing = false
	_emit_all()
	# Saved at (or, from older versions, after) 8:30 PM: the day is over, show its summary again.
	if is_day_over():
		end_day.call_deferred(&"time")


## JSON turns ints into floats; normalise lead dictionaries after loading.
func _fix_leads(raw: Array) -> Array:
	var out := []
	for l in raw:
		l.id = int(l.id)
		l.qty = int(l.qty)
		out.append(l)
	return out


func _emit_all() -> void:
	state_reset.emit()
	stats_changed.emit()
	inventory_changed.emit()
	leads_changed.emit()
	deals_changed.emit()
	tasks_changed.emit()
	location_changed.emit(location_id)


func format_money(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out
