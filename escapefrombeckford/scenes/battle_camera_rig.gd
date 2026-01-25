# camera_rig.gd
class_name CameraRig
extends Node2D

@onready var cam: Camera2D = $Camera2D

var home_pos: Vector2
var home_zoom: Vector2

var _tween: Tween

func _ready() -> void:
	cam.make_current()
	_cache_home_from_viewport_center()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_cache_home_from_viewport_center()

func _cache_home_from_viewport_center() -> void:
	home_pos = cam.get_screen_center_position()
	home_zoom = cam.zoom

func focus_to(world_pos: Vector2, zoom: Vector2, duration: float = 0.25) -> void:
	_kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "global_position", world_pos, duration)
	_tween.parallel().tween_property(cam, "zoom", zoom, duration)

func reset(duration: float = 0.25) -> void:
	focus_to(home_pos, home_zoom, duration)

func _kill() -> void:
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
