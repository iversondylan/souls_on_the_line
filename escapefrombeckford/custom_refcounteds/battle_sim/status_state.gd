# status_state.gd
class_name StatusState extends RefCounted



# status_id -> StatusStack
var by_id: Dictionary = {}  # StringName -> StatusStack

func has(id: StringName) -> bool:
	return by_id.has(id)

func get_status_stack(id: StringName) -> StatusStack:
	return by_id.get(id, null)

func add_or_reapply(id: StringName, intensity: int, duration: int = 0) -> void:
	#print("status_state.gd add_or_reapply() id: %s, intensity: %s, duration: %s" % [id, intensity_delta, duration])
	if id == &"":
		return
	
	var s: StatusStack = by_id.get(id, null)
	if s == null:
		s = StatusStack.new(id)
		s.intensity = maxi(intensity, 1)
		s.duration = duration
		by_id[id] = s
	else:
		s.intensity = maxi(s.intensity + intensity, 0)
		# duration policy: take max, or overwrite if nonzero—choose one.
		if duration > 0:
			s.duration = max(s.duration + duration, 0)
		#if s.intensity <= 0:
			#by_id.erase(id)
	#print("status_state.gd add_or_reapply() stack intensity: %s, duration: %s" % [by_id[id].intensity, by_id[id].duration])

func remove(id: StringName, remove_all: bool = true, intensity: int = 1) -> void:
	if !by_id.has(id):
		return
	if remove_all:
		by_id.erase(id)
		return
	var s: StatusStack = by_id[id]
	s.intensity = maxi(s.intensity - maxi(int(intensity), 1), 0)
	if s.intensity <= 0:
		by_id.erase(id)

func clone() -> StatusState:
	var st := StatusState.new()
	for k in by_id.keys():
		var s: StatusStack = by_id[k]
		if s:
			st.by_id[k] = s.clone()
	return st
