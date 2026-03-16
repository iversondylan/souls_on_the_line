# battle_scope_manager.gd

class_name BattleScopeManager extends RefCounted

class ScopeFrame extends RefCounted:
	var id: int = 0
	var parent_id: int = 0
	var kind: int = -1
	var label: String = ""
	var actor_id: int = 0
	var group_index: int = -1
	var turn_id: int = 0

	func _init(_id: int, _parent: int, _kind: int, _label: String, _actor_id: int, _group: int, _turn_id: int) -> void:
		id = _id
		parent_id = _parent
		kind = _kind
		label = _label
		actor_id = _actor_id
		group_index = _group
		turn_id = _turn_id

var _stack: Array[ScopeFrame] = []
var _next_scope_id: int = 1

func reset() -> void:
	_stack.clear()
	_next_scope_id = 1

func current_scope_id() -> int:
	return _stack.back().id if _stack.size() > 0 else 0

func current_parent_scope_id() -> int:
	return _stack.back().parent_id if _stack.size() > 0 else 0

func current_scope_kind() -> int:
	return _stack.back().kind if _stack.size() > 0 else -1

func push(kind: int, label: String, actor_id: int, group_index: int, turn_id: int) -> ScopeFrame:
	var parent := current_scope_id()
	var id := _next_scope_id
	_next_scope_id += 1
	var f := ScopeFrame.new(id, parent, kind, label, actor_id, group_index, turn_id)
	_stack.append(f)
	return f

func pop() -> ScopeFrame:
	if _stack.is_empty():
		return null
	return _stack.pop_back()

func depth() -> int:
	return _stack.size()
