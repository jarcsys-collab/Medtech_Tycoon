extends Node
## Responsive layout mode (autoload "Responsive").
## Picks the UI base resolution for the current window shape and emits `layout_changed` when the
## mode changes. Desktop keeps the project's 1280x720 base, so desktop rendering is unchanged.
##
##   DESKTOP           landscape, CSS height >= 600   base 1280x720 (project setting)
##   MOBILE_LANDSCAPE  landscape, CSS height <  600   base 960x540: same desktop layout, larger UI
##   MOBILE_PORTRAIT   taller than wide               base ~phone CSS width: portrait HUD layout
##
## "CSS" sizes are window pixels divided by the screen scale (devicePixelRatio on the web), so
## the decision does not depend on the user agent.

signal layout_changed(mode: Mode)

enum Mode { DESKTOP, MOBILE_LANDSCAPE, MOBILE_PORTRAIT }

const LANDSCAPE_BASE := Vector2i(960, 540)       # = Main.MIN_WINDOW: the desktop layout's minimum
const MOBILE_LANDSCAPE_MAX_HEIGHT := 600.0        # CSS px
const PORTRAIT_MIN_WIDTH := 380.0                 # logical px the portrait HUD is laid out for
const TABLET_WIDTH := 600.0                       # CSS px: wider portrait screens get a larger UI
const TABLET_UI_SCALE := 1.3

var mode := Mode.DESKTOP
var _desktop_base := Vector2i(1280, 720)


func _ready() -> void:
	_desktop_base = get_window().content_scale_size
	get_tree().root.size_changed.connect(update_responsive_layout)
	update_responsive_layout()


func is_portrait() -> bool:
	return mode == Mode.MOBILE_PORTRAIT


## Re-evaluate the layout for the current window size (window resize, rotation, fullscreen).
func update_responsive_layout() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	if px.x <= 0.0 or px.y <= 0.0:
		return
	var css := px / maxf(DisplayServer.screen_get_scale(), 1.0)
	var new_mode := Mode.DESKTOP
	var base := _desktop_base
	if css.y > css.x:
		new_mode = Mode.MOBILE_PORTRAIT
		var ui_scale := TABLET_UI_SCALE if css.x >= TABLET_WIDTH else 1.0
		var w := roundi(maxf(css.x / ui_scale, PORTRAIT_MIN_WIDTH))
		base = Vector2i(w, w)  # "expand" aspect: width is fixed, the height grows to fill the screen
	elif css.y < MOBILE_LANDSCAPE_MAX_HEIGHT:
		new_mode = Mode.MOBILE_LANDSCAPE
		base = LANDSCAPE_BASE
	if win.content_scale_size != base:
		win.content_scale_size = base
	if new_mode != mode:
		mode = new_mode
		layout_changed.emit(mode)
