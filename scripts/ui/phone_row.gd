@tool
class_name PhoneRow
extends Button
## Sales Phone menu row: icon, title, subtitle, chevron. Emits `chosen(id)`.

signal chosen(id: StringName)

@export var id: StringName
@export var title := "Title":
	set(v):
		title = v
		if is_node_ready():
			$Row/Text/Title.text = v
@export var subtitle := "":
	set(v):
		subtitle = v
		if is_node_ready():
			$Row/Text/Sub.text = v
@export var row_icon: Texture2D:
	set(v):
		row_icon = v
		if is_node_ready():
			$Row/Icon.texture = v


func _ready() -> void:
	$Row/Text/Title.text = title
	$Row/Text/Sub.text = subtitle
	$Row/Icon.texture = row_icon
	pressed.connect(func(): chosen.emit(id))
