# scope_handle.gd

class_name ScopeHandle extends RefCounted

var scope_id: int = 0
var parent_scope_id: int = 0
var kind: int = -1
var label: String = ""
var actor_id: int = 0
var group_index: int = -1
var turn_id: int = 0
var is_closed: bool = false

func _init(_scope_id: int = 0, _parent_scope_id: int = 0, _kind: int = -1, _label: String = "", _actor_id: int = 0, _group_index: int = -1, _turn_id: int = 0) -> void:
	scope_id = _scope_id
	parent_scope_id = _parent_scope_id
	kind = _kind
	label = _label
	actor_id = _actor_id
	group_index = _group_index
	turn_id = _turn_id
