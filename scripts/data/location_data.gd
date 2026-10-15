class_name LocationData
extends Resource
## A travel destination on the city map. One .tres per place lives in res://data/locations/.

@export var id: StringName
@export var display_name := ""
@export var district := ""
@export_multiline var description := ""
## Pin position on the city map, in the 941x1672 map image space.
@export var map_position := Vector2.ZERO
@export var travel_minutes := 0
@export var fare := 0
@export var unlock_level := 1
## Playable scene for this place. Empty = "SCENE COMING SOON" placeholder.
@export_file("*.tscn") var scene_path := ""
## Order on the map / lists.
@export var sort_order := 0
