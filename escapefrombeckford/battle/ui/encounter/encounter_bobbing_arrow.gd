class_name EncounterBobbingArrow extends Sprite2D

@export var bob_amplitude: float = 8.0
@export var bob_speed: float = 3.0
@export var point_offset: Vector2 = Vector2(0, -90)

var _target_screen_position: Vector2 = Vector2.ZERO
var _time: float = 0.0

func point_at(screen_position: Vector2, offset: Vector2 = point_offset) -> void:
	_target_screen_position = screen_position
	point_offset = offset
	_time = 0.0
	_update_position()
	show()

func _process(delta: float) -> void:
	_time += delta
	_update_position()

func _update_position() -> void:
	position = _target_screen_position \
		+ point_offset \
		+ Vector2(0, -bob_amplitude * cos(_time * bob_speed))
