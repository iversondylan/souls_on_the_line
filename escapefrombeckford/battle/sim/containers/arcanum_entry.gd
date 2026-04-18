class_name ArcanumEntry extends RefCounted

var id: StringName
var stacks: int = -1
var data: Dictionary = {}


func _init(_id: StringName = &"") -> void:
	id = _id


func clone():
	var copied: Variant = get_script().new(id)
	copied.stacks = int(stacks)
	copied.data = data.duplicate(true)
	return copied
