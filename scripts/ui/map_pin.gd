class_name MapPin
extends VBoxContainer
## City-map destination pin: optional "YOU ARE HERE" tag, name button, drawn teardrop pin.
## Positions itself so the pin tip sits on location.map_position (Medtycoonv1: translate(-50%,-100%)).

signal chosen(location_id: StringName)

const RED := Color("#ff3b30")
const MINT := Color("#3dffc0")
const SKY := Color("#7ed8f7")
const GREY := Color("#5d6668")

var location: LocationData
## Pin tip position in the parent (map canvas) coordinates; set by TravelMap.
var anchor_point := Vector2.ZERO
## Width of the visible map (0 = no limit; set by TravelMap). A pin near the edge keeps its tip on
## the spot but slides its name tag inward, so the tag is never cut off by the map frame.
var bounds_width := 0.0
var _pin_shift := 0.0
var _here := false
var _selected := false
var _locked := false

@onready var here_tag: PanelContainer = $HereTag
@onready var name_button: Button = $NameButton
@onready var pin: Control = $Pin


func _ready() -> void:
	name_button.pressed.connect(func(): chosen.emit(location.id))
	pin.draw.connect(_draw_pin)
	resized.connect(_reposition)


func setup(loc: LocationData) -> void:
	location = loc
	name_button.text = loc.display_name


func set_state(here: bool, selected: bool, locked: bool) -> void:
	_here = here
	_selected = selected
	_locked = locked
	here_tag.visible = here
	var big := here or selected
	var ring := SKY if selected else (MINT if here else (Color("#3a4446") if locked else RED))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151a1b") if locked else Color("#0b1211")
	style.set_border_width_all(2)
	style.border_color = ring
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5 if big else 3)
	style.content_margin_left = 12 if big else 9
	style.content_margin_right = style.content_margin_left
	if not locked:
		style.shadow_color = Color(ring, 0.6)
		style.shadow_size = 6
	for s in [&"normal", &"hover", &"pressed", &"focus"]:
		name_button.add_theme_stylebox_override(s, style)
	var text_color := MINT if here else (Color("#9aa4a6") if locked else Color.WHITE)
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		name_button.add_theme_color_override(c, text_color)
	name_button.add_theme_font_size_override(&"font_size", 17 if big else 14)
	name_button.text = location.display_name + ("   LV %d" % location.unlock_level if locked else "")
	modulate.a = 0.85 if locked and not selected else 1.0
	z_index = 5 if selected else (4 if here else 2)
	pin.custom_minimum_size = Vector2(34, 34) if big else Vector2(22, 22)
	pin.queue_redraw()
	set_process(here)
	reset_size()
	_reposition()


func _process(_delta: float) -> void:
	pin.queue_redraw()


func _reposition() -> void:
	if location:
		var x := anchor_point.x - size.x / 2.0
		var inside := x
		if bounds_width > 0.0 and size.x <= bounds_width:
			inside = clampf(x, 0.0, bounds_width - size.x)
		position = Vector2(inside, anchor_point.y - size.y)
		if not is_equal_approx(_pin_shift, x - inside):
			_pin_shift = x - inside
			pin.queue_redraw()


func _draw_pin() -> void:
	var s := pin.size
	var shift := Vector2(_pin_shift, 0.0)
	var r := minf(s.x, s.y) * 0.42
	var c := Vector2(s.x / 2.0, r + 2.0)
	var fill := MINT if _here else (GREY if _locked else RED)
	var border := Color("#0a1011") if _locked else Color.WHITE
	if _here:
		# Two expanding rings under the pin (Medtycoonv1 pulse / pulse2).
		var ph := fmod(Time.get_ticks_msec() / 1300.0, 1.0)
		for offset in [0.0, 0.5]:
			var p := fmod(ph + offset, 1.0)
			pin.draw_set_transform(shift + Vector2(s.x / 2.0, s.y * 1.18), 0.0, Vector2(1.0, 0.45))
			pin.draw_arc(Vector2.ZERO, 34.0 * (0.4 + p * 1.1), 0.0, TAU, 40, Color(MINT, 1.0 - p), 3.0)
	pin.draw_set_transform(shift, 0.0, Vector2.ONE)
	var tip := Vector2(s.x / 2.0, s.y)
	var poly := PackedVector2Array([c + Vector2(-r * 0.75, r * 0.65), tip, c + Vector2(r * 0.75, r * 0.65)])
	pin.draw_colored_polygon(poly, border)
	pin.draw_circle(c, r + 2.0, border)
	pin.draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(2, -1), tip - Vector2(0, 4), poly[2] + Vector2(-2, -1)]), fill)
	pin.draw_circle(c, r - 1.0, fill)
	pin.draw_circle(c, r * 0.32, Color("#0a1011"))
