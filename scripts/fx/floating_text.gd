class_name FloatingText
extends Node2D
## World-anchored "+$161" / "+40 XP" popup. Rises and fades; constant on-screen size.

const FONT := preload("res://assets/fonts/PixelifySansMedTycoon-Bold.ttf")
const FONT_SIZE := 24
const RISE := 64.0
const LIFETIME := 1.3

var text := ""
var color := Color.WHITE
var _age := 0.0
var _origin := Vector2.ZERO


static func spawn(parent: Node, world_pos: Vector2, label: String, tint: Color) -> FloatingText:
	var ft := FloatingText.new()
	ft.text = label
	ft.color = tint
	parent.add_child(ft)
	ft._origin = world_pos
	ft.global_position = world_pos
	return ft


func _ready() -> void:
	z_index = 110
	z_as_relative = false


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var cam := get_viewport().get_camera_2d()
	var inv := 1.0 / cam.zoom.x if cam else 1.0
	var t := _age / LIFETIME
	var pop := minf(_age / 0.15, 1.0)
	scale = Vector2.ONE * inv * (0.7 + 0.3 * ease(pop, 0.4))
	global_position = _origin - Vector2(0, RISE * ease(t, 0.5) * inv)
	modulate.a = 1.0 - smoothstep(0.65, 1.0, t)
	queue_redraw()


func _draw() -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := Vector2(-w / 2.0, 0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 8, Color(0.03, 0.05, 0.05, 0.9))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
