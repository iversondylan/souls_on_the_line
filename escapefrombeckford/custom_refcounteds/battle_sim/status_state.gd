# status_state.gd

class_name StatusState extends RefCounted

# status_id -> StatusStack
var by_id: Dictionary = {}  # StringName -> StatusStack

func has(id: StringName) -> bool:
	return by_id.has(id)

func get_status_stack(id: StringName) -> StatusStack:
	return by_id.get(id, null)
