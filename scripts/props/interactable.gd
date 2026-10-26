class_name Interactable
extends Area2D
## Something the player can use with the E key. Add a CollisionShape2D child for its reach area.
## Either connect to `interacted` or extend this script and override `interact()`.

signal interacted(player: Node)

const LAYER_INTERACTABLE := 4  # physics layer 3

@export var prompt := "Interact"
@export var enabled := true
@export_group("Presentation")
## CanvasItem that lights up while this is the player's target. With a ShaderMaterial that has a
## `highlight` uniform it glows; otherwise it gently pulses brighter.
@export var highlight_path: NodePath
## Where the floating [E] badge sits, relative to this node.
@export var marker_offset := Vector2(0, -90)

var _highlight_tween: Tween


func _init() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact() -> bool:
	return enabled


func get_prompt() -> String:
	return prompt


func interact(player: Node) -> void:
	interacted.emit(player)


func get_marker_position() -> Vector2:
	return global_position + marker_offset


## True when a world point lands on this object's artwork: the opaque pixels of its highlight
## sprite (e.g. the bed cut-out). Lets a tap anywhere on a large object pick it, not only near
## its reach area. Objects without a Sprite2D highlight return false.
func is_on_artwork(point: Vector2) -> bool:
	var art := get_node_or_null(highlight_path) as Sprite2D
	return art != null and art.is_visible_in_tree() and art.is_pixel_opaque(art.to_local(point))


func set_highlighted(on: bool) -> void:
	var target := get_node_or_null(highlight_path) as CanvasItem
	if target == null:
		return
	if _highlight_tween:
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	var mat := target.material as ShaderMaterial
	if _has_highlight_uniform(mat):
		_highlight_tween.tween_property(mat, "shader_parameter/highlight", 1.0 if on else 0.0, 0.15)
	elif on:
		_highlight_tween.set_loops()
		_highlight_tween.tween_property(target, "self_modulate", Color(1.22, 1.18, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
		_highlight_tween.tween_property(target, "self_modulate", Color(1.06, 1.05, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	else:
		_highlight_tween.tween_property(target, "self_modulate", Color.WHITE, 0.15)


static func _has_highlight_uniform(mat: ShaderMaterial) -> bool:
	if mat == null or mat.shader == null:
		return false
	for u in mat.shader.get_shader_uniform_list():
		if u.name == "highlight":
			return true
	return false
