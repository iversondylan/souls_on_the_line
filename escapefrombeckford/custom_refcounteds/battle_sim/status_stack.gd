# status_stack.gd

class_name  StatusStack extends RefCounted
	
var id: StringName
var stacks: int = 1
var duration: int = 0 # 0 = infinite (or proc-based), you decide
var data: Dictionary = {}

func _init(_id: StringName = &"") -> void:
	id = _id

func clone() -> StatusStack:
	var s := StatusStack.new(id)
	s.stacks = stacks
	s.duration = duration
	s.data = data.duplicate(true)
	return s
