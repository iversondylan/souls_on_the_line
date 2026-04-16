# status_state.gd
class_name StatusState extends RefCounted

var by_id: Dictionary = {}  # StringName -> { false: StatusStack, true: StatusStack }
var by_id_projected: Dictionary = {} # StringName -> StatusStack
var _projected_source_contributions: Dictionary = {} # String -> { StringName -> StatusStack }
var _projected_status_ids_by_source: Dictionary = {} # String -> { StringName -> bool }
var _projected_source_keys_by_status_id: Dictionary = {} # StringName -> { String -> bool }
var _projected_cache_ready: bool = false
var _effective_context_version: int = 1

func has(id: StringName, pending := false) -> bool:
	var bucket := _get_bucket(id, false)
	return bucket.has(bool(pending))

func has_any(id: StringName) -> bool:
	var bucket := _get_bucket(id, false)
	return !bucket.is_empty()

func get_status_stack(id: StringName, pending := false) -> StatusStack:
	var bucket := _get_bucket(id, false)
	var stack = bucket.get(bool(pending), null)
	return stack if stack is StatusStack else null

func get_status_ids(include_pending := true, pending_only := false) -> Array[StringName]:
	var out: Array[StringName] = []
	for id_key in by_id.keys():
		var id := StringName(id_key)
		var bucket := _get_bucket(id, false)
		if pending_only:
			if bucket.has(true):
				out.append(id)
			continue
		if bucket.has(false) or (include_pending and bucket.has(true)):
			out.append(id)
	return out

func get_all_stacks(include_pending := true) -> Array[StatusStack]:
	var out: Array[StatusStack] = []
	for id_key in by_id.keys():
		var id := StringName(id_key)
		var bucket := _get_bucket(id, false)
		var realized = bucket.get(false, null)
		if realized is StatusStack:
			out.append(realized)
		if include_pending:
			var pending_stack = bucket.get(true, null)
			if pending_stack is StatusStack:
				out.append(pending_stack)
	return out

func has_projected(id: StringName) -> bool:
	return by_id_projected.has(id)

func get_projected_status_stack(id: StringName) -> StatusStack:
	var stack = by_id_projected.get(id, null)
	return stack if stack is StatusStack else null

func get_projected_status_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id_key in by_id_projected.keys():
		out.append(StringName(id_key))
	return out

func get_all_projected_stacks() -> Array[StatusStack]:
	var out: Array[StatusStack] = []
	for id_key in by_id_projected.keys():
		var stack = by_id_projected.get(id_key, null)
		if stack is StatusStack:
			out.append(stack)
	return out

func clear_projected() -> void:
	by_id_projected.clear()
	_projected_source_contributions.clear()
	_projected_status_ids_by_source.clear()
	_projected_source_keys_by_status_id.clear()
	_projected_cache_ready = false
	_bump_effective_context_version()

func is_projected_cache_ready() -> bool:
	return bool(_projected_cache_ready)

func set_projected_cache_ready(ready: bool) -> void:
	_projected_cache_ready = bool(ready)

func get_effective_context_version() -> int:
	return int(_effective_context_version)

func get_projected_dependency_status_ids(source_key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if source_key.is_empty():
		return out
	var ids = _projected_status_ids_by_source.get(source_key, {})
	if !(ids is Dictionary):
		return out
	for status_id_key in (ids as Dictionary).keys():
		out.append(StringName(status_id_key))
	return out

func upsert_projected_source(source_key: String, projected_stacks: Array[StatusStack]) -> Array[StringName]:
	var affected_ids := {}
	if source_key.is_empty():
		return []

	var previous_map = _projected_source_contributions.get(source_key, {})
	if !(previous_map is Dictionary):
		previous_map = {}

	var next_map: Dictionary = {}
	for stack: StatusStack in projected_stacks:
		if stack == null or stack.id == &"":
			continue

		var copied := stack.clone()
		copied.pending = false
		next_map[copied.id] = copied
		affected_ids[copied.id] = true

	for status_id_key in (previous_map as Dictionary).keys():
		affected_ids[StringName(status_id_key)] = true

	_projected_source_contributions[source_key] = next_map
	_projected_status_ids_by_source[source_key] = _status_id_set_from_map(next_map)

	_rebuild_projected_source_index_for_affected_ids(source_key, affected_ids)
	_recompute_projected_bins_for_ids(affected_ids)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return _to_sorted_status_id_array(affected_ids)

func remove_projected_source(source_key: String) -> Array[StringName]:
	var previous_map = _projected_source_contributions.get(source_key, {})
	if !(previous_map is Dictionary):
		previous_map = {}

	var affected_ids := {}
	for status_id_key in (previous_map as Dictionary).keys():
		affected_ids[StringName(status_id_key)] = true

	_projected_source_contributions.erase(source_key)
	_projected_status_ids_by_source.erase(source_key)
	_rebuild_projected_source_index_for_affected_ids(source_key, affected_ids)
	_recompute_projected_bins_for_ids(affected_ids)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return _to_sorted_status_id_array(affected_ids)

func realize_pending_ctx(ctx: StatusContext, max_intensity: int = 0) -> bool:
	if ctx == null:
		return false
	var id := ctx.status_id
	if id == &"":
		return false

	var bucket := _get_bucket(id, false)
	var pending_stack = bucket.get(true, null)
	if !(pending_stack is StatusStack):
		return false

	var realized_stack = bucket.get(false, null)
	var had_realized := realized_stack is StatusStack
	var pending_i := int(pending_stack.intensity)
	var pending_d := int(pending_stack.duration)
	var realized_before_i := int(realized_stack.intensity) if had_realized else 0
	var realized_before_d := int(realized_stack.duration) if had_realized else 0

	if !had_realized:
		realized_stack = StatusStack.new(id)
		realized_stack.pending = false
		realized_stack.intensity = _clamp_intensity_total(pending_i, max_intensity)
		realized_stack.duration = pending_d
		bucket[false] = realized_stack
	else:
		realized_stack.intensity = _clamp_intensity_total(realized_before_i + pending_i, max_intensity)
		if pending_d != 0:
			realized_stack.duration = max(realized_before_d + pending_d, 0)

	bucket.erase(true)
	if bucket.is_empty():
		by_id.erase(id)
	else:
		by_id[id] = bucket

	ctx.pending = false
	ctx.op = Status.OP.CHANGE
	ctx.before_pending = true
	ctx.after_pending = false
	ctx.before_intensity = pending_i
	ctx.before_duration = pending_d
	ctx.after_intensity = int(realized_stack.intensity)
	ctx.after_duration = int(realized_stack.duration)
	ctx.delta_intensity = int(realized_stack.intensity) - realized_before_i
	ctx.delta_duration = int(realized_stack.duration) - realized_before_d
	ctx.intensity = ctx.delta_intensity
	ctx.duration = ctx.delta_duration
	_bump_effective_context_version()
	return true

# Convenience wrapper (keeps old callsites alive)
func add_or_reapply(id: StringName, intensity: int, duration: int = 0) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	ctx.intensity = intensity
	ctx.duration = duration
	add_or_reapply_ctx(ctx)

# New canonical path: determines APPLY vs CHANGE and populates ctx
func add_or_reapply_ctx(ctx: StatusContext, max_intensity: int = 0) -> bool:
	if ctx == null:
		return false
	var id := ctx.status_id
	if id == &"":
		return false

	var lane_pending := bool(ctx.pending)
	var req_i := int(ctx.intensity)
	var req_d := int(ctx.duration)

	var bucket := _get_bucket(id, true)
	var existed := bucket.has(lane_pending)
	var s: StatusStack = bucket.get(lane_pending, null)

	var before_i := 0
	var before_d := 0

	if s == null:
		s = StatusStack.new(id)
		s.pending = lane_pending
	else:
		before_i = int(s.intensity)
		before_d = int(s.duration)

	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_intensity = before_i
	ctx.before_duration = before_d

	if !existed:
		# APPLY semantics: create new stack
		# intensity policy: must be at least 1 on create
		var new_i := _clamp_intensity_total(maxi(req_i, 1), max_intensity)
		var new_d := req_d

		s.intensity = new_i
		s.duration = new_d
		s.pending = lane_pending
		bucket[lane_pending] = s
		by_id[id] = bucket

		ctx.op = Status.OP.APPLY
		ctx.delta_intensity = new_i - before_i
		ctx.delta_duration = new_d - before_d

		ctx.after_intensity = int(s.intensity)
		ctx.after_duration = int(s.duration)
		ctx.intensity = int(s.intensity)
		ctx.duration = int(s.duration)
		_bump_effective_context_version()

		return true

	# CHANGE semantics: modify existing stack
	# intensity policy: additive, clamped at 0
	var new_intensity := _clamp_intensity_total(before_i + req_i, max_intensity)
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
	ctx.intensity = di
	ctx.duration = dd
	if (di != 0) or (dd != 0):
		_bump_effective_context_version()

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
	if ctx == null:
		return
	var bucket := _get_bucket(ctx.status_id, false)
	var lane_pending := bool(ctx.pending)
	var stack = bucket.get(lane_pending, null)
	if !(stack is StatusStack):
		return
	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_intensity = int(stack.intensity)
	ctx.before_duration = int(stack.duration)
	ctx.after_intensity = 0
	ctx.after_duration = 0
	ctx.op = Status.OP.REMOVE
	bucket.erase(lane_pending)
	if bucket.is_empty():
		by_id.erase(ctx.status_id)
	else:
		by_id[ctx.status_id] = bucket
	_bump_effective_context_version()

func remove(id: StringName) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	remove_ctx(ctx)
	

func clone() -> StatusState:
	var st := StatusState.new()
	for id_key in by_id.keys():
		var id := StringName(id_key)
		var bucket := _get_bucket(id, false)
		var cloned_bucket := {}
		for lane_key in bucket.keys():
			var stack = bucket[lane_key]
			if stack is StatusStack:
				cloned_bucket[lane_key] = stack.clone()
		if !cloned_bucket.is_empty():
			st.by_id[id] = cloned_bucket
	for id_key in by_id_projected.keys():
		var id := StringName(id_key)
		var stack = by_id_projected.get(id, null)
		if stack is StatusStack:
			st.by_id_projected[id] = stack.clone()
	for source_key in _projected_source_contributions.keys():
		var source_map = _projected_source_contributions.get(source_key, {})
		var cloned_source_map := {}
		if source_map is Dictionary:
			for status_id_key in (source_map as Dictionary).keys():
				var source_stack = (source_map as Dictionary).get(status_id_key, null)
				if source_stack is StatusStack:
					cloned_source_map[StringName(status_id_key)] = source_stack.clone()
		st._projected_source_contributions[String(source_key)] = cloned_source_map
	st._projected_status_ids_by_source = _projected_status_ids_by_source.duplicate(true)
	st._projected_source_keys_by_status_id = _projected_source_keys_by_status_id.duplicate(true)
	st._projected_cache_ready = _projected_cache_ready
	st._effective_context_version = _effective_context_version
	return st

func _bump_effective_context_version() -> void:
	_effective_context_version += 1

func set_stack(id: StringName, intensity: int, duration: int, pending := false) -> bool:
	var s := get_status_stack(id, pending)
	if s == null:
		return false
	var changed := (s.intensity != intensity) or (s.duration != duration)
	s.intensity = intensity
	s.duration = duration
	return changed

func _get_bucket(id: StringName, create: bool) -> Dictionary:
	var bucket = by_id.get(id, null)
	if bucket is Dictionary:
		return bucket
	if !create:
		return {}
	bucket = {}
	by_id[id] = bucket
	return bucket

func _clamp_intensity_total(value: int, max_intensity: int) -> int:
	var out := maxi(int(value), 0)
	if int(max_intensity) > 0:
		out = mini(out, int(max_intensity))
	return out

func _status_id_set_from_map(map: Dictionary) -> Dictionary:
	var out := {}
	for status_id_key in map.keys():
		out[StringName(status_id_key)] = true
	return out

func _rebuild_projected_source_index_for_affected_ids(source_key: String, affected_ids: Dictionary) -> void:
	for status_id_key in affected_ids.keys():
		var status_id := StringName(status_id_key)
		var source_keys = _projected_source_keys_by_status_id.get(status_id, {})
		if !(source_keys is Dictionary):
			source_keys = {}
		(source_keys as Dictionary).erase(source_key)
		if (source_keys as Dictionary).is_empty():
			_projected_source_keys_by_status_id.erase(status_id)
		else:
			_projected_source_keys_by_status_id[status_id] = source_keys

	var source_status_ids = _projected_status_ids_by_source.get(source_key, {})
	if !(source_status_ids is Dictionary):
		return
	for status_id_key in (source_status_ids as Dictionary).keys():
		var status_id := StringName(status_id_key)
		var source_keys = _projected_source_keys_by_status_id.get(status_id, {})
		if !(source_keys is Dictionary):
			source_keys = {}
		(source_keys as Dictionary)[source_key] = true
		_projected_source_keys_by_status_id[status_id] = source_keys

func _recompute_projected_bins_for_ids(affected_ids: Dictionary) -> void:
	for status_id_key in affected_ids.keys():
		var status_id := StringName(status_id_key)
		var source_keys = _projected_source_keys_by_status_id.get(status_id, {})
		if !(source_keys is Dictionary) or (source_keys as Dictionary).is_empty():
			by_id_projected.erase(status_id)
			continue

		var total_intensity := 0
		var max_duration := 0
		for source_key in (source_keys as Dictionary).keys():
			var source_map = _projected_source_contributions.get(String(source_key), {})
			if !(source_map is Dictionary):
				continue
			var stack = (source_map as Dictionary).get(status_id, null)
			if !(stack is StatusStack):
				continue
			total_intensity += int(stack.intensity)
			max_duration = maxi(max_duration, int(stack.duration))

		if total_intensity <= 0:
			by_id_projected.erase(status_id)
			continue

		var out_stack = StatusStack.new(status_id)
		out_stack.pending = false
		out_stack.intensity = total_intensity
		out_stack.duration = max_duration
		by_id_projected[status_id] = out_stack

func _to_sorted_status_id_array(source_ids: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for status_id_key in source_ids.keys():
		out.append(StringName(status_id_key))
	out.sort()
	return out

func debug_projected_snapshot() -> Dictionary:
	var snapshot := {
		"projected_status_ids": get_projected_status_ids(),
		"sources": {},
		"status_dependencies": {},
	}
	for source_key in _projected_status_ids_by_source.keys():
		snapshot["sources"][String(source_key)] = get_projected_dependency_status_ids(String(source_key))
	for status_id in by_id_projected.keys():
		var key := StringName(status_id)
		var source_keys = _projected_source_keys_by_status_id.get(key, {}) # would be good to include hard typing here. What's type of source_keys?
		if source_keys is Dictionary:
			snapshot["status_dependencies"][String(key)] = (source_keys as Dictionary).keys()
	return snapshot
