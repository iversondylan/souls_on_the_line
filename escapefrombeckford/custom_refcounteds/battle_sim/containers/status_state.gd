# status_state.gd
class_name StatusState extends RefCounted

var by_id: Dictionary = {}  # StringName -> StatusStack

func has(id: StringName) -> bool:
	return by_id.has(id)

func get_status_stack(id: StringName) -> StatusStack:
	return by_id.get(id, null)

# Convenience wrapper (keeps old callsites alive)
func add_or_reapply(id: StringName, intensity: int, duration: int = 0) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	ctx.intensity = intensity
	ctx.duration = duration
	add_or_reapply_ctx(ctx)

# New canonical path: determines APPLY vs CHANGE and populates ctx
func add_or_reapply_ctx(ctx: StatusContext) -> bool:
	if ctx == null:
		return false
	var id := ctx.status_id
	if id == &"":
		return false

	var req_i := int(ctx.intensity)
	var req_d := int(ctx.duration)

	var existed := by_id.has(id)
	var s: StatusStack = by_id.get(id, null)

	var before_i := 0
	var before_d := 0

	if s == null:
		s = StatusStack.new(id)
	else:
		before_i = int(s.intensity)
		before_d = int(s.duration)

	ctx.before_intensity = before_i
	ctx.before_duration = before_d

	if !existed:
		# APPLY semantics: create new stack
		# intensity policy: must be at least 1 on create
		var new_i := maxi(req_i, 1)
		var new_d := req_d

		s.intensity = new_i
		s.duration = new_d
		by_id[id] = s

		ctx.op = Status.OP.APPLY
		ctx.delta_intensity = new_i - before_i
		ctx.delta_duration = new_d - before_d

		ctx.after_intensity = int(s.intensity)
		ctx.after_duration = int(s.duration)

		return true

	# CHANGE semantics: modify existing stack
	# intensity policy: additive, clamped at 0
	var new_intensity := maxi(before_i + req_i, 0)
	s.intensity = new_intensity

	# duration policy: you currently do "if duration>0: add; else unchanged"
	# (you also clamp to >=0)
	var new_duration := before_d
	if req_d != 0:
		new_duration = max(before_d + req_d, 0)
	s.duration = new_duration

	# Optional: if you want intensity <=0 to remove, do it here.
	# If you keep your current approach, skip.
	# if s.intensity <= 0:
	#     by_id.erase(id)

	var di := int(s.intensity) - before_i
	var dd := int(s.duration) - before_d

	# If nothing changed, keep it CHANGE but mark applied=false upstream if you want.
	# I’d still mark op=CHANGE; the API can decide to emit or not emit.
	ctx.op = Status.OP.CHANGE
	ctx.delta_intensity = di
	ctx.delta_duration = dd

	ctx.after_intensity = int(s.intensity)
	ctx.after_duration = int(s.duration)

	return (di != 0) or (dd != 0)

## status_state.gd
#class_name StatusState extends RefCounted
#
#
#
## status_id -> StatusStack
#var by_id: Dictionary = {}  # StringName -> StatusStack

#func has(id: StringName) -> bool:
	#return by_id.has(id)
#
#func get_status_stack(id: StringName) -> StatusStack:
	#return by_id.get(id, null)

#func add_or_reapply(id: StringName, intensity: int, duration: int = 0) -> void:
	##print("status_state.gd add_or_reapply() id: %s, intensity: %s, duration: %s" % [id, intensity_delta, duration])
	#if id == &"":
		#return
	#
	#var s: StatusStack = by_id.get(id, null)
	#if s == null:
		#s = StatusStack.new(id)
		#s.intensity = maxi(intensity, 1)
		#s.duration = duration
		#by_id[id] = s
	#else:
		#s.intensity = maxi(s.intensity + intensity, 0)
		## duration policy: take max, or overwrite if nonzero—choose one.
		#if duration > 0:
			#s.duration = max(s.duration + duration, 0)
		##if s.intensity <= 0:
			##by_id.erase(id)
	##print("status_state.gd add_or_reapply() stack intensity: %s, duration: %s" % [by_id[id].intensity, by_id[id].duration])

func remove_ctx(ctx: StatusContext) -> void:
	if ctx == null or !by_id.has(ctx.status_id):
		return
	ctx.op = Status.OP.REMOVE
	by_id.erase(ctx.status_id)

func remove(id: StringName) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	remove_ctx(ctx)
	

func clone() -> StatusState:
	var st := StatusState.new()
	for k in by_id.keys():
		var s: StatusStack = by_id[k]
		if s:
			st.by_id[k] = s.clone()
	return st

func set_stack(id: StringName, intensity: int, duration: int) -> bool:
	var s: StatusStack = by_id.get(id, null)
	if s == null:
		return false
	var changed := (s.intensity != intensity) or (s.duration != duration)
	s.intensity = intensity
	s.duration = duration
	return changed
