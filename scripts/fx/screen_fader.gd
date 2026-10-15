class_name ScreenFader
extends CanvasLayer
## Full-screen fade used for location changes, new game and loading. Blocks clicks while covering.

@onready var _rect: ColorRect = $Rect

var _tween: Tween


func _ready() -> void:
	layer = 100
	_rect.color = Color(0.02, 0.03, 0.035, 1.0)
	_rect.modulate.a = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP


## Tween to `alpha` (0 = clear, 1 = black). Await the returned signal.
func fade_to(alpha: float, duration: float) -> Signal:
	if _tween:
		_tween.kill()
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE)
	if alpha <= 0.0:
		_tween.tween_callback(func(): _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	return _tween.finished


func is_covering() -> bool:
	return _rect.modulate.a > 0.01
