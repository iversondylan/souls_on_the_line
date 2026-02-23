# status_state.gd
class_name StatusState extends RefCounted

class StatusStack extends RefCounted:
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

# status_id -> StatusStack
var by_id: Dictionary = {}  # StringName -> StatusStack

func has(id: StringName) -> bool:
	return by_id.has(id)

func get_status_stack(id: StringName) -> StatusStack:
	return by_id.get(id, null)

func add_or_reapply(id: StringName, stacks_delta: int, duration: int = 0) -> void:
	if id == &"":
		return
	stacks_delta = int(stacks_delta)
	duration = int(duration)

	var s: StatusStack = by_id.get(id, null)
	if s == null:
		s = StatusStack.new(id)
		s.stacks = maxi(stacks_delta, 1)
		s.duration = duration
		by_id[id] = s
	else:
		s.stacks = maxi(s.stacks + stacks_delta, 0)
		# duration policy: take max, or overwrite if nonzero—choose one.
		if duration > 0:
			s.duration = max(s.duration, duration)
		if s.stacks <= 0:
			by_id.erase(id)

func remove(id: StringName, remove_all: bool = true, stacks_delta: int = 1) -> void:
	if !by_id.has(id):
		return
	if remove_all:
		by_id.erase(id)
		return
	var s: StatusStack = by_id[id]
	s.stacks = maxi(s.stacks - maxi(int(stacks_delta), 1), 0)
	if s.stacks <= 0:
		by_id.erase(id)

func clone() -> StatusState:
	var st := StatusState.new()
	for k in by_id.keys():
		var s: StatusStack = by_id[k]
		if s:
			st.by_id[k] = s.clone()
	return st
