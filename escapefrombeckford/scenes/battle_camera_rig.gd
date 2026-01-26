# camera_rig.gd
class_name CameraRig
extends Node2D

@onready var cam: Camera2D = $Camera2D

# Godot 4: > 1.0 zooms IN (subtle)
@export var zoom_in: Vector2 = Vector2(1.02, 1.02)

# "Joystick" feel: maximum camera offset when focus is at the edge of the viewport.
# This is in SCREEN PIXELS, then converted to world-space using zoom.
@export var max_offset_px: Vector2 = Vector2(90.0, 55.0)

@export var zoom_in_duration: float = 0.18
#@export var zoom_out_duration: float = 0.22
@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080))

# Add these exports near your other timings
@export var pan_out_duration: float = 0.16      # how fast the center recenters
@export var zoom_out_delay: float = 0.10        # wait before starting zoom-out
@export var zoom_out_duration: float = 0.28     # (you already have this; consider a tad slower)

# If your background is exactly 1920x1080 world units and starts at (0,0), this is correct.
var home_pos: Vector2
var home_zoom: Vector2

var _tween: Tween


func _ready() -> void:
	cam.make_current()
	_cache_home()

	Events.fighter_entered_turn.connect(_on_fighter_entered_turn)
	Events.hand_drawn.connect(_on_hand_drawn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_cache_home()


func _cache_home() -> void:
	# In your setup, the rig sits at the intended "home" world center.
	home_pos = global_position
	home_zoom = cam.zoom


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _half_extents_world(at_zoom: Vector2) -> Vector2:
	# Approx: 1 world unit == 1 pixel in your 2D setup; camera zoom scales world->screen.
	# Half of viewport in pixels, converted into world units by dividing by zoom.
	var half_px := _viewport_size() * 0.5
	return Vector2(
		half_px.x / maxf(at_zoom.x, 0.0001),
		half_px.y / maxf(at_zoom.y, 0.0001)
	)


func _kill() -> void:
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _tween_to(pos: Vector2, zoom: Vector2, duration: float) -> void:
	_kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "global_position", pos, duration)
	_tween.parallel().tween_property(cam, "zoom", zoom, duration)


func reset(_duration_unused: float = 0.25) -> void:
	_tween_reset_lagged()



func _focus_joystick(focus_world: Vector2, duration: float) -> void:
	# Use a fixed zoom (zoom_in), and only bias position from home based on focus distance.
	var half_world := _half_extents_world(home_zoom)

	# Vector from home center to focus, expressed as a fraction of the view half-extents.
	var delta := focus_world - home_pos
	var nx := 0.0 if half_world.x <= 0.0001 else (delta.x / half_world.x)
	var ny := 0.0 if half_world.y <= 0.0001 else (delta.y / half_world.y)

	# Clamp so "edge of viewport" => magnitude 1.0 on that axis.
	var n := Vector2(clampf(nx, -1.0, 1.0), clampf(ny, -1.0, 1.0))

	# Convert max_offset_px (screen) to world offset at current zoom.
	var max_offset_world := Vector2(
		max_offset_px.x / maxf(home_zoom.x, 0.0001),
		max_offset_px.y / maxf(home_zoom.y, 0.0001)
	)

	var target_pos := home_pos + (n * max_offset_world)

	# Clamp so the camera view never goes past the background
	target_pos = _clamp_center_to_bounds(target_pos, zoom_in)

	_tween_to(target_pos, zoom_in, duration)


func _on_fighter_entered_turn(fighter: Fighter) -> void:
	if !fighter or !is_instance_valid(fighter):
		return
	if !fighter.is_alive():
		return

	# Player turn: your choice to "neutralize" camera feel.
	if fighter is Player:
		reset(zoom_out_duration)
		return

	var focus_node: Node2D = fighter.camera_focus
	if !focus_node or !is_instance_valid(focus_node):
		return

	_focus_joystick(focus_node.global_position, zoom_in_duration)


func _on_hand_drawn() -> void:
	# Your "player turn visual reset"
	reset(zoom_out_duration)

func _clamp_center_to_bounds(center: Vector2, at_zoom: Vector2) -> Vector2:
	var half := _half_extents_world(at_zoom)

	# Camera center must stay within [min+half, max-half]
	var min_c := world_bounds.position + half
	var max_c := world_bounds.position + world_bounds.size - half

	# If bounds are too small for the zoom (half bigger than rect), avoid flipping min/max
	if max_c.x < min_c.x:
		center.x = (min_c.x + max_c.x) * 0.5
	else:
		center.x = clampf(center.x, min_c.x, max_c.x)

	if max_c.y < min_c.y:
		center.y = (min_c.y + max_c.y) * 0.5
	else:
		center.y = clampf(center.y, min_c.y, max_c.y)

	return center

func _tween_reset_lagged() -> void:
	_kill()

	# Important: clamp using the SMALLER view (zoom_in) for the pan phase,
	# so we don't reveal edges while sliding back home.
	var pan_target := _clamp_center_to_bounds(home_pos, zoom_in)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	# 1) Pan first (or mostly first)
	_tween.tween_property(self, "global_position", pan_target, maxf(pan_out_duration, 0.001))

	# 2) Then zoom out AFTER a delay (lag)
	_tween.tween_interval(maxf(zoom_out_delay, 0.0))

	# Clamp again for the final zoom-out state (view gets larger)
	var final_pos := _clamp_center_to_bounds(pan_target, home_zoom)

	_tween.tween_property(cam, "zoom", home_zoom, maxf(zoom_out_duration, 0.001))
	_tween.parallel().tween_property(self, "global_position", final_pos, maxf(zoom_out_duration, 0.001))
