# event_package.gd

class_name EventPackage extends RefCounted

var event: BattleEvent
var duration: float = 0.0: set = _set_duration
var d0: float = 0.0: set = _set_d0
var is_planned: bool = false


func _set_duration(_new: float) -> void:
	duration = clampf(_new, 0.0, 5.0)

func _set_d0(_new: float) -> void:
	d0 = clampf(_new, 0.0, 1.0)
