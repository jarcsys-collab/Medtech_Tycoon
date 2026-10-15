extends Node
## Maps existing game events to MusicManager / SfxManager. Contains no gameplay logic: it only
## listens to signals (GameState, UIEvents, Main.overlay_changed, Phone.page_changed) and hooks
## nodes as they enter the tree (buttons, map pins, locked shelves, the player's walk cycle).

const PHONE_DUCK_DB := -4.0
const HOVER_INTERVAL_MS := 60
const QUIET_AFTER_RESET_MS := 400   # swallow jingles fired while a save/new game is applied
const QUIET_UI_AFTER_MOVE_MS := 1200 # no "panel close" swish when travel closes the map
const SLEEP_JINGLE_GAP := 3.2       # day_end -> day_start

## Phone pages that count as a customer/sales meeting (AUDIO_MANIFEST: Schedule, Customers, Quotes).
const MEETING_PAGES := [&"schedule", &"customers", &"quotes"]
## Side-menu panels with their own music (AUDIO_MANIFEST: Finance also covers Tasks and Deals).
const PANEL_TRACKS := {&"tasks": &"finance", &"deals": &"finance", &"finance": &"finance", &"inventory": &"inventory"}
## Footstep surface per location (Home = wood, Coffee Corner = tile; the depot's concrete uses tile).
const SURFACE := {&"home": &"footstep_wood", &"coffee": &"footstep_tile", &"warehouse": &"footstep_tile"}
## Buttons whose press already has a dedicated sound elsewhere.
const NO_CLICK_NAMES := [&"CloseButton", &"GoButton"]

## Jingles: [priority, music duck dB, duck hold s]. When several fire in one frame only the
## highest-priority one plays, so each game event is heard once.
const STINGERS := {
	&"level_up": [90, -8.0, 2.5],
	&"achievement_unlocked": [85, -8.0, 3.0],
	&"sale_success": [80, -6.0, 1.5],
	&"travel_confirm": [70, 0.0, 0.0],
	&"purchase": [60, 0.0, 0.0],
	&"task_complete": [50, 0.0, 0.0],
	&"new_lead": [40, 0.0, 0.0],
	&"reputation_up": [30, 0.0, 0.0],
	&"notification_message": [10, 0.0, 0.0],
}

var _overlay: StringName = &""
var _phone_page: StringName = &""
var _pending: StringName = &""
var _quiet_until := 0
var _quiet_ui_until := 0
var _sleeping := false
var _last_hover := 0
var _locked_at := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	# The main scene can enter the tree before this autoload is ready; hook what already exists.
	_hook_existing.call_deferred(get_tree().root)
	GameState.state_reset.connect(_on_state_reset)
	GameState.location_changed.connect(_on_location_changed)
	GameState.deal_closed.connect(_on_deal_closed)
	GameState.stock_purchased.connect(_on_stock_purchased)
	GameState.leads_added.connect(_on_leads_added)
	GameState.reputation_delta.connect(_on_reputation_delta)
	GameState.task_completed.connect(_on_task_completed)
	GameState.level_up.connect(_on_level_up)
	GameState.day_ended.connect(_on_day_ended)
	UIEvents.toast_requested.connect(_on_toast)
	UIEvents.choice_requested.connect(_on_choice_requested)
	# Tutorial is registered after this autoload; connect once every autoload is in the tree.
	(func(): Tutorial.step_completed.connect(_on_tutorial_step)).call_deferred()


# --- Music --------------------------------------------------------------------

func _desired_track() -> StringName:
	if _overlay == &"travel":
		return &"travel"
	if PANEL_TRACKS.has(_overlay):
		return PANEL_TRACKS[_overlay]
	if _overlay == &"phone" and _phone_page in MEETING_PAGES:
		return &"meeting"
	return GameState.location_id


func _refresh_music() -> void:
	if not _sleeping:
		MusicManager.play_track(_desired_track())


func _on_overlay_changed(active: StringName) -> void:
	if active == _overlay:
		return
	var previous := _overlay
	_overlay = active
	if active != &"phone":
		_phone_page = &""
	if not _ui_quiet():
		if active == &"travel":
			SfxManager.play(&"map_open")
		elif active == &"phone":
			SfxManager.play(&"ui_panel_open")
		elif active != &"":
			SfxManager.play(&"ui_tab_select")
		elif previous != &"":
			SfxManager.play(&"ui_panel_close")
	MusicManager.set_hold_duck(PHONE_DUCK_DB if active == &"phone" else 0.0)
	_refresh_music()


func _on_phone_page(page: StringName) -> void:
	_phone_page = page
	if _overlay == &"phone":
		_refresh_music()


# --- Game events ----------------------------------------------------------------

func _on_state_reset() -> void:
	# New game / load / sleep: the restored state is applied, not "earned", so no jingles.
	_quiet_until = Time.get_ticks_msec() + QUIET_AFTER_RESET_MS
	_quiet_ui_until = Time.get_ticks_msec() + QUIET_UI_AFTER_MOVE_MS
	if not _sleeping:
		MusicManager.forget_positions()
		_refresh_music()


func _on_location_changed(_id: StringName) -> void:
	_quiet_ui_until = Time.get_ticks_msec() + QUIET_UI_AFTER_MOVE_MS
	_stinger(&"travel_confirm")
	_refresh_music()


func _on_deal_closed(_amount: int, _in_person: bool) -> void:
	_stinger(&"sale_success")


func _on_stock_purchased(_product_id: String, _qty: int) -> void:
	_stinger(&"purchase")


func _on_leads_added(_count: int) -> void:
	_stinger(&"new_lead")


func _on_reputation_delta(amount: int) -> void:
	if amount > 0:
		_stinger(&"reputation_up")


func _on_task_completed(_task_id: String) -> void:
	var all_done := GameState.completed_tasks.size() >= GameData.TASKS.size()
	_stinger(&"achievement_unlocked" if all_done else &"task_complete")


## Medtycoonv2 tutorial: task_complete per step, achievement_unlocked when finished (same arbitration
## as other jingles, so a step completed by a sale is heard as the sale).
func _on_tutorial_step(final: bool) -> void:
	_stinger(&"achievement_unlocked" if final else &"task_complete")


func _on_level_up(new_level: int) -> void:
	_stinger(&"level_up")
	for loc in GameData.locations:
		if loc.unlock_level == new_level:
			# A map location just became available: follow the level-up jingle.
			get_tree().create_timer(1.6).timeout.connect(func():
				if not _quiet():
					SfxManager.play(&"location_unlocked")
					MusicManager.duck_for(-6.0, 2.0))
			break


func _on_toast(_text: String) -> void:
	# A "locked" thud already covers the toast that explains it.
	if Time.get_ticks_msec() - _locked_at < 250:
		return
	_stinger(&"notification_message")


func _play_locked() -> void:
	_locked_at = Time.get_ticks_msec()
	if _pending == &"notification_message":
		_pending = &""
	SfxManager.play(&"ui_locked")


func _on_choice_requested(_title: String, _body: String, _options: Array) -> void:
	SfxManager.play(&"ui_panel_open")


## Sleeping: music fades, end-of-day jingle, then start-of-day jingle and the location track.
func _on_day_ended(_new_day: int) -> void:
	_sleeping = true
	_pending = &""
	_quiet_until = Time.get_ticks_msec() + int(SLEEP_JINGLE_GAP * 1000.0)
	MusicManager.fade_out_all(1.5)
	SfxManager.play(&"day_end")
	get_tree().create_timer(SLEEP_JINGLE_GAP).timeout.connect(func():
		_sleeping = false
		SfxManager.play(&"day_start")
		MusicManager.forget_positions()
		_refresh_music())


# --- Jingle arbitration ------------------------------------------------------------

func _stinger(id: StringName) -> void:
	if _quiet() or not STINGERS.has(id):
		return
	if _pending == &"":
		_flush.call_deferred()
	if _pending == &"" or STINGERS[id][0] > STINGERS[_pending][0]:
		_pending = id


func _flush() -> void:
	if _pending == &"":
		return
	var id := _pending
	_pending = &""
	SfxManager.play(id)
	var duck: float = STINGERS[id][1]
	if duck < 0.0:
		MusicManager.duck_for(duck, STINGERS[id][2])


func _quiet() -> bool:
	return _sleeping or Time.get_ticks_msec() < _quiet_until


func _ui_quiet() -> bool:
	return Time.get_ticks_msec() < _quiet_ui_until


# --- Node hooks ---------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node.has_meta(&"_audio_hooked"):
		return
	if node.has_signal(&"overlay_changed"):  # Main
		node.set_meta(&"_audio_hooked", true)
		node.overlay_changed.connect(_on_overlay_changed)
		if node.is_node_ready():
			_sync_overlay(node)
		else:
			node.ready.connect(_sync_overlay.bind(node), CONNECT_ONE_SHOT)
	elif node is Phone:
		node.set_meta(&"_audio_hooked", true)
		node.page_changed.connect(_on_phone_page)
	elif node is MapPin:
		node.set_meta(&"_audio_hooked", true)
		node.chosen.connect(_on_pin_chosen.bind(node))
	elif node is Player:
		var sprite := node.get_node_or_null(^"Sprite") as AnimatedSprite2D
		if sprite:
			node.set_meta(&"_audio_hooked", true)
			sprite.frame_changed.connect(_on_player_frame.bind(sprite))
	elif node is Interactable and node.get_parent() is Shelf:
		node.set_meta(&"_audio_hooked", true)
		node.interacted.connect(_on_shelf_used.bind(node.get_parent()))
	if node is BaseButton and not node.has_meta(&"_audio_hooked"):
		node.set_meta(&"_audio_hooked", true)
		node.mouse_entered.connect(_on_button_hover.bind(node))
		if not (node is NavButton or node.get_parent() is MapPin or node.name in NO_CLICK_NAMES):
			node.pressed.connect(SfxManager.play.bind(&"ui_click"))


func _hook_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing(child)


## Adopt Main's current overlay without playing UI sounds (startup).
func _sync_overlay(main: Node) -> void:
	_overlay = main.get(&"active")
	MusicManager.set_hold_duck(PHONE_DUCK_DB if _overlay == &"phone" else 0.0, 0.0)
	_refresh_music()


func _on_button_hover(button: BaseButton) -> void:
	var now := Time.get_ticks_msec()
	if button.disabled or now - _last_hover < HOVER_INTERVAL_MS:
		return
	_last_hover = now
	SfxManager.play(&"ui_hover")


func _on_pin_chosen(location_id: StringName, _pin: MapPin) -> void:
	var loc := GameData.get_location(location_id)
	if loc and loc.unlock_level > GameState.level:
		_play_locked()
	else:
		SfxManager.play(&"map_pin_select")


func _on_shelf_used(_player: Node, shelf: Shelf) -> void:
	if shelf.is_locked():
		_play_locked()


## Footsteps on walk frames 0 and 4 of the 8-frame cycle.
func _on_player_frame(sprite: AnimatedSprite2D) -> void:
	if sprite.animation != &"walk" or not (sprite.frame == 0 or sprite.frame == 4):
		return
	if not sprite.is_visible_in_tree():
		return
	var surface: StringName = SURFACE.get(GameState.location_id, &"")
	if surface != &"":
		SfxManager.play_group(surface)
