class_name DepthOverlay
extends Sprite2D
## A foreground cut-out of the background art (e.g. the bed) with a sloped "front line".
## Actors whose feet are above the line are drawn behind it; below it, in front.
## Native version of Medtycoonv1's bed-layer + frontY() trick.

const Z_BEHIND := 0
const Z_IN_FRONT := 2

## Polyline in local coordinates, sorted by x.
@export var front_line := PackedVector2Array()
@export var actor_group := &"actors"


func _ready() -> void:
	z_index = 1


func _process(_delta: float) -> void:
	for actor in get_tree().get_nodes_in_group(actor_group):
		if actor is Node2D:
			actor.z_index = Z_BEHIND if is_behind(to_local(actor.global_position)) else Z_IN_FRONT


func is_behind(p: Vector2) -> bool:
	var fy := front_y(p.x)
	return fy >= 0.0 and p.y < fy


func front_y(x: float) -> float:
	var f := front_line
	if f.size() < 2 or x < f[0].x or x > f[f.size() - 1].x:
		return -1.0
	for i in f.size() - 1:
		var a := f[i]
		var b := f[i + 1]
		if x >= a.x and x <= b.x:
			var span := maxf(b.x - a.x, 0.001)
			return lerpf(a.y, b.y, (x - a.x) / span)
	return -1.0
