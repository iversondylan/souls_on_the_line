# camera_rig.gd
class_name CameraRig
extends Node2D

@onready var cam: Camera2D = $Camera2D

@export var zoom_in: Vector2 = Vector2(1.07, 1.07)

# Max camera offset when focus is at the edge of the viewport (SCREEN PX),
# converted to world via zoom.
@export var max_offset_px: Vector2 = Vector2(90.0, 55.0)

@export var movement_duration: float = 0.55

@export var offset_deadzone: float = 0.06       # 0..1 (normalized). 0 disables.
@export var offset_response_power_x: float = 1.4  # >1 compresses near center, expands near edges
@export var offset_response_power_y: float = 0.75  # >1 compresses near center, expands near edges

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080))

var home_pos: Vector2
var home_zoom: Vector2

var _tween: Tween

func _ready() -> void:
	cam.make_current()
	_cache_home()
	
	## FIX ME
	#Events.fighter_entered_turn.connect(_on_fighter_entered_turn)
	Events.hand_drawn.connect(_on_hand_drawn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_cache_home()


func _cache_home() -> void:
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

func _shape_axis(x: float, response_power: float) -> float:
	# x in [-1,1]
	var a := absf(x)
	if offset_deadzone > 0.0 and a < offset_deadzone:
		return 0.0
	
	# Remove deadzone then re-normalize to [0,1]
	if offset_deadzone > 0.0:
		a = (a - offset_deadzone) / maxf(1.0 - offset_deadzone, 0.0001)
	
	# Power curve: >1 compresses small inputs near center; <1 expands them
	a = pow(a, maxf(response_power, 0.0001))
	
	return signf(x) * a


func _joystick_target_pos(focus_world: Vector2) -> Vector2:
	var half_world := _half_extents_world(home_zoom)
	var delta := focus_world - home_pos
	
	var nx := 0.0 if half_world.x <= 0.0001 else (delta.x / half_world.x)
	var ny := 0.0 if half_world.y <= 0.0001 else (delta.y / half_world.y)
	
	# Clamp to [-1,1] then shape each axis independently.
	var n := Vector2(
		_shape_axis(clampf(nx, -1.0, 1.0), offset_response_power_x),
		_shape_axis(clampf(ny, -1.0, 1.0), offset_response_power_y)
	)
	
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
	var pos_tw := _tween.tween_property(self, "global_position", target_pos, maxf(duration, 0.001))
	pos_tw.set_trans(Tween.TRANS_SINE)
	pos_tw.set_ease(Tween.EASE_OUT)
	
	var zoom_tw := _tween.parallel().tween_property(cam, "zoom", target_zoom, maxf(duration, 0.001))
	zoom_tw.set_trans(Tween.TRANS_SINE)
	zoom_tw.set_ease(Tween.EASE_OUT)


func _tween_reset() -> void:
	_kill()
	var final_pos := _clamp_center_to_bounds(home_pos, home_zoom)
	_tween_focus(final_pos, home_zoom, movement_duration)



func reset() -> void:
	_tween_reset()


func _focus_joystick(focus_world: Vector2, duration: float) -> void:
	var target_pos := _joystick_target_pos(focus_world)
	_tween_focus(target_pos, zoom_in, duration)


func _on_fighter_entered_turn(fighter: CombatantView) -> void:
	if !fighter or !is_instance_valid(fighter):
		return
	if !fighter.is_alive:
		return
	
	# Player turn: neutralize
	#if fighter is Player:
		#reset()
		#return
	
	var focus_node: Node2D = fighter.camera_focus
	if !focus_node or !is_instance_valid(focus_node):
		return
	
	_focus_joystick(focus_node.global_position, movement_duration)


func _on_hand_drawn() -> void:
	reset()
