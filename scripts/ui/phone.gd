class_name Phone
extends Control
## Sales Phone. Home = the Sales Simulator handoff's app grid (V1): apps with a page open it inside
## the phone; Deals, Inventory and Finance open their existing screens (`app_requested`); One Jarc,
## Tickets and Itinerary are shown as SOON tiles until they are built. Profile shows level and XP.
## Leads page can close deals by phone (no in-person bonus).

signal close_requested
## Presentation hook (audio): the visible page changed (&"" = phone home screen).
signal page_changed(page: StringName)
## A phone app whose screen lives outside the phone (Deals, Inventory, Finance): Main opens it.
signal app_requested(id: StringName)

## Header art by time of day (Sales Simulator v3 phone banners).
const BANNERS := {
	&"morning": preload("res://assets/ui/phone-sunrise.png"),
	&"afternoon": preload("res://assets/ui/phone-afternoon.png"),
	&"evening": preload("res://assets/ui/phone-evening.png"),
}

## Home grid, in order: [id, title, icon, icon tint (ZIP), kind]. kind: &"page" = page inside the
## phone, &"screen" = opens via app_requested, &"soon" = not built yet (disabled tile).
const APPS := [
	[&"leads", "Leads", preload("res://assets/ui/pLeads.png"), Color("#173a3a"), &"page"],
	[&"messages", "Messages", preload("res://assets/ui/pMsg-centered.png"), Color("#2a2f4a"), &"page"],
	[&"customers", "Customers", preload("res://assets/ui/pCust.png"), Color("#22324a"), &"page"],
	[&"deals", "Deals", preload("res://assets/ui/deals.png"), Color("#2e3a26"), &"screen"],
	[&"inventory", "Inventory", preload("res://assets/ui/inv.png"), Color("#3a3320"), &"screen"],
	[&"finance", "Finance", preload("res://assets/ui/fin.png"), Color("#1f2f3a"), &"screen"],
	[&"schedule", "Schedule", preload("res://assets/ui/pSched.png"), Color("#1d3346"), &"page"],
	[&"quotes", "Quotes", preload("res://assets/ui/pQuote.png"), Color("#22343a"), &"page"],
	[&"collections", "Collect", preload("res://assets/ui/pColl.png"), Color("#3a2a30"), &"page"],
	[&"profile", "Profile", preload("res://assets/ui/star.png"), Color("#3a3320"), &"page"],
	[&"one_jarc", "One Jarc", preload("res://assets/ui/pTicket.png"), Color("#173a3a"), &"soon"],
	[&"tickets", "Tickets", preload("res://assets/ui/travel.png"), Color("#1f3a2c"), &"soon"],
	[&"itinerary", "Itinerary", preload("res://assets/ui/pSched.png"), Color("#1d3346"), &"soon"],
]
const PAGE_TITLES := {&"collections": "Collections", &"profile": "Profile & Progress"}
const PORTRAIT := preload("res://assets/ui/portrait.png")

const MESSAGES := [
	["Dana (Regional Manager)", "Welcome aboard! Your territory is yours to build. Close your first deal this week."],
	["Harbor Supplier Depot", "Wholesale restocks available at our Harbor depot once you reach Level 2."],
]

@onready var backdrop: Control = $Backdrop
@onready var time_label: Label = %TimeLabel
@onready var level_label: Label = %PhoneLevel
@onready var banner: TextureRect = %Banner
@onready var greeting: Label = %Title
@onready var greeting_sub: Label = %Subtitle
@onready var home: GridContainer = %Home
@onready var home_scroll: ScrollContainer = $Frame/Screen/VBox/HomeScroll
@onready var page: VBoxContainer = %Page
@onready var page_title: Label = %PageTitle
@onready var page_list: VBoxContainer = %PageList
@onready var back_button: Button = %BackButton

var _current_page: StringName = &""
var _messages_read := false
var _refresh_queued := false


func _ready() -> void:
	backdrop.gui_input.connect(_on_backdrop_input)
	back_button.pressed.connect(show_home)
	for a in APPS:
		var tile := PhoneApp.new(a[0], a[1], a[2], a[3], a[4] != &"soon")
		tile.chosen.connect(open_page)
		home.add_child(tile)
	for sig in [GameState.stats_changed, GameState.leads_changed, GameState.inventory_changed, GameState.deals_changed]:
		sig.connect(_queue_refresh)
	show_home()


## Deferred so a page button is never freed inside its own pressed signal.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func open() -> void:
	show_home()
	UIAnim.pop_in(self, $Frame, 0.95)


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: portrait phones show the Sales Phone full-width between the HUD bars
## (insets = screen px kept free at the top / bottom). Otherwise the scene layout (docked right).
func apply_layout(portrait: bool, insets: Vector2) -> void:
	var frame: Control = $Frame
	if portrait:
		LayoutSwap.apply(frame, LayoutSwap.band(8.0, insets.x, 8.0, insets.y))
	else:
		LayoutSwap.restore(frame)


## Mobile landscape: fit the phone between the top bar and the screen bottom (margins in UI px).
func apply_band(margins: Rect2) -> void:
	LayoutSwap.apply($Frame, LayoutSwap.band(margins.position.x, margins.position.y, margins.size.x, margins.size.y))


func show_home() -> void:
	_current_page = &""
	page.hide()
	home.show()
	home_scroll.show()
	refresh()
	page_changed.emit(_current_page)


func open_page(id: StringName) -> void:
	match _app_kind(id):
		&"screen":
			app_requested.emit(id)
			return
		&"soon":
			return  # not built yet: the tile is disabled, and nothing opens
	_current_page = id
	if id == &"messages":
		_messages_read = true
	home.hide()
	home_scroll.hide()
	page.show()
	refresh()
	page_changed.emit(_current_page)


func refresh() -> void:
	_refresh_queued = false
	if not is_node_ready():
		return
	time_label.text = GameState.time_label()
	level_label.text = "LV %d" % GameState.level
	banner.texture = BANNERS[GameState.time_slot()]
	var h := floori(GameState.minutes / 60.0) % 24
	greeting.text = "Good morning" if h < 12 else "Good afternoon" if h < 17 else "Good evening"
	var n := GameState.leads.size()
	greeting_sub.text = ("%d lead%s need%s attention" % [n, "" if n == 1 else "s", "s" if n == 1 else ""]) if n > 0 else "All caught up"
	app(&"leads").badge = n
	app(&"messages").badge = 0 if _messages_read else MESSAGES.size()
	if _current_page != &"":
		_build_page(_current_page)


## Tutorial highlight (Medtycoonv2 "phone:<row>"): pulse the phone row the current step points at.
func _process(_delta: float) -> void:
	if not visible:
		return
	var target := Tutorial.highlight()
	var lit := target.begins_with("phone:") and home.visible and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for tile: PhoneApp in home.get_children():
		if tile.available:
			tile.modulate = Hud.HIGHLIGHT_TINT if (lit and String(tile.id) == target.get_slice(":", 1)) else Color.WHITE


## The home-grid tile for an app id.
func app(id: StringName) -> PhoneApp:
	for tile: PhoneApp in home.get_children():
		if tile.id == id:
			return tile
	return null


static func _app_kind(id: StringName) -> StringName:
	for a in APPS:
		if a[0] == id:
			return a[4]
	return &"page"


func _build_page(id: StringName) -> void:
	UIFactory.clear(page_list)
	page_title.text = PAGE_TITLES.get(id, String(id).capitalize())
	match id:
		&"leads":
			if GameState.leads.is_empty():
				page_list.add_child(UIFactory.label("No open leads. Meet people at Coffee Corner, or sleep for new ones.", &"SubLabel", 0, UIFactory.NONE, true))
			for lead in GameState.leads:
				page_list.add_child(_lead_card(lead))
		&"customers":
			for c in GameState.customers:
				page_list.add_child(UIFactory.label("• " + c, &"", 15, UIFactory.NONE, true))
		&"messages":
			for m in MESSAGES:
				var parts := UIFactory.row_panel()
				parts[1].add_child(UIFactory.label(m[0], &"TitleSmall", 15, Color("#7ed8f7")))
				parts[1].add_child(UIFactory.label(m[1], &"SubLabel", 0, UIFactory.NONE, true))
				page_list.add_child(parts[0])
		&"schedule":
			page_list.add_child(UIFactory.label("No meetings today.\nMeetings unlock with the Office Park (Level 3).", &"SubLabel", 0, UIFactory.NONE, true))
		&"quotes":
			page_list.add_child(UIFactory.label("No pending quotes.\nFormal quotes arrive in a later version.", &"SubLabel", 0, UIFactory.NONE, true))
		&"collections":
			page_list.add_child(UIFactory.label("$0 due today.\nAll V1 deals are paid on delivery.", &"SubLabel", 0, UIFactory.NONE, true))
		&"profile":
			_build_profile()


## Level and XP (moved here from the top bar in V1), plus the player's running totals.
func _build_profile() -> void:
	var parts := UIFactory.row_panel()
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	var face := TextureRect.new()
	face.texture = PORTRAIT
	face.custom_minimum_size = Vector2(44, 58)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var level := UIFactory.label("LEVEL %d" % GameState.level, &"GoldTitle", 18)
	level.name = "Level"
	col.add_child(level)
	var prog := GameState.xp_progress()
	var bar := ProgressBar.new()
	bar.name = "XPBar"
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = float(prog.x) / prog.y if prog.y > 0 else 1.0
	col.add_child(bar)
	var xp := UIFactory.label("%d / %d XP" % [prog.x, prog.y] if prog.y > 0 else "MAX LEVEL", &"SubLabel", 12)
	xp.name = "XP"
	col.add_child(xp)
	head.add_child(col)
	parts[1].add_child(head)
	if prog.y > 0:
		parts[1].add_child(UIFactory.label("%d XP to Level %d" % [prog.y - prog.x, GameState.level + 1], &"CaptionLabel", 12))
	page_list.add_child(parts[0])
	var stats := UIFactory.row_panel()
	for line in [["Reputation", "%d%%" % GameState.reputation], ["Total XP", str(GameState.xp)],
			["Deals closed", str(GameState.deals.size())], ["Customers", str(GameState.customers.size())],
			["Cash on hand", "$" + GameState.format_money(GameState.cash)]]:
		var row := HBoxContainer.new()
		row.add_child(UIFactory.label(line[0], &"CaptionLabel", 13))
		var v := UIFactory.label(line[1], &"TitleSmall", 14)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		stats[1].add_child(row)
	page_list.add_child(stats[0])


func _lead_card(lead: Dictionary) -> Control:
	var product := GameData.get_product(lead.product_id)
	var parts := UIFactory.row_panel()
	var box: VBoxContainer = parts[1]
	box.add_child(UIFactory.label(lead.name, &"TitleSmall", 15))
	box.add_child(UIFactory.label(lead.business + ("  · met at café" if lead.source == "cafe" else ""), &"SubLabel", 12))
	var need := HBoxContainer.new()
	need.add_theme_constant_override(&"separation", 8)
	need.add_child(UIFactory.product_swatch(product, Vector2(32, 22)))
	need.add_child(UIFactory.label("%d× %s" % [int(lead.qty), product.display_name], &"", 14, UIFactory.NONE, true))
	box.add_child(need)
	var ok := GameState.can_fulfil(lead)
	var price := GameState.deal_price(lead, false)
	var label := "Call & close  $%s" % GameState.format_money(price) if ok else "Need %d in stock (have %d)" % [int(lead.qty), GameState.stock_of(lead.product_id)]
	var btn := UIFactory.button(label, func(): GameState.close_deal(int(lead.id), false), not ok, ok)
	btn.theme_type_variation = &"PrimaryButton" if ok else &"SmallButton"
	btn.add_theme_font_size_override(&"font_size", 13)
	box.add_child(btn)
	return parts[0]


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_requested.emit()
