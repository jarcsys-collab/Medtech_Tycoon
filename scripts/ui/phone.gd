class_name Phone
extends Control
## Sales Phone (Medtycoonv1 "SALES PHONE"). Home = 6 rows; each row opens a page inside the phone.
## Leads page can close deals by phone (no in-person bonus).

signal close_requested
## Presentation hook (audio): the visible page changed (&"" = phone home screen).
signal page_changed(page: StringName)

const MESSAGES := [
	["Dana (Regional Manager)", "Welcome aboard! Your territory is yours to build. Close your first deal this week."],
	["Harbor Supplier Depot", "Wholesale restocks available at our Harbor depot once you reach Level 2."],
]

@onready var backdrop: Control = $Backdrop
@onready var time_label: Label = %TimeLabel
@onready var level_label: Label = %PhoneLevel
@onready var home: VBoxContainer = %Home
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
	for row in home.get_children():
		if row is PhoneRow:
			row.chosen.connect(open_page)
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
	_set_row(&"Leads", "%d open leads" % GameState.leads.size())
	_set_row(&"Schedule", "0 meetings today")
	_set_row(&"Messages", "0 unread" if _messages_read else "%d unread" % MESSAGES.size())
	_set_row(&"Customers", "%d customers" % GameState.customers.size())
	_set_row(&"Quotes", "0 pending")
	_set_row(&"Collections", "$0 due today")
	if _current_page != &"":
		_build_page(_current_page)


## Tutorial highlight (Medtycoonv2 "phone:<row>"): pulse the phone row the current step points at.
func _process(_delta: float) -> void:
	if not visible:
		return
	var target := Tutorial.highlight()
	var lit := target.begins_with("phone:") and home.visible and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for row in home.get_children():
		if row is PhoneRow:
			row.modulate = Hud.HIGHLIGHT_TINT if (lit and String(row.id) == target.get_slice(":", 1)) else Color.WHITE


func _set_row(row_name: StringName, text: String) -> void:
	var row := home.get_node_or_null(NodePath(row_name)) as PhoneRow
	if row:
		row.subtitle = text


func _build_page(id: StringName) -> void:
	UIFactory.clear(page_list)
	page_title.text = String(id).capitalize()
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
