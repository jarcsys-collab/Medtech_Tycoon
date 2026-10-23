extends Node
## Root of the game: owns the persistent Player, swaps location scenes, and routes side-nav/overlay state
## (Medtycoonv1 `active` + `phone` state and select()). Presentation: GameCamera framing, fade
## transitions between locations, interaction marker and floating "+$ / +XP" feedback.

## Presentation hook (audio): the open overlay changed (&"" = none, &"phone", &"travel", &"tasks", ...).
signal overlay_changed(active: StringName)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MIN_WINDOW := Vector2i(960, 540)
const FADE_OUT := 0.2
const FADE_IN := 0.3
const FLOAT_HEAD_OFFSET := Vector2(0, -250)
const PHONE_ROOM_SHIFT := 110.0
const FLOAT_MIN_SCREEN_Y := 150.0

@onready var world: Node2D = $World
@onready var fx: Node2D = $World/FX
@onready var camera: GameCamera = $World/GameCamera
@onready var marker: InteractionMarker = $World/FX/InteractionMarker
@onready var travel_map: TravelMap = $UI/TravelMap
@onready var phone: Phone = $UI/Phone
@onready var hud: Hud = $UI/Hud
@onready var info_panel: InfoPanel = $UI/InfoPanel
@onready var choice_dialog: ChoiceDialog = $UI/ChoiceDialog
@onready var fader: ScreenFader = $Fader

var player: Player
var current_location: LocationBase
var active: StringName = &""

var _shown_location: StringName = &""
var _transition_id := 0
var _transitioning := false
var _float_frame := -1
var _float_stack := 0
var _portrait := false
var _layout_queued := false


func _ready() -> void:
	get_window().min_size = min_window_size(OS.has_feature("web"))
	player = PLAYER_SCENE.instantiate()
	player.interactable_changed.connect(hud.set_prompt)
	player.interactable_changed.connect(marker.follow)

	hud.nav_selected.connect(select)
	phone.close_requested.connect(_close_overlays)
	travel_map.close_requested.connect(_close_overlays)
	info_panel.close_requested.connect(_close_overlays)
	choice_dialog.visibility_changed.connect(_update_input_lock)
	# Medtycoonv2 tutorial events.
	player.moved_enough.connect(Tutorial.notify.bind("moved"))
	overlay_changed.connect(Tutorial.on_overlay_changed)
	phone.page_changed.connect(Tutorial.on_phone_page)

	travel_map.hide()
	info_panel.hide()
	phone.hide()

	if not SaveSystem.load_game():
		GameState.new_game()
	_load_location(GameState.location_id)
	# Connected after the initial load so startup builds the world exactly once.
	GameState.location_changed.connect(_on_location_changed)
	GameState.state_reset.connect(_on_state_reset)
	GameState.cash_delta.connect(_on_cash_delta)
	GameState.xp_gained.connect(func(n: int): _float("+%d XP" % n, Color("#e8c25a")))
	GameState.reputation_delta.connect(func(n: int): _float("%+d REP" % n, Color("#7ed8f7")))
	# Responsive layout: re-applied on mode changes, resizes, rotation and fullscreen.
	Responsive.layout_changed.connect(func(_mode): _queue_layout())
	hud.portrait_insets_changed.connect(_apply_overlay_insets)
	get_tree().root.size_changed.connect(_queue_layout)
	update_responsive_layout()
	select(&"phone")  # Medtycoonv1 phoneOpenOnStart = true
	if SaveSystem.last_error != "":
		UIEvents.toast(SaveSystem.load_failure_message())
	fader.fade_to(0.0, 0.5)


## Desktop builds only. On the web the canvas follows the browser; a minimum size there makes
## Godot lay out for a wider window than a phone shows, so the right edge is cut off.
static func min_window_size(web: bool) -> Vector2i:
	return Vector2i.ZERO if web else MIN_WINDOW


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if choice_dialog.visible:
			choice_dialog.close()
		else:
			_close_overlays()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_phone") and not choice_dialog.visible:
		select(&"phone")  # Medtycoonv2 input map: P
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"open_map") and not choice_dialog.visible:
		select(&"travel")  # Medtycoonv2 input map: M (toggles like the TRAVEL tile)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_save"):
		UIEvents.toast("Game saved" if SaveSystem.save_game() else "Save failed")
	elif event.is_action_pressed(&"quick_load"):
		UIEvents.toast("Game loaded" if SaveSystem.load_game() else SaveSystem.load_failure_message())


## Side-nav selection. Phone and Travel toggle; other items open the info panel.
func select(id: StringName) -> void:
	if id == active and (id == &"phone" or id == &"travel" or info_panel.visible):
		_close_overlays()
		return
	active = id
	_apply_overlay_insets()
	if id != &"phone":
		phone.close()
	if id != &"travel":
		travel_map.close()
	if id in [&"phone", &"travel"]:
		info_panel.close()
	match id:
		&"phone":
			phone.open()
			GameState.complete_task("open_phone")
		&"travel":
			travel_map.open()
		_:
			info_panel.open(id)
	_sync_ui()


func _close_overlays() -> void:
	active = &""
	phone.close()
	travel_map.close()
	info_panel.close()
	_sync_ui()


func _sync_ui() -> void:
	hud.set_active_nav(active)
	hud.set_map_mode(active == &"travel")
	_apply_overlay_insets()  # mobile: the HUD just collapsed / restored its cards
	_update_camera_shift()
	_update_input_lock()
	overlay_changed.emit(active)


## Keep the room clear of the phone, which docks on the right (desktop / landscape only; in
## portrait the phone covers the screen width).
func _update_camera_shift() -> void:
	camera.screen_shift = Vector2(-PHONE_ROOM_SHIFT, 0) if active == &"phone" and not _portrait else Vector2.ZERO


# --- Responsive layout (mode and UI base size come from the Responsive autoload) -----------

func _queue_layout() -> void:
	if not _layout_queued:
		_layout_queued = true
		update_responsive_layout.call_deferred()


func update_responsive_layout() -> void:
	_layout_queued = false
	match Responsive.mode:
		Responsive.Mode.MOBILE_PORTRAIT:
			apply_mobile_portrait_layout()
		Responsive.Mode.MOBILE_LANDSCAPE:
			apply_mobile_landscape_layout()
		_:
			apply_desktop_layout()
	marker.touch_mode = hud.touch_ui


func apply_desktop_layout() -> void:
	_portrait = false
	hud.apply_layout(false)
	phone.apply_layout(false, Vector2.ZERO)
	travel_map.apply_layout(false, Vector2.ZERO)
	info_panel.apply_layout(false, Vector2.ZERO)
	choice_dialog.apply_layout(false)
	camera.inset_source = Callable()
	_update_camera_shift()


## Same arrangement as desktop; Responsive renders it from a smaller UI base (960x540) so text
## and buttons are larger on phone screens held sideways.
func apply_mobile_landscape_layout() -> void:
	apply_desktop_layout()
	# Short screens: keep the phone and panels between the top bar and the screen edge, clear of
	# the nav rail (right) and the tutorial card (left), instead of overlapping the stat bar.
	var vp := get_viewport().get_visible_rect().size
	phone.apply_band(Rect2(vp.x - 124.0 - 340.0, 74.0, 124.0, 8.0))
	info_panel.apply_band(Rect2(352.0, 74.0, 128.0, 8.0))


func apply_mobile_portrait_layout() -> void:
	_portrait = true
	hud.apply_layout(true)
	choice_dialog.apply_layout(true)
	camera.inset_source = hud.get_portrait_insets
	_update_camera_shift()
	_apply_overlay_insets.call_deferred()  # after the HUD has been laid out


## Portrait: fit the phone / map / panels between the HUD bars and below the task card. The phone
## also stays clear of the tutorial card so the current instruction remains readable.
func _apply_overlay_insets() -> void:
	if not _portrait:
		return
	var bars := hud.get_portrait_insets(false)
	var with_cards := hud.get_portrait_insets(true)
	phone.apply_layout(true, with_cards)
	travel_map.apply_layout(true, bars)  # the task and tutorial cards are hidden on the map
	info_panel.apply_layout(true, with_cards)


func _update_input_lock() -> void:
	player.input_enabled = not (choice_dialog.visible or active == &"travel" or _transitioning)


func _on_location_changed(location_id: StringName) -> void:
	if location_id == _shown_location:
		return
	_transition_to(location_id)
	SaveSystem.save_game()


## New game / load / sleep: rebuild the current place so NPCs reflect the restored state.
func _on_state_reset() -> void:
	_transition_to(GameState.location_id)


## Fade to black, swap the location, fade back in. A newer transition supersedes an older one.
func _transition_to(location_id: StringName) -> void:
	_shown_location = location_id
	_transition_id += 1
	var my_id := _transition_id
	_transitioning = true
	_update_input_lock()
	await fader.fade_to(1.0, FADE_OUT)
	if my_id != _transition_id:
		return
	_load_location(location_id)
	_close_overlays()
	_transitioning = false
	_update_input_lock()
	await fader.fade_to(0.0, FADE_IN)


func _load_location(location_id: StringName) -> void:
	var data := GameData.get_location(location_id)
	var path := GameData.COMING_SOON_SCENE
	if data and data.scene_path != "":
		path = data.scene_path
	if player.get_parent():
		player.get_parent().remove_child(player)
	if current_location:
		current_location.queue_free()
	current_location = (load(path) as PackedScene).instantiate()
	world.add_child(current_location)
	world.move_child(current_location, 0)
	current_location.setup(data, player)
	_shown_location = location_id
	camera.frame(current_location.get_camera_focus(), player if player.is_inside_tree() else null)
	hud.set_prompt(null)
	marker.follow(null)


func _on_cash_delta(amount: int) -> void:
	if amount > 0:
		_float("+$" + GameState.format_money(amount), Color("#3dffc0"))
	elif amount < 0:
		_float("-$" + GameState.format_money(-amount), Color("#ff8a7a"))


## Floating feedback above the player's head; popups raised in the same frame stack upward.
func _float(text: String, color: Color) -> void:
	if not player.is_inside_tree() or _transitioning:
		return
	var frame := Engine.get_process_frames()
	_float_stack = _float_stack + 1 if frame == _float_frame else 0
	_float_frame = frame
	var z := camera.zoom.x
	var pos := player.global_position + FLOAT_HEAD_OFFSET - Vector2(0, 30.0 / z * _float_stack)
	# Keep the whole rise below the top stat bar (screen y >= FLOAT_MIN_SCREEN_Y).
	var view_top := camera.get_screen_center_position().y - get_viewport().get_visible_rect().size.y / 2.0 / z
	var min_y := hud.get_portrait_insets().x if _portrait else FLOAT_MIN_SCREEN_Y
	pos.y = maxf(pos.y, view_top + (min_y + 30.0 * _float_stack) / z)
	FloatingText.spawn(fx, pos, text, color)
