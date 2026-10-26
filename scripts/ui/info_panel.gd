class_name InfoPanel
extends PanelContainer
## One panel, four modes: tasks / deals / inventory / finance (side-nav items that were stubs in Medtycoonv1).

signal close_requested

const MODES := {
	&"tasks": ["TASKS", preload("res://assets/ui/tasks.png")],
	&"deals": ["DEALS", preload("res://assets/ui/deals.png")],
	&"inventory": ["INVENTORY", preload("res://assets/ui/inv.png")],
	&"finance": ["FINANCE", preload("res://assets/ui/fin.png")],
}
const MINT := Color("#3dffc0")
const GOLD := Color("#e8c25a")

@onready var icon: TextureRect = %Icon
@onready var title: Label = %Title
@onready var content: VBoxContainer = %Content
## Stays below the scrolling list, so its buttons (REPLAY) are never scrolled out of sight.
@onready var footer: HBoxContainer = %Footer
@onready var close_button: Button = %CloseButton

var mode: StringName = &""
var _refresh_queued := false


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	for sig in [GameState.stats_changed, GameState.inventory_changed, GameState.deals_changed, GameState.tasks_changed]:
		sig.connect(_queue_refresh)


func open(new_mode: StringName) -> void:
	var was_open := visible and modulate.a > 0.99
	mode = new_mode
	refresh()
	if not was_open:
		UIAnim.pop_in(self, self, 0.95)


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: portrait phones show the panel full-width between the HUD bars
## (insets = screen px kept free at the top / bottom). Otherwise the scene layout (centred).
func apply_layout(portrait: bool, insets: Vector2) -> void:
	if portrait:
		LayoutSwap.apply(self, LayoutSwap.band(8.0, insets.x, 8.0, insets.y))
	else:
		LayoutSwap.restore(self)


## Mobile landscape: fit the panel between the HUD columns (margins in UI px).
func apply_band(margins: Rect2) -> void:
	LayoutSwap.apply(self, LayoutSwap.band(margins.position.x, margins.position.y, margins.size.x, margins.size.y))


func _queue_refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	if not MODES.has(mode):
		return
	title.text = MODES[mode][0]
	icon.texture = MODES[mode][1]
	UIFactory.clear(content)
	UIFactory.clear(footer)
	footer.hide()
	match mode:
		&"tasks": _build_tasks()
		&"deals": _build_deals()
		&"inventory": _build_inventory()
		&"finance": _build_finance()


func _build_tasks() -> void:
	for t in GameData.TASKS:
		var done: bool = GameState.completed_tasks.has(t.id)
		var parts := UIFactory.row_panel()
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 10)
		head.add_child(UIFactory.check_box(done))
		head.add_child(UIFactory.label(t.title, &"TitleSmall", 0, MINT if done else UIFactory.NONE))
		if t.xp > 0:
			var xp := UIFactory.label("+%d XP" % t.xp, &"SubLabel")
			xp.size_flags_horizontal = Control.SIZE_SHRINK_END
			head.add_child(xp)
		parts[1].add_child(head)
		parts[1].add_child(UIFactory.label(t.desc, &"SubLabel", 0, UIFactory.NONE, true))
		if done:
			parts[0].modulate.a = 0.6
		content.add_child(parts[0])
	# Medtycoonv2: replay the guided tutorial from TASKS.
	var replay := UIFactory.button("Replay tutorial" if not Tutorial.is_active() else "Restart tutorial (step %s)" % Tutorial.index_label(), _replay_tutorial)
	replay.name = "ReplayButton"
	replay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	footer.add_child(replay)
	footer.show()


func _replay_tutorial() -> void:
	Tutorial.restart()
	close_requested.emit()


func _build_deals() -> void:
	var total := 0
	for d in GameState.deals:
		total += int(d.amount)
	content.add_child(UIFactory.label("%d deals closed · $%s revenue" % [GameState.deals.size(), GameState.format_money(total)], &"GoldTitle", 16))
	if GameState.deals.is_empty():
		content.add_child(UIFactory.label("No deals yet. Pitch café customers or call leads from your phone.", &"SubLabel", 0, UIFactory.NONE, true))
	for i in range(GameState.deals.size() - 1, -1, -1):
		var d: Dictionary = GameState.deals[i]
		var product := GameData.get_product(d.product_id)
		var parts := UIFactory.row_panel()
		parts[1].add_child(UIFactory.label("Day %d · %s" % [int(d.day), d.customer], &"TitleSmall", 15, UIFactory.NONE, true))
		parts[1].add_child(UIFactory.label("%d× %s · $%s · %s" % [int(d.qty), product.display_name if product else d.product_id,
			GameState.format_money(int(d.amount)), "in person" if d.in_person else "by phone"], &"SubLabel", 0, UIFactory.NONE, true))
		content.add_child(parts[0])


func _build_inventory() -> void:
	var units := 0
	var value := 0
	for p in GameData.products:
		units += GameState.stock_of(p.id)
		value += GameState.stock_of(p.id) * p.wholesale_cost
	content.add_child(UIFactory.label("%d units in stock · $%s at cost" % [units, GameState.format_money(value)], &"GoldTitle", 16))
	for p in GameData.products:
		var locked := p.unlock_level > GameState.level
		var parts := UIFactory.row_panel()
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		row.add_child(UIFactory.product_swatch(p, Vector2(46, 34)))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UIFactory.label(p.display_name + ("   (LV %d)" % p.unlock_level if locked else ""), &"TitleSmall"))
		text.add_child(UIFactory.label("Cost $%s · Sells ~$%s" % [GameState.format_money(p.wholesale_cost), GameState.format_money(p.retail_price)], &"SubLabel"))
		row.add_child(text)
		var qty := UIFactory.label("x%d" % GameState.stock_of(p.id), &"ValueLabel")
		qty.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(qty)
		parts[1].add_child(row)
		if locked:
			parts[0].modulate.a = 0.55
		content.add_child(parts[0])
	content.add_child(UIFactory.label("Restock at the Supplier Depot (Harbor).", &"SubLabel"))


func _build_finance() -> void:
	var prog := GameState.xp_progress()
	var lines := [
		["Cash", "$" + GameState.format_money(GameState.cash)],
		["Revenue (all time)", "$" + GameState.format_money(GameState.revenue_total)],
		["Expenses (all time)", "$" + GameState.format_money(GameState.expenses_total)],
		["Profit", "$" + GameState.format_money(GameState.revenue_total - GameState.expenses_total)],
		["Reputation", "%d%%" % GameState.reputation],
		["Leads", str(GameState.leads.size())],
		["Level", "%d  (%s)" % [GameState.level, ("%d / %d XP" % [prog.x, prog.y]) if prog.y > 0 else "MAX"]],
		["Deals closed", str(GameState.deals.size())],
		["Customers", str(GameState.customers.size())],
	]
	var parts := UIFactory.row_panel()
	for line in lines:
		var row := HBoxContainer.new()
		row.add_child(UIFactory.label(line[0], &"CaptionLabel", 13))
		var v := UIFactory.label(line[1], &"TitleSmall")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		parts[1].add_child(row)
	content.add_child(parts[0])

	content.add_child(UIFactory.label("GAME", &"CaptionLabel"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	buttons.add_child(UIFactory.button("Save (F5)", _save, false, true))
	buttons.add_child(UIFactory.button("Load (F9)", _load, not SaveSystem.has_save()))
	buttons.add_child(UIFactory.button("New Game", _confirm_new_game))
	content.add_child(buttons)
	content.add_child(UIFactory.label("Autosaves when you travel and when you sleep.", &"SubLabel", 0, UIFactory.NONE, true))


func _save() -> void:
	UIEvents.toast("Game saved" if SaveSystem.save_game() else "Save failed")
	_queue_refresh()


func _load() -> void:
	UIEvents.toast("Game loaded" if SaveSystem.load_game() else SaveSystem.load_failure_message())


func _confirm_new_game() -> void:
	UIEvents.ask("Start a new game?", "Your current progress will be overwritten on the next save.",
		[UIEvents.option("Start over", _new_game, false, true), UIEvents.option("Cancel")])


func _new_game() -> void:
	GameState.new_game()
	SaveSystem.save_game()
	UIEvents.toast("New game started")
