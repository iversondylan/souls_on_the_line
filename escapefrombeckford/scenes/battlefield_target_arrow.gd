# battlefield_target_arrow.gd
class_name BattlefieldTargetArrow
extends Sprite2D

@export var drop_height := 200.0
@export var bob_amplitude := 8.0
@export var bob_speed := 3.0

var _base_pos: Vector2
var _last_base_pos: Vector2 = Vector2.INF
var _time := 0.0
var _active := false

func show_at(pos: Vector2):
	# If we're already showing at this slot, do nothing
	if _active and pos == _last_base_pos:
		return
	
	_last_base_pos = pos
	_base_pos = pos
	_time = 0.0
	_active = true
	show()


func _process(delta: float) -> void:
	if !_active:
		return
	
	_time += delta
	
	var y := -drop_height - bob_amplitude * cos(_time * bob_speed)
	global_position = _base_pos + Vector2(0, y)

func hide_arrow():
	_active = false
	_last_base_pos = Vector2.INF
	hide()
