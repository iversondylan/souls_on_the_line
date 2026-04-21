# status_state.gd
class_name StatusState extends RefCounted

var by_id: Dictionary = {}  # StringName -> StatusTokenBucket
var by_id_projected: Dictionary = {} # StringName -> StatusToken
var _projected_contribution_index: ProjectedStatusContributionIndex = ProjectedStatusContributionIndex.new()
var _projected_cache_ready: bool = false
var _effective_context_version: int = 1
var _has_cached_effective_contexts: bool = false
var _cached_effective_context_version: int = 0
var _cached_effective_contexts: Array[SimStatusContext] = []

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

func get_status_token_by_token_id(token_id: int, include_pending := true) -> StatusToken:
	if token_id <= 0:
		return null
	for token: StatusToken in get_all_tokens(include_pending):
		if token != null and int(token.token_id) == int(token_id):
			return token
	return null

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

func has_cached_effective_contexts(version: int) -> bool:
	return bool(_has_cached_effective_contexts) and int(version) == int(_cached_effective_context_version)

func get_cached_effective_contexts(version: int) -> Array[SimStatusContext]:
	if !has_cached_effective_contexts(version):
		return []
	return _copy_effective_contexts(_cached_effective_contexts)

func set_cached_effective_contexts(version: int, contexts: Array[SimStatusContext]) -> void:
	_has_cached_effective_contexts = true
	_cached_effective_context_version = int(version)
	_cached_effective_contexts = _copy_effective_contexts(contexts)

func invalidate_effective_context_cache() -> void:
	_has_cached_effective_contexts = false
	_cached_effective_context_version = 0
	_cached_effective_contexts.clear()

func get_projected_dependency_status_ids(source_key: String) -> Array[StringName]:
	return _projected_contribution_index.get_dependency_status_ids(source_key)

func rebuild_projected_tokens(proto_resolver: Callable = Callable()) -> void:
	by_id_projected.clear()
	for status_id in _projected_contribution_index.get_all_status_ids():
		var proto: Status = null
		if proto_resolver.is_valid():
			proto = proto_resolver.call(status_id) as Status
		var projected_token := _projected_contribution_index.build_projected_token(status_id, proto)
		if projected_token != null:
			by_id_projected[status_id] = projected_token

func upsert_projected_source(
	source_key: String,
	projected_tokens: Array[StatusToken],
	order_info := {},
	proto_resolver: Callable = Callable()
) -> Array[StringName]:
	var affected_ids: Array[StringName] = _projected_contribution_index.replace_source(source_key, projected_tokens, order_info)
	_recompute_projected_bins_for_ids(affected_ids, proto_resolver)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return affected_ids

func remove_projected_source(source_key: String, proto_resolver: Callable = Callable()) -> Array[StringName]:
	var affected_ids: Array[StringName] = _projected_contribution_index.remove_source(source_key)
	_recompute_projected_bins_for_ids(affected_ids, proto_resolver)
	_projected_cache_ready = true
	_bump_effective_context_version()
	return affected_ids

func realize_pending_ctx(ctx: StatusContext, max_stacks: int = 0) -> StatusMutationResult:
	var result := StatusMutationResult.new()
	if ctx == null:
		return result
	var id := ctx.status_id
	if id == &"":
		return result

	var bucket: StatusTokenBucket = _get_bucket(id, false)
	if bucket == null:
		return result

	var pending_token: StatusToken = bucket.get_status_token(true)
	if pending_token == null:
		return result

	var realized_token: StatusToken = bucket.get_status_token(false)
	var had_realized := realized_token != null
	var pending_stacks := int(pending_token.stacks)
	var pending_token_id := int(pending_token.token_id)
	var realized_before_stacks := int(realized_token.stacks) if had_realized else 0

	if !had_realized:
		realized_token = StatusToken.new(id)
		realized_token.token_id = pending_token_id
		realized_token.pending = false
		realized_token.stacks = _clamp_stacks_total(pending_stacks, max_stacks)
		bucket.set_status_token(realized_token, false)
	else:
		realized_token.stacks = _clamp_stacks_total(realized_before_stacks + pending_stacks, max_stacks)

	bucket.erase(true)
	if bucket.is_empty():
		by_id.erase(id)
	else:
		by_id[id] = bucket

	ctx.pending = false
	ctx.op = Status.OP.CHANGE
	ctx.before_pending = true
	ctx.after_pending = false
	ctx.before_token_id = pending_token_id
	ctx.after_token_id = int(realized_token.token_id)
	ctx.before_stacks = pending_stacks
	ctx.after_stacks = int(realized_token.stacks)
	ctx.delta_stacks = int(realized_token.stacks) - realized_before_stacks
	ctx.stacks = ctx.delta_stacks

	result.changed = true
	result.status_id = id
	result.op = int(ctx.op)
	result.before_pending = true
	result.after_pending = false
	result.before_token_id = pending_token_id
	result.after_token_id = int(realized_token.token_id)
	result.before_stacks = pending_stacks
	result.after_stacks = int(realized_token.stacks)
	result.delta_stacks = int(ctx.delta_stacks)
	_bump_effective_context_version()
	return result

func add_or_reapply(
	id: StringName,
	stacks: int = 1,
	reapply_type: int = Status.ReapplyType.ADD,
	allocate_token_id: Callable = Callable()
) -> void:
	var ctx := StatusContext.new()
	ctx.status_id = id
	ctx.stacks = stacks
	add_or_reapply_ctx(ctx, 0, reapply_type, allocate_token_id)

func add_or_reapply_ctx(
	ctx: StatusContext,
	max_stacks: int = 0,
	reapply_type: int = Status.ReapplyType.ADD,
	allocate_token_id: Callable = Callable()
) -> StatusMutationResult:
	var result := StatusMutationResult.new()
	if ctx == null:
		return result
	var id := ctx.status_id
	if id == &"":
		return result

	var lane_pending := bool(ctx.pending)
	var req_stacks := int(ctx.stacks)

	var bucket: StatusTokenBucket = _get_bucket(id, true)
	var existed: bool = bucket.has(lane_pending)
	var token: StatusToken = bucket.get_status_token(lane_pending)

	var before_stacks := 0
	var before_token_id := 0

	if token == null:
		token = StatusToken.new(id)
		token.token_id = int(allocate_token_id.call()) if allocate_token_id.is_valid() else 0
		token.pending = lane_pending
	else:
		before_stacks = int(token.stacks)
		before_token_id = int(token.token_id)

	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_token_id = before_token_id
	ctx.before_stacks = before_stacks

	if !existed:
		var new_stacks := _clamp_stacks_total(req_stacks, max_stacks)
		if new_stacks <= 0:
			return result

		token.stacks = new_stacks
		token.pending = lane_pending
		bucket.set_status_token(token, lane_pending)
		by_id[id] = bucket

		ctx.op = Status.OP.APPLY
		ctx.after_token_id = int(token.token_id)
		ctx.delta_stacks = new_stacks - before_stacks
		ctx.after_stacks = int(token.stacks)
		ctx.stacks = int(token.stacks)

		result.changed = true
		result.status_id = id
		result.op = int(ctx.op)
		result.before_pending = lane_pending
		result.after_pending = lane_pending
		result.before_token_id = 0
		result.after_token_id = int(token.token_id)
		result.before_stacks = before_stacks
		result.after_stacks = int(token.stacks)
		result.delta_stacks = int(ctx.delta_stacks)
		_bump_effective_context_version()
		return result

	var new_total := before_stacks
	match int(reapply_type):
		int(Status.ReapplyType.REPLACE):
			new_total = _clamp_stacks_total(req_stacks, max_stacks)
		int(Status.ReapplyType.IGNORE):
			new_total = before_stacks
		_:
			new_total = _clamp_stacks_total(before_stacks + req_stacks, max_stacks)
	token.stacks = new_total

	var ds := int(token.stacks) - before_stacks

	ctx.op = Status.OP.CHANGE
	ctx.after_token_id = int(token.token_id)
	ctx.delta_stacks = ds
	ctx.after_stacks = int(token.stacks)
	ctx.stacks = ds

	result.changed = ds != 0
	result.status_id = id
	result.op = int(ctx.op)
	result.before_pending = lane_pending
	result.after_pending = lane_pending
	result.before_token_id = before_token_id
	result.after_token_id = int(token.token_id)
	result.before_stacks = before_stacks
	result.after_stacks = int(token.stacks)
	result.delta_stacks = ds
	if ds != 0:
		_bump_effective_context_version()

	return result

func remove_ctx(ctx: StatusContext) -> StatusMutationResult:
	var result := StatusMutationResult.new()
	if ctx == null:
		return result

	var bucket: StatusTokenBucket = _get_bucket(ctx.status_id, false)
	if bucket == null:
		return result

	var lane_pending := bool(ctx.pending)
	var token: StatusToken = bucket.get_status_token(lane_pending)
	if token == null:
		return result

	ctx.before_pending = lane_pending
	ctx.after_pending = lane_pending
	ctx.before_token_id = int(token.token_id)
	ctx.after_token_id = 0
	ctx.before_stacks = int(token.stacks)
	ctx.after_stacks = 0
	ctx.op = Status.OP.REMOVE

	bucket.erase(lane_pending)
	if bucket.is_empty():
		by_id.erase(ctx.status_id)
	else:
		by_id[ctx.status_id] = bucket

	result.changed = true
	result.status_id = ctx.status_id
	result.op = int(ctx.op)
	result.before_pending = lane_pending
	result.after_pending = lane_pending
	result.before_token_id = int(ctx.before_token_id)
	result.after_token_id = 0
	result.before_stacks = int(ctx.before_stacks)
	result.after_stacks = 0
	result.delta_stacks = -int(ctx.before_stacks)
	_bump_effective_context_version()
	return result

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
	invalidate_effective_context_cache()
	_effective_context_version += 1

func set_token(id: StringName, stacks: int, pending := false) -> bool:
	var token := get_status_token(id, pending)
	if token == null:
		return false
	var changed := token.stacks != stacks
	token.stacks = stacks
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

func _clamp_stacks_total(value: int, max_stacks: int) -> int:
	var out := maxi(int(value), 0)
	if int(max_stacks) > 0:
		out = mini(out, int(max_stacks))
	return out

func _recompute_projected_bins_for_ids(
	affected_ids: Array[StringName],
	proto_resolver: Callable = Callable()
) -> void:
	for status_id in affected_ids:
		var proto: Status = null
		if proto_resolver.is_valid():
			proto = proto_resolver.call(status_id) as Status
		var projected_token: StatusToken = _projected_contribution_index.build_projected_token(status_id, proto)
		if projected_token == null:
			by_id_projected.erase(status_id)
			continue
		by_id_projected[status_id] = projected_token

func _copy_effective_contexts(source_contexts: Array[SimStatusContext]) -> Array[SimStatusContext]:
	var copied: Array[SimStatusContext] = []
	for ctx: SimStatusContext in source_contexts:
		copied.append(ctx)
	return copied

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
