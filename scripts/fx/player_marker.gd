class_name PlayerMarker
extends Node2D
## Small pixel-art chevron above the player's head, so the player stands out from café customers
## who share the outdoor sprite. Child of the Player scene only. Constant on-screen size (like
## InteractionMarker), gentle bob, and it fades out while the player is next to something usable,
## where the [E] badge and customer bubbles take that space.

const FILL := Color("#7ed8f7")      # "active cyan" from the Sales Simulator palette
const OUTLINE := Color("#0b1211")   # panel colour, used as the pixel outline
const PIXEL := 3.0                  # on-screen px per art pixel
const BOB := 2.5
const FADE_SPEED := 8.0
## Down-pointing chevron, 9x5 art pixels.
const SHAPE := [
	"XX.....XX",
	".XX...XX.",
	"..XX.XX..",
	"...XXX...",
	"....X....",
]

## Set by the player: true while an interaction target is in reach.
var suppressed := false
var _t := 0.0
var _alpha := 1.0
var _cells: Array[Vector2i] = []


func _ready() -> void:
	for y in SHAPE.size():
		for x in SHAPE[y].length():
			if SHAPE[y][x] == "X":
				_cells.append(Vector2i(x, y))


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, 0.0 if suppressed else 1.0, delta * FADE_SPEED)
	visible = _alpha > 0.01
	if not visible:
		return
	modulate.a = _alpha
	var cam := get_viewport().get_camera_2d()
	var inv := 1.0 / cam.zoom.x if cam else 1.0
	scale = Vector2.ONE * inv
	queue_redraw()


func _draw() -> void:
	var w := SHAPE[0].length()
	var h := SHAPE.size()
	# Bottom tip at the node origin, bob in whole art pixels so it stays crisp.
	var bob := roundf(sin(_t * 3.0) * BOB / PIXEL) * PIXEL
	var origin := Vector2(-w * PIXEL / 2.0, -h * PIXEL + bob)
	for c in _cells:
		draw_rect(Rect2(origin + Vector2(c) * PIXEL - Vector2.ONE * PIXEL, Vector2.ONE * PIXEL * 3.0), OUTLINE)
	for c in _cells:
		draw_rect(Rect2(origin + Vector2(c) * PIXEL, Vector2.ONE * PIXEL), FILL)
