class_name LocationBase
extends Node2D
## Base for every playable place. Expected children (all optional except for player-hosting scenes):
##   Walls (StaticBody2D)
##     WalkBounds (CollisionPolygon2D, build_mode = Segments)  -> walkable outline (Medtycoonv1 "walk")
##     <any other CollisionPolygon2D>                          -> solid blockers (Medtycoonv1 "blocks")
##   Actors (Node2D, y-sorted)       -> player + NPCs live here
##   PlayerSpawn (Marker2D)          -> Medtycoonv1 "start"
##   WanderSpots (Node2D of Marker2D)-> Medtycoonv1 "spots"
## Nodes in group "nav_obstacles" with get_nav_outline() are also carved out of the navmesh.
## Visuals: a "Background" Sprite2D gets feathered edges plus an auto-generated blurred backdrop
## that fills the screen around the room (swap the textures for final Aseprite art; no code changes).

const EDGE_FADE := preload("res://assets/shaders/edge_fade.gdshader")
const BACKDROP_BLUR := preload("res://assets/shaders/backdrop_blur.gdshader")

@export var world_size := Vector2(941, 1672)
## False for placeholder scenes (Medtycoonv1 hides the character when there is no scene).
@export var hosts_player := true
## Player outfit here: outdoor clothes everywhere except home (Sales Simulator v3).
@export var player_outdoor_outfit := true
@export var nav_agent_radius := 14.0
@export_group("Presentation")
## World-space area the GameCamera keeps framed. Empty = whole world_size.
@export var camera_focus := Rect2()
## Darkening/tint of the blurred backdrop (alpha 0 disables it).
@export var backdrop_tint := Color(0.42, 0.45, 0.5, 1.0)
@export var feather_edges := true
## Optional "Background" art from 4:30 PM (GameState.is_evening); same size and layout as the day art.
@export var evening_background: Texture2D

const TIME_FADE := 0.6

var location_data: LocationData
var nav_region: NavigationRegion2D
var _day_background: Texture2D
var _backdrop: Sprite2D

@onready var actors: Node2D = get_node_or_null("Actors")


func get_camera_focus() -> Rect2:
	return camera_focus if camera_focus.has_area() else Rect2(Vector2.ZERO, world_size)


func setup(data: LocationData, player: Player) -> void:
	location_data = data
	if not hosts_player or actors == null:
		return
	actors.add_child(player)
	player.set_outdoor(player_outdoor_outfit)
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	player.global_position = spawn.global_position if spawn else world_size / 2.0
	player.enter_location(get_wander_spots())


func _ready() -> void:
	_build_navigation()
	_build_backdrop()
	var bg := get_node_or_null("Background") as Sprite2D
	if evening_background and bg:
		_day_background = bg.texture
		GameState.stats_changed.connect(_update_time_of_day)
		_update_time_of_day(true)


## Day/evening background swap; a copy of the old art fades out on top so the change is soft.
func _update_time_of_day(instant := false) -> void:
	var bg := get_node_or_null("Background") as Sprite2D
	var want := evening_background if GameState.is_evening() else _day_background
	if bg == null or bg.texture == want:
		return
	if not instant and is_inside_tree():
		var old := bg.duplicate() as Sprite2D
		old.name = "BackgroundFadeOut"
		add_child(old)
		move_child(old, bg.get_index() + 1)
		var t := old.create_tween()
		t.tween_property(old, "modulate:a", 0.0, TIME_FADE)
		t.tween_callback(old.queue_free)
	bg.texture = want
	if _backdrop:
		_backdrop.texture = want


func _build_backdrop() -> void:
	var bg := get_node_or_null("Background") as Sprite2D
	if bg == null or bg.texture == null:
		return
	if feather_edges:
		var fade := ShaderMaterial.new()
		fade.shader = EDGE_FADE
		bg.material = fade
		# Full-size overlays cut from the same image must fade identically. An overlay with its own
		# material (e.g. the bed glow, which includes the same edge fade) keeps it.
		for child in get_children():
			if child is DepthOverlay and child.material == null and child.texture and child.texture.get_size() == bg.texture.get_size():
				child.material = fade
	if backdrop_tint.a <= 0.0:
		return
	var blur := ShaderMaterial.new()
	blur.shader = BACKDROP_BLUR
	blur.set_shader_parameter(&"tint", backdrop_tint)
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.texture = bg.texture
	backdrop.material = blur
	backdrop.z_index = -20
	backdrop.scale = Vector2.ONE * 2.6
	backdrop.position = bg.position + (bg.texture.get_size() / 2.0 if not bg.centered else Vector2.ZERO)
	add_child(backdrop)
	move_child(backdrop, 0)
	_backdrop = backdrop


func get_wander_spots(group_node := "WanderSpots") -> Array[Vector2]:
	var out: Array[Vector2] = []
	var holder := get_node_or_null(group_node)
	if holder:
		for m in holder.get_children():
			if m is Node2D:
				out.append(m.global_position)
	return out


func _build_navigation() -> void:
	var walls := get_node_or_null("Walls")
	var bounds := get_node_or_null("Walls/WalkBounds") as CollisionPolygon2D
	if walls == null or bounds == null:
		return
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_global_poly(bounds))
	for child in walls.get_children():
		if child is CollisionPolygon2D and child != bounds and not child.disabled:
			source.add_obstruction_outline(_global_poly(child))
	for node in get_tree().get_nodes_in_group(&"nav_obstacles"):
		if is_ancestor_of(node) and node.has_method("get_nav_outline"):
			source.add_obstruction_outline(node.get_nav_outline())
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = nav_agent_radius
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source)
	nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)


static func _global_poly(poly: CollisionPolygon2D) -> PackedVector2Array:
	return poly.global_transform * poly.polygon
