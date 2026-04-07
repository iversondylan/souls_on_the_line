# projection_change_system.gd

class_name ProjectionChangeSystem
extends RefCounted


static func track_status_aura(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName,
	pending := false
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return

	var bank: ProjectionBank = api.state.projection_bank
	var impact_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id, pending)
	var changed := bool(bank.track_status_aura(source_owner_id, status_id, pending))
	_handle_status_aura_projection_change(
		api,
		source_owner_id,
		impact_info,
		changed or bool(impact_info.get("known", false))
	)


static func untrack_status_aura(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName,
	pending := false
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return

	var bank: ProjectionBank = api.state.projection_bank
	var impact_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id, pending)
	if !bool(bank.untrack_status_aura(source_owner_id, status_id, pending)):
		return

	_handle_status_aura_projection_change(api, source_owner_id, impact_info, true)


static func untrack_auras_from_removed_combatant(api: SimBattleAPI, removed_id: int) -> void:
	if api == null or api.state == null or api.state.projection_bank == null:
		return
	if removed_id <= 0:
		return

	var bank: ProjectionBank = api.state.projection_bank
	for entry: Dictionary in bank.get_entries():
		if StringName(entry.get("source_kind", &"")) == ProjectionBank.SOURCE_KIND_STATUS_AURA \
				and int(entry.get("source_owner_id", 0)) == removed_id:
			untrack_status_aura(
				api,
				int(entry.get("source_owner_id", 0)),
				StringName(entry.get("source_id", &"")),
				bool(entry.get("pending", false))
			)


static func swap_status_aura_lane(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName,
	from_pending: bool,
	to_pending: bool
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return
	if bool(from_pending) == bool(to_pending):
		refresh_status_aura(api, source_owner_id, status_id, from_pending)
		return

	var bank: ProjectionBank = api.state.projection_bank
	var before_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id, from_pending)
	var changed := false
	changed = bool(bank.untrack_status_aura(source_owner_id, status_id, from_pending)) or changed
	changed = bool(bank.track_status_aura(source_owner_id, status_id, to_pending)) or changed
	var after_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id, to_pending)

	var merged_info := _merge_impact_info(before_info, after_info)
	_handle_status_aura_projection_change(api, source_owner_id, merged_info, changed)


static func refresh_status_aura(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName,
	pending := false
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return

	var bank: ProjectionBank = api.state.projection_bank
	var impact_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id, pending)
	_handle_status_aura_projection_change(
		api,
		source_owner_id,
		impact_info,
		bool(impact_info.get("known", false))
	)


static func _can_use_status_aura_projection_bank(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> bool:
	return (
		api != null
		and api.state != null
		and api.state.projection_bank != null
		and source_owner_id > 0
		and status_id != &""
	)


static func _merge_impact_info(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged_targets := PackedInt32Array()
	var seen := {}
	for info in [a, b]:
		var ids: PackedInt32Array = info.get("target_ids", PackedInt32Array())
		for raw_id in ids:
			var cid := int(raw_id)
			if cid <= 0 or seen.has(cid):
				continue
			seen[cid] = true
			merged_targets.append(cid)

	return {
		"known": bool(a.get("known", false)) and bool(b.get("known", false)),
		"target_ids": merged_targets,
	}


static func _handle_status_aura_projection_change(
	api: SimBattleAPI,
	source_owner_id: int,
	impact_info: Dictionary,
	should_process: bool
) -> void:
	if api == null or api.state == null or !should_process:
		return

	var impacted_ids := PackedInt32Array()
	var known := bool(impact_info.get("known", false))
	if known:
		impacted_ids = impact_info.get("target_ids", PackedInt32Array())

	var applied_targeted := _request_targeted_projection_dirtying(api, source_owner_id, impacted_ids, known)
	if !applied_targeted:
		api._request_replan_all()
		api._request_intent_refresh_all()

	# Rebuild modifier caches for all units whose effective modifier tokens
	# may have changed due to the aura projection update.
	if known:
		api._rebuild_modifier_cache_for(int(source_owner_id))
		for raw_id in impacted_ids:
			api._rebuild_modifier_cache_for(int(raw_id))
	else:
		# Impact unknown: conservatively rebuild every unit.
		api._rebuild_all_modifier_caches()

	_request_immediate_projection_flush_if_needed(api)


static func _request_targeted_projection_dirtying(
	api: SimBattleAPI,
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

	return true


static func _add_impacted_id_if_relevant(api: SimBattleAPI, out: Dictionary, cid: int) -> void:
	if api == null or api.state == null or cid <= 0:
		return

	var unit: CombatantState = api.state.get_unit(cid)
	if unit == null or !unit.is_alive():
		return
	if unit.combatant_data == null or unit.combatant_data.ai == null:
		return

	out[cid] = true


static func _request_immediate_projection_flush_if_needed(api: SimBattleAPI) -> void:
	if api == null or api.runtime == null or !bool(api.is_main):
		return
	if api.checkpoint_processor == null:
		return

	var cp := api.checkpoint_processor
	if !cp.has_dirty_planning() and !cp.has_dirty_turn_order() and !cp.has_dirty_outcome():
		return

	api.runtime.request_projection_cleanup_flush()
