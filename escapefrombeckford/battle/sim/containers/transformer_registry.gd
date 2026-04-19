class_name TransformerRegistry extends RefCounted


const FRIENDLY := 0
const ENEMY := 1

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


func has_projection_transformer(source_kind: StringName, source_owner_id: int, source_id: StringName) -> bool:
	return _records_by_transformer_key.has(
		TransformerRecord.make_transformer_key(
			TransformerRecord.TRANSFORMER_KIND_PROJECTION,
			&"",
			source_kind,
			source_owner_id,
			source_id
		)
	)


func mark_transformer_dirty(transformer_key: String) -> void:
	if transformer_key.is_empty() or !_records_by_transformer_key.has(transformer_key):
		return
	var record: TransformerRecord = _records_by_transformer_key[transformer_key]
	_invalidate_record(record)


func mark_interceptor_hook_dirty(hook_kind: StringName) -> void:
	if hook_kind == &"":
		return
	_dirty_interceptor_hooks[hook_kind] = true


func mark_source_dirty(source_kind: StringName, source_owner_id: int, source_id: StringName) -> void:
	var source_key := TransformerRecord.make_source_key(source_kind, source_owner_id, source_id)
	if source_key.is_empty() or !_transformer_keys_by_source_key.has(source_key):
		return
	var transformer_keys: Dictionary = _transformer_keys_by_source_key[source_key]
	for transformer_key_variant in transformer_keys.keys():
		mark_transformer_dirty(String(transformer_key_variant))


func get_projection_records() -> Array[TransformerRecord]:
	if !_ordered_projection_cache_valid:
		_rebuild_projection_cache()
	# Read-only contract: callers must not mutate this array or contained records.
	# Violating this contract can corrupt shared cache state. We intentionally removed
	# per-read cloning here to reduce hot-path allocation pressure. If a caller must
	# mutate, it must clone the array and records first.
	return _ordered_projection_cache


func get_interceptors_for_hook(state, hook_kind: StringName) -> Array[Interceptor]:
	_ensure_interceptor_hook(state, hook_kind)
	# Read-only contract: callers must not mutate this array or contained interceptors.
	# Violating this contract can corrupt shared hook cache state. We intentionally
	# removed per-read cloning here to reduce hot-path allocation pressure. If a caller
	# must mutate, it must clone the array and interceptors first.
	var ordered: Array[Interceptor] = _interceptors_by_hook.get(hook_kind, [])
	return ordered


func get_projection_impact_info(
	state: BattleState,
	source_owner_id: int,
	status_id: StringName
) -> ProjectionImpactInfo:
	var target_ids := PackedInt32Array()
	if state == null or state.status_catalog == null or source_owner_id <= 0 or status_id == &"":
		return ProjectionImpactInfo.new(false, target_ids)

	var source_unit: CombatantState = state.get_unit(int(source_owner_id))
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
		if !aura_proto.affects_target(state, int(source_owner_id), target_id):
			continue

		seen[target_id] = true
		target_ids.append(target_id)

	return ProjectionImpactInfo.new(true, target_ids)


func sync_status_source_transformers(
	state: BattleState,
	source_owner_id: int,
	status_id: StringName
) -> void:
	if state == null or source_owner_id <= 0 or status_id == &"":
		return

	var owner: CombatantState = state.get_unit(source_owner_id)
	var group_index := int(owner.team) if owner != null else -1
	var proto: Status = state.status_catalog.get_proto(status_id) if state != null and state.status_catalog != null else null
	var wants_projection := false
	var wants_interceptor := false

	if owner != null and owner.is_alive() and owner.statuses != null and proto != null:
		wants_projection = proto is Aura and (
			owner.statuses.has(status_id, false) or owner.statuses.has(status_id, true)
		)
		wants_interceptor = bool(proto.listens_for_any_death()) and owner.statuses.has(status_id, false)

	_sync_projection_record(
		wants_projection,
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN,
		source_owner_id,
		group_index,
		status_id,
		int(proto.transformer_priority) if proto != null else 1
	)
	_sync_interceptor_record(
		wants_interceptor,
		Interceptor.HOOK_ON_ANY_DEATH,
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN,
		source_owner_id,
		group_index,
		status_id,
		int(proto.transformer_priority) if proto != null else 1
	)


func sync_arcanum_source_transformers(
	state: BattleState,
	source_owner_id: int,
	source_group_index: int,
	arcanum_id: StringName
) -> void:
	if state == null or source_owner_id <= 0 or arcanum_id == &"":
		return

	var proto: Arcanum = state.arcana_catalog.get_proto(arcanum_id) if state.arcana_catalog != null else null
	var entry: ArcanumEntry = state.arcana.get_entry(arcanum_id) if state.arcana != null else null
	var wants_projection := proto != null and entry != null and bool(proto.affects_others())
	var wants_interceptor := proto != null and entry != null and bool(proto.listens_for_any_death())
	var priority := int(proto.transformer_priority) if proto != null else 1

	_sync_projection_record(
		wants_projection,
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
		source_owner_id,
		source_group_index,
		arcanum_id,
		priority
	)
	_sync_interceptor_record(
		wants_interceptor,
		Interceptor.HOOK_ON_ANY_DEATH,
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
		source_owner_id,
		source_group_index,
		arcanum_id,
		priority
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
			sync_arcanum_source_transformers(state, source_owner_id, source_group_index, entry.id)

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
		sync_arcanum_source_transformers(state, source_owner_id, source_group_index, StringName(arcanum_id))


func get_projection_source_keys_for_owner(source_owner_id: int) -> Array[String]:
	var out: Array[String] = []
	for record: TransformerRecord in get_projection_records():
		if record == null or int(record.source_owner_id) != int(source_owner_id):
			continue
		out.append(record.get_source_key())
	return out


func get_projection_source_record(source_kind: StringName, source_owner_id: int, source_id: StringName) -> TransformerRecord:
	var transformer_key := TransformerRecord.make_transformer_key(
		TransformerRecord.TRANSFORMER_KIND_PROJECTION,
		&"",
		source_kind,
		source_owner_id,
		source_id
	)
	if transformer_key.is_empty() or !_records_by_transformer_key.has(transformer_key):
		return null
	var record := _records_by_transformer_key[transformer_key] as TransformerRecord
	return record.clone() if record != null else null


func remove_transformers_for_source(source_kind: StringName, source_owner_id: int, source_id: StringName) -> void:
	var source_key := TransformerRecord.make_source_key(source_kind, source_owner_id, source_id)
	if source_key.is_empty() or !_transformer_keys_by_source_key.has(source_key):
		return
	var transformer_keys: Array[String] = []
	for transformer_key_variant in _transformer_keys_by_source_key[source_key].keys():
		transformer_keys.append(String(transformer_key_variant))
	for transformer_key in transformer_keys:
		_remove_record_by_key(transformer_key)


func _sync_projection_record(
	wants_record: bool,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
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
		priority
	)


func _sync_interceptor_record(
	wants_record: bool,
	hook_kind: StringName,
	source_kind: StringName,
	source_owner_id: int,
	source_group_index: int,
	source_id: StringName,
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
	priority: int
) -> void:
	var transformer_key := TransformerRecord.make_transformer_key(
		transformer_kind,
		hook_kind,
		source_kind,
		source_owner_id,
		source_id
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


func _ensure_interceptor_hook(_state, hook_kind: StringName) -> void:
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
	match record.hook_kind:
		Interceptor.HOOK_ON_ANY_DEATH:
			return OnAnyDeathInterceptor.new(
				record.source_kind,
				record.source_owner_id,
				record.source_group_index,
				record.source_id,
				record.tid,
				record.priority
			)
		_:
			return null


static func _record_sorts_before(a: TransformerRecord, b: TransformerRecord) -> bool:
	if a == null or b == null:
		return false
	if int(a.priority) != int(b.priority):
		return int(a.priority) < int(b.priority)
	return int(a.tid) < int(b.tid)
