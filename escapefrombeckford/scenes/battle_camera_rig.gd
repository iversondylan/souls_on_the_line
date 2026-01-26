# camera_rig.gd
class_name CameraRig
extends Node2D

@onready var cam: Camera2D = $Camera2D

# Godot 4: > 1.0 zooms IN (objects appear larger)
@export var zoom_in: Vector2 = Vector2(1.07, 1.07)

# Max camera offset when focus is at the edge of the viewport (SCREEN PX),
# converted to world via zoom.
@export var max_offset_px: Vector2 = Vector2(90.0, 55.0)

@export var zoom_in_duration: float = 0.35

# Reset feel
@export var reset_duration: float = 0.34
@export var reset_zoom_delay: float = 0.01  # small, keeps edges safer but still feels synced

# Joystick shaping: bigger -> smaller movement near center, more reserved for far targets
@export var offset_deadzone: float = 0.06       # 0..1 (normalized). 0 disables.
@export var offset_response_power: float = 1.7  # >1 compresses near center, expands near edges

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080))

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
	var half_px := _viewport_size() * 0.5
	return Vector2(
		half_px.x / maxf(at_zoom.x, 0.0001),
		half_px.y / maxf(at_zoom.y, 0.0001)
	)


func _kill() -> void:
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _clamp_center_to_bounds(center: Vector2, at_zoom: Vector2) -> Vector2:
	var half := _half_extents_world(at_zoom)

	var min_c := world_bounds.position + half
	var max_c := world_bounds.position + world_bounds.size - half

	if max_c.x < min_c.x:
		center.x = (min_c.x + max_c.x) * 0.5
	else:
		center.x = clampf(center.x, min_c.x, max_c.x)

	if max_c.y < min_c.y:
		center.y = (min_c.y + max_c.y) * 0.5
	else:
		center.y = clampf(center.y, min_c.y, max_c.y)

	return center


# ------------------------------------------------------------
# Joystick math (small near center, big near edges)
# ------------------------------------------------------------

func _shape_axis(x: float) -> float:
	# x in [-1,1]
	var a := absf(x)
	if offset_deadzone > 0.0 and a < offset_deadzone:
		return 0.0

	# Remove deadzone then re-normalize to [0,1]
	if offset_deadzone > 0.0:
		a = (a - offset_deadzone) / maxf(1.0 - offset_deadzone, 0.0001)

	# Power curve: >1 compresses small inputs near center
	a = pow(a, maxf(offset_response_power, 0.0001))

	return signf(x) * a


func _joystick_target_pos(focus_world: Vector2) -> Vector2:
	# Normalize focus vector in terms of "how close to the edge of the viewport"
	# using the HOME zoom's view extents.
	var half_world := _half_extents_world(home_zoom)
	var delta := focus_world - home_pos

	var nx := 0.0 if half_world.x <= 0.0001 else (delta.x / half_world.x)
	var ny := 0.0 if half_world.y <= 0.0001 else (delta.y / half_world.y)

	# Clamp to [-1,1] then shape it so near-center moves are smaller.
	var n := Vector2(
		_shape_axis(clampf(nx, -1.0, 1.0)),
		_shape_axis(clampf(ny, -1.0, 1.0))
	)

	# Convert max_offset from screen px to world units using HOME zoom.
	var max_offset_world := Vector2(
		max_offset_px.x / maxf(home_zoom.x, 0.0001),
		max_offset_px.y / maxf(home_zoom.y, 0.0001)
	)

	var target := home_pos + (n * max_offset_world)
	return _clamp_center_to_bounds(target, zoom_in)


# ------------------------------------------------------------
# Tween helpers
# ------------------------------------------------------------

func _tween_focus(target_pos: Vector2, target_zoom: Vector2, duration: float) -> void:
	_kill()
	_tween = create_tween()

	# Pan + zoom together for focus
	var pos_tw := _tween.tween_property(cam, "global_position", target_pos, maxf(duration, 0.001))
	pos_tw.set_trans(Tween.TRANS_SINE)
	pos_tw.set_ease(Tween.EASE_OUT)

	var zoom_tw := _tween.parallel().tween_property(cam, "zoom", target_zoom, maxf(duration, 0.001))
	zoom_tw.set_trans(Tween.TRANS_SINE)
	zoom_tw.set_ease(Tween.EASE_OUT)


func _tween_reset_synced() -> void:
	_kill()
	_tween = create_tween()

	# We want the reset to feel like one motion.
	# To avoid edge-peeking, we "favor" the smaller view while beginning the pan:
	# - pan target is clamped at zoom_in (safe while view is tight)
	# - zoom-out starts shortly after pan begins (tiny delay)
	var pan_target := _clamp_center_to_bounds(home_pos, zoom_in)
	var final_pos := _clamp_center_to_bounds(pan_target, home_zoom)

	#var pos_tw := _tween.tween_property(self, "global_position", pan_target, maxf(reset_duration, 0.001))
	#pos_tw.set_trans(Tween.TRANS_QUAD)
	#pos_tw.set_ease(Tween.EASE_IN)

	# Zoom-out starts slightly after pan begins, but overlaps heavily -> feels synchronized
	var zoom_tw := _tween.parallel().tween_property(cam, "zoom", home_zoom, maxf(reset_duration*1.5, 0.001))
	#zoom_tw.set_delay(maxf(reset_zoom_delay, 0.0))
	zoom_tw.set_trans(Tween.TRANS_SINE)
	zoom_tw.set_ease(Tween.EASE_OUT)

	# While zooming out, ease position from pan_target toward final_pos (clamped for larger view)
	var final_pos_tw := _tween.parallel().tween_property(cam, "global_position", final_pos, maxf(reset_duration, 0.001))
	#final_pos_tw.set_delay(maxf(reset_zoom_delay, 0.0))
	final_pos_tw.set_trans(Tween.TRANS_SINE)
	final_pos_tw.set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------
# Public-ish API
# ------------------------------------------------------------

func reset() -> void:
	_tween_reset_synced()


func _focus_joystick(focus_world: Vector2, duration: float) -> void:
	var target_pos := _joystick_target_pos(focus_world)
	_tween_focus(target_pos, zoom_in, duration)


# ------------------------------------------------------------
# Event hooks
# ------------------------------------------------------------

func _on_fighter_entered_turn(fighter: Fighter) -> void:
	if !fighter or !is_instance_valid(fighter):
		return
	if !fighter.is_alive():
		return

	# Player turn: neutralize
	if fighter is Player:
		reset()
		return

	var focus_node: Node2D = fighter.camera_focus
	if !focus_node or !is_instance_valid(focus_node):
		return

	_focus_joystick(focus_node.global_position, zoom_in_duration)


func _on_hand_drawn() -> void:
	reset()
