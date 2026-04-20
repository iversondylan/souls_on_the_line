class_name TransformerRegistry extends RefCounted


const FRIENDLY := 0
const ENEMY := 1
const TARGETING_STAGE_RETARGET := 1
const TARGETING_STAGE_INTERPOSE := 2

var _next_tid: int = 1
var _records_by_transformer_key: Dictionary = {}
var _transformer_keys_by_source_key: Dictionary = {}
var _ordered_projection_cache: Array[TransformerRecord] = []
var _ordered_projection_cache_valid: bool = false
var _interceptors_by_hook: Dictionary = {}
var _dirty_interceptor_hooks: Dictionary = {}


func clear() -> void:
	_next_tid = 1
	_records_by_transformer_key.clear()
	_transformer_keys_by_source_key.clear()
	_ordered_projection_cache.clear()
	_ordered_projection_cache_valid = false
	_interceptors_by_hook.clear()
	_dirty_interceptor_hooks.clear()


func clone():
	var copied: Variant = get_script().new()
	copied._next_tid = int(_next_tid)
	for transformer_key_variant in _records_by_transformer_key.keys():
		var transformer_key := String(transformer_key_variant)
		var record: TransformerRecord = _records_by_transformer_key[transformer_key]
		if record != null:
			copied._records_by_transformer_key[transformer_key] = record.clone()
	for source_key_variant in _transformer_keys_by_source_key.keys():
		var source_key := String(source_key_variant)
		copied._transformer_keys_by_source_key[source_key] = _transformer_keys_by_source_key[source_key].duplicate(true)
	copied._dirty_interceptor_hooks = _dirty_interceptor_hooks.duplicate(true)
	for hook_variant in _interceptors_by_hook.keys():
		var hook_kind := StringName(hook_variant)
		var ordered: Array = _interceptors_by_hook[hook_kind]
		var ordered_copy: Array = []
		for interceptor in ordered:
			if interceptor != null:
				ordered_copy.append(interceptor.clone())
		copied._interceptors_by_hook[hook_kind] = ordered_copy
	if _ordered_projection_cache_valid:
		for record: TransformerRecord in _ordered_projection_cache:
			if record != null:
				copied._ordered_projection_cache.append(record.clone())
		copied._ordered_projection_cache_valid = true
	return copied


func has_projection_transformer(
	source_kind: StringName,
	source_owner_id: int,
	source_id: StringName,
	source_instance_id: int = 0
) -> bool:
	return _records_by_transformer_key.has(
		TransformerRecord.make_transformer_key(
			TransformerRecord.TRANSFORMER_KIND_PROJECTION,
			&"",
			source_kind,
			source_owner_id,
			source_id,
			source_instance_id
		)
	)


func mark_transformer_dirty(transformer_key: String) -> void:
	if transformer_key.is_empty() or !_records_by_transformer_key.has(transformer_key):
		return
	var record: TransformerRecord = _records_by_transformer_key[transformer_key]
	_invalidate_record(record)


func mark_source_dirty(
	source_kind: StringName,
	source_owner_id: int,
	source_id: StringName,
	source_instance_id: int = 0
) -> void:
	var source_key := TransformerRecord.make_source_key(
		source_kind,
		source_owner_id,
		source_id,
		source_instance_id
	)
	if source_key.is_empty() or !_transformer_keys_by_source_key.has(source_key):
		return
	var transformer_keys: Dictionary = _transformer_keys_by_source_key[source_key]
	for transformer_key_variant in transformer_keys.keys():
		mark_transformer_dirty(String(transformer_key_variant))


func get_projection_records() -> Array[TransformerRecord]:
	if !_ordered_projection_cache_valid:
		_rebuild_projection_cache()
	return _ordered_projection_cache


func get_interceptors_for_hook(_state, hook_kind: StringName) -> Array[Interceptor]:
	_ensure_interceptor_hook(hook_kind)
	var ordered: Array[Interceptor] = []
	ordered.assign(_interceptors_by_hook.get(hook_kind, []))
	return ordered


func sync_projected_interceptors_for_target(state: BattleState, target_id: int) -> void:
	if state == null or target_id <= 0:
		return
	var target: CombatantState = state.get_unit(int(target_id))
	var group_index := int(target.team) if target != null else -1
	var desired_status_ids := {}
	if target != null and target.is_alive() and target.statuses != null and state.status_catalog != null:
		for token: StatusToken in target.statuses.get_all_projected_tokens():
			if token == null or StringName(token.id) == &"":
				continue
			var status_id := StringName(token.id)
			var proto: Status = state.status_catalog.get_proto(status_id)
			if proto == null:
				continue
			if !_projected_status_wants_own_interceptor(target, status_id, proto):
				continue
			desired_status_ids[status_id] = true
			_sync_projected_status_effective_records(int(target_id), group_index, status_id, proto)
	var stale_status_ids := {}
	for record_variant in _records_by_transformer_key.values():
		var record := record_variant as TransformerRecord
		if record == null:
			continue
		if record.source_kind != TransformerRecord.SOURCE_KIND_PROJECTED_STATUS_EFFECTIVE:
			continue
		if int(record.source_owner_id) != int(target_id):
			continue
		if desired_status_ids.has(record.source_id):
			continue
		stale_status_ids[record.source_id] = true
	for status_id_variant in stale_status_ids.keys():
		remove_transformers_for_source(
			TransformerRecord.SOURCE_KIND_PROJECTED_STATUS_EFFECTIVE,
			int(target_id),
			StringName(status_id_variant)
		)


func sync_source_change(api, source_ref: TransformerSourceRef) -> void:
	if api == null or api.state == null or api.state.transformer_registry == null:
		return
	if source_ref == null or !source_ref.is_valid():
		return

	var impact_before := _get_projection_impact_info(api.state, source_ref)
	var had_projection := has_projection_transformer(
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_id,
		source_ref.source_instance_id
	)

	_sync_source_records(api.state, source_ref)

	var has_projection := has_projection_transformer(
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_id,
		source_ref.source_instance_id
	)
	if has_projection:
		mark_source_dirty(
			source_ref.source_kind,
			source_ref.source_owner_id,
			source_ref.source_id,
			source_ref.source_instance_id
		)

	var impact_after := _get_projection_impact_info(api.state, source_ref)
	var merged_impacted_ids := _merge_target_ids(impact_before, impact_after)
	var merged_known := (impact_before != null and impact_before.known) or (impact_after != null and impact_after.known)
	var should_process := had_projection or has_projection or merged_known
	if !should_process:
		return

	var source_keys: Array[String] = []
	source_keys.append(
		TransformerRecord.make_source_key(
			source_ref.source_kind,
			source_ref.source_owner_id,
			source_ref.source_id,
			source_ref.source_instance_id
		)
	)
	_handle_projection_source_change(
		api,
		source_ref.source_owner_id,
		merged_impacted_ids,
		merged_known,
		source_keys
	)


func sync_all_arcanum_transformers(
	state: BattleState,
	source_owner_id: int,
	source_group_index: int = FRIENDLY
) -> void:
	if state == null or source_owner_id <= 0:
		return

	var desired_ids := {}
	if state.arcana != null:
		for entry: ArcanumEntry in state.arcana.list:
			if entry == null or entry.id == &"":
				continue
			desired_ids[entry.id] = true
			_sync_source_records(
				state,
				TransformerSourceRef.for_arcanum_entry(source_owner_id, source_group_index, entry.id)
			)

	var to_remove: Array[StringName] = []
	for record_variant in _records_by_transformer_key.values():
		var record := record_variant as TransformerRecord
		if record == null:
			continue
		if record.source_kind != TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY:
			continue
		if int(record.source_owner_id) != int(source_owner_id):
			continue
		if desired_ids.has(record.source_id):
			continue
		to_remove.append(record.source_id)

	for arcanum_id in to_remove:
		_sync_source_records(
			state,
			TransformerSourceRef.for_arcanum_entry(source_owner_id, source_group_index, StringName(arcanum_id))
		)


func get_projection_source_keys_for_owner(source_owner_id: int) -> Array[String]:
	var out: Array[String] = []
	for record: TransformerRecord in get_projection_records():
		if record == null or int(record.source_owner_id) != int(source_owner_id):
			continue
		out.append(record.get_source_key())
	return out


func get_projection_source_record(
	source_kind: StringName,
	source_owner_id: int,
	source_id: StringName,
	source_instance_id: int = 0
) -> TransformerRecord:
	var transformer_key := TransformerRecord.make_transformer_key(
		TransformerRecord.TRANSFORMER_KIND_PROJECTION,
		&"",
		source_kind,
		source_owner_id,
		source_id,
		source_instance_id
	)
	if transformer_key.is_empty() or !_records_by_transformer_key.has(transformer_key):
		return null
	var record := _records_by_transformer_key[transformer_key] as TransformerRecord
	return record.clone() if record != null else null


func remove_transformers_for_source(
	source_kind: StringName,
	source_owner_id: int,
	source_id: StringName,
	source_instance_id: int = 0
) -> void:
	var source_key := TransformerRecord.make_source_key(
		source_kind,
		source_owner_id,
		source_id,
		source_instance_id
	)
	if source_key.is_empty() or !_transformer_keys_by_source_key.has(source_key):
		return
	var transformer_keys: Array[String] = []
	for transformer_key_variant in _transformer_keys_by_source_key[source_key].keys():
		transformer_keys.append(String(transformer_key_variant))
	for transformer_key in transformer_keys:
		_remove_record_by_key(transformer_key)


func _sync_source_records(state: BattleState, source_ref: TransformerSourceRef) -> void:
	if state == null or source_ref == null or !source_ref.is_valid():
		return
	match source_ref.source_kind:
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN:
			_sync_status_source_records(state, source_ref)
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY:
			_sync_arcanum_source_records(state, source_ref)


func _get_projection_impact_info(state: BattleState, source_ref: TransformerSourceRef) -> ProjectionImpactInfo:
	if source_ref == null or !source_ref.is_valid():
		return ProjectionImpactInfo.new(false, PackedInt32Array())
	match source_ref.source_kind:
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN:
			return _get_status_projection_impact_info(state, source_ref)
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY:
			return _get_arcanum_projection_impact_info(state, source_ref)
		_:
			return ProjectionImpactInfo.new(false, PackedInt32Array())


func _get_status_projection_impact_info(state: BattleState, source_ref: TransformerSourceRef) -> ProjectionImpactInfo:
	var target_ids := PackedInt32Array()
	if state == null or state.status_catalog == null:
		return ProjectionImpactInfo.new(false, target_ids)

	var source_owner_id := int(source_ref.source_owner_id)
	var status_id := StringName(source_ref.source_id)
	if source_owner_id <= 0 or status_id == &"":
		return ProjectionImpactInfo.new(false, target_ids)

	var source_unit: CombatantState = state.get_unit(source_owner_id)
	if source_unit == null:
		return ProjectionImpactInfo.new(false, target_ids)

	var aura_proto := state.status_catalog.get_proto(status_id) as Aura
	if aura_proto == null:
		return ProjectionImpactInfo.new(false, target_ids)

	var seen := {}
	for unit_value in state.units.values():
		var unit: CombatantState = unit_value as CombatantState
		if unit == null or !unit.is_alive():
			continue
		var target_id := int(unit.id)
		if target_id <= 0 or seen.has(target_id):
			continue
		if !aura_proto.affects_target(state, source_owner_id, target_id):
			continue
		seen[target_id] = true
		target_ids.append(target_id)
	return ProjectionImpactInfo.new(true, target_ids)


func _get_arcanum_projection_impact_info(state: BattleState, source_ref: TransformerSourceRef) -> ProjectionImpactInfo:
	var target_ids := PackedInt32Array()
	if state == null or state.arcana_catalog == null or state.arcana == null:
		return ProjectionImpactInfo.new(false, target_ids)

	var source_owner_id := int(source_ref.source_owner_id)
	var arcanum_id := StringName(source_ref.source_id)
	if source_owner_id <= 0 or arcanum_id == &"":
		return ProjectionImpactInfo.new(false, target_ids)

	var entry: ArcanumEntry = state.arcana.get_entry(arcanum_id)
	var proto: Arcanum = state.arcana_catalog.get_proto(arcanum_id)
	if entry == null or proto == null or !proto.affects_others():
		return ProjectionImpactInfo.new(false, target_ids)

	var seen := {}
	for unit_value in state.units.values():
		var unit: CombatantState = unit_value as CombatantState
		if unit == null or !unit.is_alive():
			continue
		var target_id := int(unit.id)
		if target_id <= 0 or seen.has(target_id):
			continue
		if !proto.affects_target(state, source_owner_id, target_id):
			continue
		seen[target_id] = true
		target_ids.append(target_id)
	return ProjectionImpactInfo.new(true, target_ids)


func _sync_status_source_records(state: BattleState, source_ref: TransformerSourceRef) -> void:
	var owner: CombatantState = state.get_unit(int(source_ref.source_owner_id))
	var group_index := int(owner.team) if owner != null else int(source_ref.source_group_index)
	var proto: Status = state.status_catalog.get_proto(source_ref.source_id) if state.status_catalog != null else null
	var token: StatusToken = null
	var wants_projection := false
	var wants_interceptors := false

	if owner != null and owner.is_alive() and owner.statuses != null and proto != null:
		token = owner.statuses.get_status_token_by_token_id(int(source_ref.source_instance_id), true)
		if token != null:
			wants_projection = proto is Aura
			wants_interceptors = !bool(token.pending)

	_sync_projection_record(
		wants_projection,
		source_ref.source_kind,
		source_ref.source_owner_id,
		group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		int(proto.transformer_priority) if proto != null else 1
	)
	_sync_status_interceptor_records(
		wants_interceptors,
		source_ref.source_kind,
		source_ref.source_owner_id,
		group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		proto
	)


func _sync_arcanum_source_records(state: BattleState, source_ref: TransformerSourceRef) -> void:
	var proto: Arcanum = state.arcana_catalog.get_proto(source_ref.source_id) if state.arcana_catalog != null else null
	var entry: ArcanumEntry = state.arcana.get_entry(source_ref.source_id) if state.arcana != null else null
	var wants_projection := proto != null and entry != null and bool(proto.affects_others())
	var wants_interceptors := proto != null and entry != null
	var priority := int(proto.transformer_priority) if proto != null else 1

	_sync_projection_record(
		wants_projection,
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		priority
	)
	_sync_interceptor_record(
		wants_interceptors and bool(proto != null and proto.listens_for_any_death()),
		Interceptor.HOOK_ON_ANY_DEATH,
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		priority
	)
	_sync_interceptor_record(
		wants_interceptors and bool(proto != null and proto.listens_for_targeting_retarget()),
		Interceptor.HOOK_ON_TARGETING_RETARGET,
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		int(proto.get_targeting_priority(TARGETING_STAGE_RETARGET)) if proto != null else priority
	)
	_sync_interceptor_record(
		wants_interceptors and bool(proto != null and proto.listens_for_targeting_interpose()),
		Interceptor.HOOK_ON_TARGETING_INTERPOSE,
		source_ref.source_kind,
		source_ref.source_owner_id,
		source_ref.source_group_index,
		source_ref.source_id,
		source_ref.source_instance_id,
		int(proto.get_targeting_priority(TARGETING_STAGE_INTERPOSE)) if proto != null else priority
	)


func _sync_projected_status_effective_records(
	target_id: int,
	group_index: int,
	status_id: StringName,
	proto: Status
) -> void:
	var wants_interceptors := target_id > 0 and group_index >= 0 and proto != null
	_sync_status_interceptor_records(
		wants_interceptors,
		TransformerRecord.SOURCE_KIND_PROJECTED_STATUS_EFFECTIVE,
		target_id,
		group_index,
		status_id,
		0,
		proto
	)


func _projected_status_wants_own_interceptor(
	target: CombatantState,
	status_id: StringName,
	proto: Status
) -> bool:
	if target == null or target.statuses == null or status_id == &"" or proto == null:
		return false
	if int(proto.reapply_type) != int(Status.ReapplyType.INTENSITY):
		return true
	return target.statuses.get_status_token(status_id, false) == null


func _sync_status_interceptor_records(
	wants_records: bool,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
	source_instance_id: int,
	proto: Status
) -> void:
	var default_priority := int(proto.transformer_priority) if proto != null else 1
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_any_death()),
		Interceptor.HOOK_ON_ANY_DEATH,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		default_priority
	)
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_player_turn_begin()),
		Interceptor.HOOK_ON_PLAYER_TURN_BEGIN,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		default_priority
	)
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_group_turn_begin()),
		Interceptor.HOOK_ON_GROUP_TURN_BEGIN,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		default_priority
	)
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_group_turn_end()),
		Interceptor.HOOK_ON_GROUP_TURN_END,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		default_priority
	)
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_targeting_retarget()),
		Interceptor.HOOK_ON_TARGETING_RETARGET,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		int(proto.get_targeting_priority(TARGETING_STAGE_RETARGET)) if proto != null else default_priority
	)
	_sync_interceptor_record(
		wants_records and bool(proto != null and proto.listens_for_targeting_interpose()),
		Interceptor.HOOK_ON_TARGETING_INTERPOSE,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		int(proto.get_targeting_priority(TARGETING_STAGE_INTERPOSE)) if proto != null else default_priority
	)


func _sync_projection_record(
	wants_record: bool,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
	source_instance_id: int,
	priority: int
) -> void:
	_sync_record(
		wants_record,
		TransformerRecord.TRANSFORMER_KIND_PROJECTION,
		&"",
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		priority
	)


func _sync_interceptor_record(
	wants_record: bool,
	hook_kind: StringName,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
	source_instance_id: int,
	priority: int
) -> void:
	_sync_record(
		wants_record,
		TransformerRecord.TRANSFORMER_KIND_INTERCEPTOR,
		hook_kind,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		priority
	)


func _sync_record(
	wants_record: bool,
	transformer_kind: StringName,
	hook_kind: StringName,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
	source_instance_id: int,
	priority: int
) -> void:
	var transformer_key := TransformerRecord.make_transformer_key(
		transformer_kind,
		hook_kind,
		source_kind,
		source_owner_id,
		source_id,
		source_instance_id
	)
	if transformer_key.is_empty():
		return

	if !wants_record:
		_remove_record_by_key(transformer_key)
		return

	var existing := _records_by_transformer_key.get(transformer_key, null) as TransformerRecord
	if existing != null:
		var changed := false
		if int(existing.source_group_index) != int(source_group_index):
			existing.source_group_index = int(source_group_index)
			changed = true
		if int(existing.priority) != int(priority):
			existing.priority = int(priority)
			changed = true
		if changed:
			_invalidate_record(existing)
		return

	var record := TransformerRecord.new(
		_next_tid,
		transformer_kind,
		hook_kind,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		priority
	)
	_next_tid += 1
	_records_by_transformer_key[transformer_key] = record
	var source_key := record.get_source_key()
	var transformer_keys: Dictionary = _transformer_keys_by_source_key.get(source_key, {})
	transformer_keys[transformer_key] = true
	_transformer_keys_by_source_key[source_key] = transformer_keys
	_invalidate_record(record)


func _remove_record_by_key(transformer_key: String) -> void:
	if transformer_key.is_empty() or !_records_by_transformer_key.has(transformer_key):
		return
	var record: TransformerRecord = _records_by_transformer_key[transformer_key]
	_records_by_transformer_key.erase(transformer_key)
	var source_key := record.get_source_key()
	if _transformer_keys_by_source_key.has(source_key):
		var transformer_keys: Dictionary = _transformer_keys_by_source_key[source_key]
		transformer_keys.erase(transformer_key)
		if transformer_keys.is_empty():
			_transformer_keys_by_source_key.erase(source_key)
		else:
			_transformer_keys_by_source_key[source_key] = transformer_keys
	_invalidate_record(record)


func _invalidate_record(record: TransformerRecord) -> void:
	if record == null:
		return
	if record.is_projection():
		_ordered_projection_cache_valid = false
		_ordered_projection_cache.clear()
	if record.is_interceptor():
		_dirty_interceptor_hooks[record.hook_kind] = true


func _rebuild_projection_cache() -> void:
	var ordered: Array[TransformerRecord] = []
	for record_variant in _records_by_transformer_key.values():
		var record := record_variant as TransformerRecord
		if record == null or !record.is_valid() or !record.is_projection():
			continue
		ordered.append(record.clone())
	ordered.sort_custom(func(a: TransformerRecord, b: TransformerRecord) -> bool:
		return _record_sorts_before(a, b)
	)
	_ordered_projection_cache = ordered
	_ordered_projection_cache_valid = true


func _ensure_interceptor_hook(hook_kind: StringName) -> void:
	if hook_kind == &"":
		return
	if !_dirty_interceptor_hooks.get(hook_kind, true):
		return

	var ordered_interceptors: Array = []
	var ordered_records: Array[TransformerRecord] = []
	for record_variant in _records_by_transformer_key.values():
		var record := record_variant as TransformerRecord
		if record == null or !record.is_valid() or !record.is_interceptor():
			continue
		if record.hook_kind != hook_kind:
			continue
		ordered_records.append(record.clone())
	ordered_records.sort_custom(func(a: TransformerRecord, b: TransformerRecord) -> bool:
		return _record_sorts_before(a, b)
	)

	for record: TransformerRecord in ordered_records:
		var interceptor: Interceptor = _build_interceptor(record)
		if interceptor == null:
			continue
		ordered_interceptors.append(interceptor)

	_interceptors_by_hook[hook_kind] = ordered_interceptors
	_dirty_interceptor_hooks[hook_kind] = false


func _build_interceptor(record: TransformerRecord):
	if record == null:
		return null
	return Interceptor.new(
		record.hook_kind,
		record.source_kind,
		record.source_owner_id,
		record.source_group_index,
		record.source_id,
		record.source_instance_id,
		record.tid,
		record.priority
	)


func _handle_projection_source_change(
	api,
	source_owner_id: int,
	impacted_ids: PackedInt32Array,
	known: bool,
	source_keys: Array[String]
) -> void:
	var applied_targeted := _request_targeted_projection_dirtying(api, source_owner_id, impacted_ids, known)
	if !applied_targeted:
		api._request_replan_all()
		api._request_intent_refresh_all()

	api._refresh_projected_status_cache_for(int(source_owner_id), source_keys)
	if known:
		for raw_id in impacted_ids:
			api._refresh_projected_status_cache_for(int(raw_id), source_keys)
	else:
		_refresh_projection_source_for_all_units(api, source_owner_id, source_keys)

	_request_immediate_projection_flush_if_needed(api)


func _request_targeted_projection_dirtying(
	api,
	source_owner_id: int,
	target_ids: PackedInt32Array,
	known: bool
) -> bool:
	if api == null or api.state == null or !known:
		return false

	var dirty_ids := {}
	_add_impacted_id_if_relevant(api, dirty_ids, int(source_owner_id))
	for raw_id in target_ids:
		_add_impacted_id_if_relevant(api, dirty_ids, int(raw_id))
	if dirty_ids.is_empty():
		return false

	for cid_variant in dirty_ids.keys():
		var cid := int(cid_variant)
		api._request_replan(cid)
		api._request_intent_refresh(cid)
		api._cancel_invalid_plan_immediately_if_needed(cid)
	return true


func _add_impacted_id_if_relevant(api, out: Dictionary, cid: int) -> void:
	if api == null or api.state == null or cid <= 0:
		return
	var unit: CombatantState = api.state.get_unit(cid)
	if unit == null or !unit.is_alive():
		return
	if unit.combatant_data == null or unit.combatant_data.ai == null:
		return
	out[cid] = true


func _request_immediate_projection_flush_if_needed(api) -> void:
	if api == null or api.runtime == null or !bool(api.is_main):
		return
	if api.checkpoint_processor == null:
		return
	var cp = api.checkpoint_processor
	if !cp.has_dirty_planning() and !cp.has_dirty_turn_order() and !cp.has_dirty_outcome():
		return
	api.runtime.request_projection_cleanup_flush()


func _refresh_projection_source_for_all_units(api, source_owner_id: int, source_keys: Array[String]) -> void:
	if api == null or api.state == null:
		return
	for cid_variant in api.state.units.keys():
		var cid := int(cid_variant)
		if cid <= 0 or cid == int(source_owner_id):
			continue
		api._refresh_projected_status_cache_for(cid, source_keys)


static func _merge_target_ids(first: ProjectionImpactInfo, second: ProjectionImpactInfo) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	if first != null and first.known:
		for raw_id in first.target_ids:
			var cid := int(raw_id)
			if cid <= 0 or seen.has(cid):
				continue
			seen[cid] = true
			out.append(cid)
	if second != null and second.known:
		for raw_id in second.target_ids:
			var cid := int(raw_id)
			if cid <= 0 or seen.has(cid):
				continue
			seen[cid] = true
			out.append(cid)
	return out


static func _record_sorts_before(a: TransformerRecord, b: TransformerRecord) -> bool:
	if a == null or b == null:
		return false
	if int(a.priority) != int(b.priority):
		return int(a.priority) < int(b.priority)
	return int(a.tid) < int(b.tid)
