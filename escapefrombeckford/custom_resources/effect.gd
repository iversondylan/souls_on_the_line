# effect.gd

class_name Effect extends RefCounted

var targets: PackedInt32Array = []
var sound: Sound

func execute(_api: BattleAPI) -> void:
	pass
