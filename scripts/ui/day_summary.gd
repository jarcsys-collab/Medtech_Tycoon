class_name DaySummary
extends Control
## End-of-day summary (Sales Simulator handoff: "END OF DAY · Day N complete" card with a NEXT DAY
## button). Opens on GameState.day_finished (8:30 PM or the bed); the only way on is NEXT DAY,
## which starts the next morning once. Escape and taps outside the card do not close it.

const ROW_ICONS := {
	&"deals": preload("res://assets/ui/deals.png"),
	&"cash": preload("res://assets/ui/cash.png"),
	&"met": preload("res://assets/ui/pCust.png"),
	&"level": preload("res://assets/ui/star.png"),
	&"leads": preload("res://assets/ui/leads.png"),
}
const GOOD := Color("#3dffc0")
const MUTED := Color("#9fb0ad")
const GOLD := Color("#ffd166")
const BLUE := Color("#7ed8f7")

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = %Title
@onready var date_label: Label = %Date
@onready var reason_label: Label = %Reason
@onready var rows: VBoxContainer = %Rows
@onready var next_button: Button = %NextDay


func _ready() -> void:
	hide()
	next_button.pressed.connect(_on_next_day)
	GameState.day_finished.connect(open)
	GameState.state_reset.connect(_on_state_reset)


func open(summary: Dictionary) -> void:
	title_label.text = "Day %d complete" % summary.day
	date_label.text = summary.date
	if summary.reason == &"time":
		reason_label.text = "It's %s. The working day is over." % summary.time
	else:
		reason_label.text = "You turned in for the night."
	UIFactory.clear(rows)
	_row(&"deals", "Deals closed", str(summary.deals), GOOD if summary.deals > 0 else MUTED)
	if summary.sales > 0:
		_row(&"cash", "Gross sales", "+$" + GameState.format_money(summary.sales), GOOD)
	_row(&"met", "Clients met", str(summary.met), GOOD if summary.met > 0 else MUTED)
	_row(&"cash", "Cash on hand", "$" + GameState.format_money(summary.cash), Color.WHITE)
	_row(&"level", "Level", "%d · Rep %d%%" % [summary.level, summary.reputation], GOLD)
	_row(&"leads", "Tomorrow", "+%d new leads" % summary.new_leads, BLUE)
	next_button.disabled = false
	UIAnim.pop_in(self, panel, 0.92)


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: on narrow portrait screens the card uses the screen width instead of 460 px.
func apply_layout(portrait: bool) -> void:
	if portrait:
		LayoutSwap.apply(panel, {"custom_minimum_size": Vector2(minf(460.0, get_viewport_rect().size.x - 20.0), 0)})
	else:
		LayoutSwap.restore(panel)


func _row(icon: StringName, label: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var tex := TextureRect.new()
	tex.texture = ROW_ICONS[icon]
	tex.custom_minimum_size = Vector2(24, 24)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(tex)
	row.add_child(UIFactory.label(label, &"CaptionLabel", 14))
	var v := UIFactory.label(value, &"TitleSmall", 0, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	rows.add_child(row)


## One press only: the button is disabled at once, and GameState ignores a second start anyway.
func _on_next_day() -> void:
	if next_button.disabled:
		return
	next_button.disabled = true
	GameState.start_next_day()


## Load / new game / next morning: close unless the loaded day is still over (it reopens then).
func _on_state_reset() -> void:
	if not GameState.day_closing:
		close()
