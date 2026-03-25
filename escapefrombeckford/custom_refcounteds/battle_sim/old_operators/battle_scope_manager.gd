# battle_scope_manager.gd

class_name BattleScopeManager extends RefCounted

var _stack: Array[ScopeHandle] = []
var _next_scope_id: int = 1
var last_error_message: String = ""

func reset() -> void:
	_stack.clear()
	_next_scope_id = 1
	last_error_message = ""

func current_scope_id() -> int:
	return _stack.back().scope_id if _stack.size() > 0 else 0

func current_parent_scope_id() -> int:
	return _stack.back().parent_scope_id if _stack.size() > 0 else 0

func current_scope_kind() -> int:
	return _stack.back().kind if _stack.size() > 0 else -1

func push(kind: int, label: String, actor_id: int, group_index: int, turn_id: int) -> ScopeHandle:
	last_error_message = ""
	var parent := current_scope_id()
	var id := _next_scope_id
	_next_scope_id += 1
	var handle := ScopeHandle.new(id, parent, kind, label, actor_id, group_index, turn_id)
	_stack.append(handle)
	return handle

func close(handle: ScopeHandle) -> ScopeHandle:
	last_error_message = ""
	if handle == null:
		last_error_message = "BattleScopeManager.close(): null scope handle"
		return null
	if handle.is_closed:
		last_error_message = "BattleScopeManager.close(): scope handle already closed id=%d" % int(handle.scope_id)
		return null
	if _stack.is_empty():
		last_error_message = "BattleScopeManager.close(): scope stack is empty id=%d" % int(handle.scope_id)
		return null

	var top : ScopeHandle = _stack.back()
	if top != handle:
		last_error_message = "BattleScopeManager.close(): non-top scope close attempted expected_top=%d got=%d" % [
			int(top.scope_id),
			int(handle.scope_id),
		]
		return null
	if int(top.scope_id) != int(handle.scope_id) or int(top.kind) != int(handle.kind):
		last_error_message = "BattleScopeManager.close(): scope handle mismatch top_id=%d handle_id=%d top_kind=%d handle_kind=%d" % [
			int(top.scope_id),
			int(handle.scope_id),
			int(top.kind),
			int(handle.kind),
		]
		return null

	_stack.pop_back()
	handle.is_closed = true
	return handle

func depth() -> int:
	return _stack.size()
