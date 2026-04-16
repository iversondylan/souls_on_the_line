class_name StatusStackBucket extends RefCounted

var realized_stack: StatusStack = null
var pending_stack: StatusStack = null


func has(pending := false) -> bool:
	return get_status_stack(bool(pending)) != null


func has_any() -> bool:
	return realized_stack != null or pending_stack != null


func is_empty() -> bool:
	return !has_any()


func get_status_stack(pending := false) -> StatusStack:
	return pending_stack if bool(pending) else realized_stack


func set_status_stack(stack: StatusStack, pending := false) -> void:
	if bool(pending):
		pending_stack = stack
		return
	realized_stack = stack


func erase(pending := false) -> void:
	if bool(pending):
		pending_stack = null
		return
	realized_stack = null


func get_stacks(include_pending := true) -> Array[StatusStack]:
	var out: Array[StatusStack] = []
	if realized_stack != null:
		out.append(realized_stack)
	if bool(include_pending) and pending_stack != null:
		out.append(pending_stack)
	return out


func clone():
	var copied = get_script().new()
	if realized_stack != null:
		copied.realized_stack = realized_stack.clone()
	if pending_stack != null:
		copied.pending_stack = pending_stack.clone()
	return copied
