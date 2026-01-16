# card_resolved_targets.gd
class_name CardResolvedTarget extends RefCounted

var fighters: Array[Fighter] = []
var areas: Array[Area2D] = []
var insert_index: int = -1
var is_battlefield: bool = false
