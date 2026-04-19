# status_state.gd
class_name StatusState extends RefCounted

var by_id: Dictionary = {}  # StringName -> StatusTokenBucket
var by_id_projected: Dictionary = {} # StringName -> StatusToken
var _projected_contribution_index: ProjectedStatusContributionIndex = ProjectedStatusContributionIndex.new()
var _projected_cache_ready: bool = false
var _effective_context_version: int = 1


func has(id: StringName, pending := false) -> bool:
	var bucket: StatusTokenBucket = _get_bucket(id, false)
	return bucket != null and bucket.has(bool(pending))


func has_any(id: StringName) -> bool:
	var bucket: StatusTokenBucket = _get_bucket(id, false)
	return bucket != null and bucket.has_any()


func get_status_token(id: StringName, pending := false) -> StatusToken:
	var bucket: StatusTokenBucket = _get_bucket(id, false)
	if bucket == null:
		return null
	return bucket.get_status_token(bool(pending))


func get_status_ids(include_pending := true, pending_only := false) -> Array[StringName]:
	var out: Array[StringName] = []
	for id_key in by_id.keys():
		var id := StringName(id_key)
		var bucket: StatusTokenBucket = _get_bucket(id, false)
		if bucket == null:
			continue
		if pending_only:
			if bucket.has(true):
				out.append(id)
			continue
		if bucket.has(false) or (include_pending and bucket.has(true)):
			out.append(id)
	return out


func get_all_tokens(include_pending := true) -> Array[StatusToken]:
	var out: Array[StatusToken] = []
	for id_key in by_id.keys():
		var bucket: StatusTokenBucket = _get_bucket(StringName(id_key), false)
		if bucket == null:
			continue
		out.append_array(bucket.get_tokens(include_pending))
	return out


func has_projected(id: StringName) -> bool:
	return by_id_projected.has(id)


func get_projected_status_token(id: StringName) -> StatusToken:
	return by_id_projected.get(id, null) as StatusToken


func get_projected_status_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id_key in by_id_projected.keys():
		out.append(StringName(id_key))
	return out


func get_all_projected_tokens() -> Array[StatusToken]:
	var out: Array[StatusToken] = []
	for id_key in by_id_projected.keys():
		var token := by_id_projected.get(id_key, null) as StatusToken
		if token != null:
			out.append(token)
	return out


func clear_projected() -> void:
	by_id_projected.clear()
	_projected_contribution_index.clear()
	_projected_cache_ready = false
	_bump_effective_context_version()


func is_projected_cache_ready() -> bool:
	return bool(_projected_cache_ready)


func set_projected_cache_ready(ready: bool) -> void:
	_projected_cache_ready = bool(ready)


func get_effective_context_version() -> int:
	return int(_effective_context_version)


func get_projected_dependency_status_ids(source_key: String) -> Array[StringName]:
	return _projected_contribution_index.get_dependency_status_ids(source_key)


func upsert_projected_source(source_key: String, projected_tokens: Array[StatusToken], order_info := {}) -> Array[StringName]:
	var affected_ids: Array[StringName] = _projected_contribution_index.replace_source(source_key, projected_tokens, order_info)
	_recompute_projected_bins_for_ids(affected_ids)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return affected_ids


func remove_projected_source(source_key: String) -> Array[StringName]:
	var affected_ids: Array[StringName] = _projected_contribution_index.remove_source(source_key)
	_recompute_projected_bins_for_ids(affected_ids)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return affected_ids


func realize_pending_ctx(ctx: StatusContext, max_intensity: int = 0) -> bool:
	if ctx == null:
		return false
	var id := ctx.status_id
	if id == &"":
		return false

	var bucket: StatusTokenBucket = _get_bucket(id, false)
	if bucket == null:
		return false

	var pending_token: StatusToken = bucket.get_status_token(true)
	if pending_token == null:
		return false

	var realized_token: StatusToken = bucket.get_status_token(false)
	var had_realized := realized_token != null
	var pending_i := int(pending_token.intensity)
	var pending_d := int(pending_token.duration)
	var realized_before_i := int(realized_token.intensity) if had_realized else 0
	var realized_before_d := int(realized_token.duration) if had_realized else 0

	if !had_realized:
		realized_token = StatusToken.new(id)
		realized_token.pending = false
		realized_token.intensity = _clamp_intensity_total(pending_i, max_intensity)
		realized_token.duration = pending_d
		bucket.set_status_token(realized_token, false)
	else:
		realized_token.intensity = _clamp_intensity_total(realized_before_i + pending_i, max_intensity)
		if pending_d != 0:
			realized_token.duration = max(realized_before_d + pending_d, 0)

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
	ctx.after_intensity = int(realized_token.intensity)
	ctx.after_duration = int(realized_token.duration)
	ctx.delta_intensity = int(realized_token.intensity) - realized_before_i
	ctx.delta_duration = int(realized_token.duration) - realized_before_d
	ctx.intensity = ctx.delta_intensity
	ctx.duration = ctx.delta_duration
	_bump_effective_context_version()
	return true


func add_or_reapply(id: StringName, intensity: int, duration: int = 0) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	ctx.intensity = intensity
	ctx.duration = duration
	add_or_reapply_ctx(ctx)


func add_or_reapply_ctx(ctx: StatusContext, max_intensity: int = 0) -> bool:
	if ctx == null:
		return false
	var id := ctx.status_id
	if id == &"":
		return false

	var lane_pending := bool(ctx.pending)
	var req_i := int(ctx.intensity)
	var req_d := int(ctx.duration)

	var bucket: StatusTokenBucket = _get_bucket(id, true)
	var existed: bool = bucket.has(lane_pending)
	var token: StatusToken = bucket.get_status_token(lane_pending)

	var before_i := 0
	var before_d := 0

	if token == null:
		token = StatusToken.new(id)
		token.pending = lane_pending
	else:
		before_i = int(token.intensity)
		before_d = int(token.duration)

	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_intensity = before_i
	ctx.before_duration = before_d

	if !existed:
		var new_i := _clamp_intensity_total(maxi(req_i, 1), max_intensity)
		var new_d := req_d

		token.intensity = new_i
		token.duration = new_d
		token.pending = lane_pending
		bucket.set_status_token(token, lane_pending)
		by_id[id] = bucket

		ctx.op = Status.OP.APPLY
		ctx.delta_intensity = new_i - before_i
		ctx.delta_duration = new_d - before_d
		ctx.after_intensity = int(token.intensity)
		ctx.after_duration = int(token.duration)
		ctx.intensity = int(token.intensity)
		ctx.duration = int(token.duration)
		_bump_effective_context_version()
		return true

	var new_intensity := _clamp_intensity_total(before_i + req_i, max_intensity)
	token.intensity = new_intensity

	var new_duration := before_d
	if req_d != 0:
		new_duration = max(before_d + req_d, 0)
	token.duration = new_duration

	var di := int(token.intensity) - before_i
	var dd := int(token.duration) - before_d

	ctx.op = Status.OP.CHANGE
	ctx.delta_intensity = di
	ctx.delta_duration = dd
	ctx.after_intensity = int(token.intensity)
	ctx.after_duration = int(token.duration)
	ctx.intensity = di
	ctx.duration = dd
	if (di != 0) or (dd != 0):
		_bump_effective_context_version()

	return (di != 0) or (dd != 0)


func remove_ctx(ctx: StatusContext) -> void:
	if ctx == null:
		return

	var bucket: StatusTokenBucket = _get_bucket(ctx.status_id, false)
	if bucket == null:
		return

	var lane_pending := bool(ctx.pending)
	var token: StatusToken = bucket.get_status_token(lane_pending)
	if token == null:
		return

	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_intensity = int(token.intensity)
	ctx.before_duration = int(token.duration)
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
	var copied := StatusState.new()
	for id_key in by_id.keys():
		var id := StringName(id_key)
		var bucket: StatusTokenBucket = _get_bucket(id, false)
		if bucket != null and !bucket.is_empty():
			copied.by_id[id] = bucket.clone()
	for id_key in by_id_projected.keys():
		var id := StringName(id_key)
		var token := by_id_projected.get(id, null) as StatusToken
		if token != null:
			copied.by_id_projected[id] = token.clone()
	copied._projected_contribution_index = _projected_contribution_index.clone()
	copied._projected_cache_ready = _projected_cache_ready
	copied._effective_context_version = _effective_context_version
	return copied


func _bump_effective_context_version() -> void:
	_effective_context_version += 1


func set_token(id: StringName, intensity: int, duration: int, pending := false) -> bool:
	var token := get_status_token(id, pending)
	if token == null:
		return false
	var changed := (token.intensity != intensity) or (token.duration != duration)
	token.intensity = intensity
	token.duration = duration
	if changed:
		_bump_effective_context_version()
	return changed


func _get_bucket(id: StringName, create: bool) -> StatusTokenBucket:
	if by_id.has(id):
		return by_id[id] as StatusTokenBucket
	if !create:
		return null
	var bucket: StatusTokenBucket = StatusTokenBucket.new()
	by_id[id] = bucket
	return bucket


func _clamp_intensity_total(value: int, max_intensity: int) -> int:
	var out := maxi(int(value), 0)
	if int(max_intensity) > 0:
		out = mini(out, int(max_intensity))
	return out


func _recompute_projected_bins_for_ids(affected_ids: Array[StringName]) -> void:
	for status_id in affected_ids:
		var projected_token: StatusToken = _projected_contribution_index.build_projected_token(status_id)
		if projected_token == null:
			by_id_projected.erase(status_id)
			continue
		by_id_projected[status_id] = projected_token


func debug_projected_snapshot() -> Dictionary:
	var snapshot := {
		"projected_status_ids": get_projected_status_ids(),
		"sources": {},
		"status_dependencies": {},
	}
	for source_key in _projected_contribution_index.get_all_source_keys():
		snapshot["sources"][source_key] = get_projected_dependency_status_ids(source_key)
	for status_id in by_id_projected.keys():
		var key := StringName(status_id)
		snapshot["status_dependencies"][String(key)] = _projected_contribution_index.get_source_keys_for_status(key)
	return snapshot
