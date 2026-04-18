# projection_bank.gd

class_name ProjectionBank extends RefCounted

const ProjectionImpactInfo := preload("res://battle/sim/containers/projection_impact_info.gd")
const ProjectionSourceEntry := preload("res://battle/sim/containers/projection_source_entry.gd")
const ArcanumEntry := preload("res://battle/sim/containers/arcanum_entry.gd")

const SOURCE_KIND_STATUS_AURA := &"status_aura"
const SOURCE_KIND_ARCANUM := &"arcanum"

var _entries_by_key: Dictionary = {}
var _ordered_entries_cache: Array[ProjectionSourceEntry] = []
var _ordered_entries_cache_valid := false


func track_status_aura(source_owner_id: int, status_id: StringName) -> bool:
	return _track(SOURCE_KIND_STATUS_AURA, int(source_owner_id), StringName(status_id))


func untrack_status_aura(source_owner_id: int, status_id: StringName) -> bool:
	var key := _make_key(SOURCE_KIND_STATUS_AURA, int(source_owner_id), StringName(status_id))
	var existed := _entries_by_key.has(key)
	_entries_by_key.erase(key)
	if existed:
		_invalidate_ordered_entries_cache()
	return existed


func has_status_aura(source_owner_id: int, status_id: StringName) -> bool:
	return _entries_by_key.has(
		_make_key(SOURCE_KIND_STATUS_AURA, int(source_owner_id), StringName(status_id))
	)


func get_status_aura_impact_info(
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


func rebuild_arcanum_entries(state: BattleState, owner_id: int) -> void:
	clear_arcanum_entries()

	if state == null or state.arcana == null or state.arcana_catalog == null or owner_id <= 0:
		return

	for arcanum_entry: ArcanumEntry in state.arcana.list:
		if arcanum_entry == null or arcanum_entry.id == &"":
			continue

		var arcanum_proto: Arcanum = state.arcana_catalog.get_proto(arcanum_entry.id)
		if arcanum_proto == null or !arcanum_proto.affects_others():
			continue

		_track(SOURCE_KIND_ARCANUM, owner_id, arcanum_entry.id)


func clear() -> void:
	_entries_by_key.clear()
	_invalidate_ordered_entries_cache()


func clear_arcanum_entries() -> void:
	var keys_to_remove: Array[String] = []
	for key in _entries_by_key.keys():
		var entry: ProjectionSourceEntry = _entries_by_key[key]
		if entry != null and entry.source_kind == SOURCE_KIND_ARCANUM:
			keys_to_remove.append(String(key))

	for key: String in keys_to_remove:
		_entries_by_key.erase(key)
	if !keys_to_remove.is_empty():
		_invalidate_ordered_entries_cache()


func get_entries() -> Array[ProjectionSourceEntry]:
	if !_ordered_entries_cache_valid:
		_rebuild_ordered_entries_cache()
	var copied: Array[ProjectionSourceEntry] = []
	for entry: ProjectionSourceEntry in _ordered_entries_cache:
		copied.append(entry)
	return copied


func clone():
	var bank = get_script().new()
	for key in _entries_by_key.keys():
		var entry: ProjectionSourceEntry = _entries_by_key[key]
		if entry != null:
			bank._entries_by_key[key] = entry.clone()
	return bank


func _track(source_kind: StringName, source_owner_id: int, source_id: StringName) -> bool:
	if source_kind == &"" or source_owner_id <= 0 or source_id == &"":
		return false

	var entry := ProjectionSourceEntry.new(source_kind, source_owner_id, source_id)
	var key := entry.get_source_key()
	var changed := !_entries_by_key.has(key)
	_entries_by_key[key] = entry
	if changed:
		_invalidate_ordered_entries_cache()
	return changed


func _make_key(source_kind: StringName, source_owner_id: int, source_id: StringName) -> String:
	return ProjectionSourceEntry.make_source_key(source_kind, source_owner_id, source_id)

func _invalidate_ordered_entries_cache() -> void:
	_ordered_entries_cache_valid = false
	_ordered_entries_cache.clear()

func _rebuild_ordered_entries_cache() -> void:
	var ordered: Array[ProjectionSourceEntry] = []
	for key in _entries_by_key.keys():
		var entry: ProjectionSourceEntry = _entries_by_key[key]
		if entry != null and entry.is_valid():
			var cloned: ProjectionSourceEntry = entry.clone()
			ordered.append(cloned)

	ordered.sort_custom(func(a: ProjectionSourceEntry, b: ProjectionSourceEntry) -> bool:
		var a_kind := String(a.source_kind)
		var b_kind := String(b.source_kind)
		if a_kind != b_kind:
			return a_kind < b_kind

		var a_owner := int(a.source_owner_id)
		var b_owner := int(b.source_owner_id)
		if a_owner != b_owner:
			return a_owner < b_owner

		var a_source := String(a.source_id)
		var b_source := String(b.source_id)
		if a_source != b_source:
			return a_source < b_source
		return false
	)
	_ordered_entries_cache = ordered
	_ordered_entries_cache_valid = true
