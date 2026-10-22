class_name TravelMap
extends Control
## City map overlay (Medtycoonv1 "Travel map"): pick a pin, review trip time/fare, TRAVEL.
## The portrait map is shown as a framed card that fits the available height (scrolls/drag-pans if
## the window is short); pins and labels stay at a constant, readable UI size.

signal close_requested

const PIN_SCENE := preload("res://scenes/ui/map_pin.tscn")
## Region of the map image that contains every pin (map image pixels).
const ROI := Rect2(0, 90, 941, 1150)
const MIN_SCALE := 0.62
const MAX_SCALE := 1.0
## Same layout as the day map (pins stay put); shown from 4:30 PM (GameState.is_evening).
const EVENING_MAP := preload("res://assets/environment/city-map-evening.png")

@onready var map_scroll: ScrollContainer = %MapScroll
@onready var map_canvas: Control = %MapCanvas
@onready var map_image: TextureRect = %MapImage
@onready var pins_layer: Control = %Pins
@onready var info_box: PanelContainer = %InfoBox
@onready var level_info: Label = %LevelInfo
@onready var dest_name: Label = %DestName
@onready var dest_district: Label = %DestDistrict
@onready var dest_desc: Label = %DestDesc
@onready var time_label: Label = %TimeLabel
@onready var cost_label: Label = %CostLabel
@onready var go_button: Button = %GoButton
@onready var close_button: Button = %CloseButton

var _dest: StringName = &""
var _pins := {}
var _day_map: Texture2D
var _scale := 1.0
var _dragging := false


func _ready() -> void:
	_day_map = map_image.texture
	for loc in GameData.locations:
		var pin: MapPin = PIN_SCENE.instantiate()
		pins_layer.add_child(pin)
		pin.setup(loc)
		pin.chosen.connect(_on_pin_chosen)
		_pins[loc.id] = pin
	go_button.pressed.connect(_on_go)
	close_button.pressed.connect(close_requested.emit)
	map_scroll.resized.connect(_layout)
	$MapArea.resized.connect(_layout)
	map_canvas.gui_input.connect(_on_canvas_input)
	GameState.stats_changed.connect(refresh)
	_layout()
	refresh()


func open() -> void:
	_dest = &""
	refresh()
	UIAnim.pop_in(self, info_box, 0.96)
	_layout.call_deferred()
	_scroll_to_current.call_deferred()


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: portrait phones get a full-width map with the trip panel above the bottom nav bar
## (insets = screen px kept free at the top / bottom). Otherwise the scene layout.
func apply_layout(portrait: bool, insets: Vector2) -> void:
	var map_area: Control = $MapArea
	if portrait:
		# Narrow screen: let the long labels wrap and slim the TRAVEL button so the panel fits.
		LayoutSwap.apply(level_info, {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(10, 0)})
		LayoutSwap.apply(dest_name, {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(10, 0),
			"size_flags_horizontal": Control.SIZE_EXPAND_FILL})
		LayoutSwap.apply(go_button, {"custom_minimum_size": Vector2(96, 44)})
		LayoutSwap.apply(info_box, {"anchor_left": 0.0, "anchor_right": 1.0,
			"offset_left": 8.0, "offset_top": -insets.y, "offset_right": -8.0, "offset_bottom": -insets.y})
		var info_h := info_box.get_combined_minimum_size().y
		LayoutSwap.apply(map_area, {
			"theme_override_constants/margin_left": 8, "theme_override_constants/margin_top": int(insets.x),
			"theme_override_constants/margin_right": 8,
			"theme_override_constants/margin_bottom": int(insets.y + info_h + 8.0)})
	else:
		for c in [level_info, dest_name, go_button, info_box, map_area]:
			LayoutSwap.restore(c)
	_layout.call_deferred()


func refresh() -> void:
	if not is_node_ready():
		return
	var map_tex := EVENING_MAP if GameState.is_evening() else _day_map
	map_image.texture = map_tex
	$Backdrop.texture = map_tex
	var level := GameState.level
	var open_count := 0
	for loc in GameData.locations:
		if loc.unlock_level <= level:
			open_count += 1
		(_pins[loc.id] as MapPin).set_state(loc.id == GameState.location_id, loc.id == _dest, loc.unlock_level > level)
	level_info.text = "LEVEL %d · %d places open" % [level, open_count]

	var loc := GameData.get_location(_dest)
	if loc == null:
		dest_name.text = "Pick a destination"
		dest_district.text = "CITY MAP"
		dest_desc.text = "Tap a red pin to see trip details."
		time_label.text = ""
		cost_label.text = ""
		_set_go("TRAVEL", false)
		return
	var here := loc.id == GameState.location_id
	var locked := loc.unlock_level > level
	dest_name.text = loc.display_name
	dest_district.text = loc.district
	dest_desc.text = "Locked. Reach Level %d to unlock this location." % loc.unlock_level if locked else loc.description
	time_label.text = "You are here" if here else ("Requires Level %d" % loc.unlock_level if locked else "%d min trip" % loc.travel_minutes)
	cost_label.text = "" if (here or locked) else ("$%d fare" % loc.fare if loc.fare > 0 else "Free")
	var problem := GameState.travel_check(loc)
	_set_go("HERE" if here else ("LOCKED" if locked else "TRAVEL"), problem == "")
	go_button.tooltip_text = problem


func _layout() -> void:
	# Measured from the full-screen overlay minus MapArea's margins, not from MapScroll/MapArea:
	# those can never get narrower than the current map (horizontal scrolling is disabled), so on a
	# narrow screen the map could not shrink to fit. On desktop the result is the same as before.
	var map_area: MarginContainer = $MapArea
	var area := size - Vector2(
		map_area.get_theme_constant(&"margin_left") + map_area.get_theme_constant(&"margin_right"),
		map_area.get_theme_constant(&"margin_top") + map_area.get_theme_constant(&"margin_bottom"))
	if area.y <= 0.0:
		return
	_scale = clampf(area.y / ROI.size.y, MIN_SCALE, MAX_SCALE)
	_scale = minf(_scale, area.x / ROI.size.x)
	map_canvas.custom_minimum_size = ROI.size * _scale
	map_image.position = -ROI.position * _scale
	map_image.size = map_image.texture.get_size() * _scale
	for loc in GameData.locations:
		var pin: MapPin = _pins[loc.id]
		pin.anchor_point = (loc.map_position - ROI.position) * _scale
		pin._reposition()


func _scroll_to_current() -> void:
	var loc := GameData.get_location(GameState.location_id)
	if loc:
		var y := (loc.map_position.y - ROI.position.y) * _scale
		map_scroll.scroll_vertical = int(y - map_scroll.size.y * 0.6)


func _set_go(text: String, enabled: bool) -> void:
	go_button.text = text
	go_button.disabled = not enabled
	go_button.theme_type_variation = &"PrimaryButton" if enabled else &""


func _on_pin_chosen(id: StringName) -> void:
	_dest = id
	refresh()
	UIAnim.pulse(info_box, 1.02)


func _on_go() -> void:
	var loc := GameData.get_location(_dest)
	var problem := GameState.travel_check(loc)
	if problem != "":
		UIEvents.toast(problem)
		return
	GameState.travel_to(loc)


## Drag the map with the mouse (touch drag is handled by ScrollContainer itself).
func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		map_scroll.scroll_vertical -= int(event.relative.y)
