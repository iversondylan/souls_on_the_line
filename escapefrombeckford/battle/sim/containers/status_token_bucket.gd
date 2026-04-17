class_name StatusTokenBucket extends RefCounted

const StatusToken := preload("res://battle/sim/containers/status_token.gd")

var realized_token: StatusToken = null
var pending_token: StatusToken = null


func has(pending := false) -> bool:
	return get_status_token(bool(pending)) != null


func has_any() -> bool:
	return realized_token != null or pending_token != null


func is_empty() -> bool:
	return !has_any()


func get_status_token(pending := false) -> StatusToken:
	return pending_token if bool(pending) else realized_token


func set_status_token(token: StatusToken, pending := false) -> void:
	if bool(pending):
		pending_token = token
		return
	realized_token = token


func erase(pending := false) -> void:
	if bool(pending):
		pending_token = null
		return
	realized_token = null


func get_tokens(include_pending := true) -> Array[StatusToken]:
	var out: Array[StatusToken] = []
	if realized_token != null:
		out.append(realized_token)
	if bool(include_pending) and pending_token != null:
		out.append(pending_token)
	return out


func clone():
	var copied: Variant = get_script().new()
	if realized_token != null:
		copied.realized_token = realized_token.clone()
	if pending_token != null:
		copied.pending_token = pending_token.clone()
	return copied
