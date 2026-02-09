# status_state.gd

class_name StatusState extends RefCounted

var id: String = ""
var duration: int = 0
var intensity: int = 0

func _init(_id: String = "", _duration: int = 0, _intensity: int = 0) -> void:
	id = _id
	duration = _duration
	intensity = _intensity

func clone() -> StatusState:
	return StatusState.new(id, duration, intensity)
