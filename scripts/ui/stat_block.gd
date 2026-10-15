@tool
class_name StatBlock
extends HBoxContainer
## Icon + caption + value (top-bar stat: DAY / CASH / REPUTATION / LEADS). Pulses when the value changes.

@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			_apply()
@export var icon_size := Vector2(30, 30):
	set(v):
		icon_size = v
		if is_node_ready():
			_apply()
@export var caption := "CAPTION":
	set(v):
		caption = v
		if is_node_ready():
			$Text/Caption.text = v
@export var value := "0":
	set(v):
		var changed := v != value
		value = v
		if is_node_ready():
			$Text/Value.text = v
			if changed and not Engine.is_editor_hint() and is_visible_in_tree():
				UIAnim.pulse($Text/Value, 1.1)


func _ready() -> void:
	_apply()
	$Text/Caption.text = caption
	$Text/Value.text = value


func _apply() -> void:
	$Icon.texture = icon
	$Icon.custom_minimum_size = icon_size
	$Icon.visible = icon != null
