# effect.gd

class_name Effect extends RefCounted

var targets: Array[Fighter]
var sound: Sound

func execute(_api: BattleAPI) -> void:
	pass
