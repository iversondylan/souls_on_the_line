# projection_change_system.gd

class_name ProjectionChangeSystem
extends RefCounted

const ProjectionImpactInfo := preload("res://battle/sim/containers/projection_impact_info.gd")
const ProjectionSourceEntry := preload("res://battle/sim/containers/projection_source_entry.gd")


static func untrack_status_aura(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return

	var bank: ProjectionBank = api.state.projection_bank
	var impact_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id)
	if !bool(bank.untrack_status_aura(source_owner_id, status_id)):
		return

	_handle_status_aura_projection_change(
		api,
		source_owner_id,
		impact_info,
		true,
		[_make_status_aura_source_key(source_owner_id, status_id)]
	)


static func untrack_auras_from_removed_combatant(api: SimBattleAPI, removed_id: int) -> void:
	if api == null or api.state == null or api.state.projection_bank == null:
		return
	if removed_id <= 0:
		return

	var bank: ProjectionBank = api.state.projection_bank
	for entry: ProjectionSourceEntry in bank.get_entries():
		if entry.source_kind == ProjectionBank.SOURCE_KIND_STATUS_AURA \
				and int(entry.source_owner_id) == removed_id:
			untrack_status_aura(
				api,
				int(entry.source_owner_id),
				StringName(entry.source_id)
			)


static func refresh_status_aura(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> void:
	if !_can_use_status_aura_projection_bank(api, source_owner_id, status_id):
		return

	var bank: ProjectionBank = api.state.projection_bank
	var impact_info := bank.get_status_aura_impact_info(api.state, source_owner_id, status_id)
	var should_track := _source_has_live_aura_stack(api, source_owner_id, status_id)
	var had_entry := bool(bank.has_status_aura(source_owner_id, status_id))
	var changed := false

	if should_track and !had_entry:
		changed = bool(bank.track_status_aura(source_owner_id, status_id))
	elif !should_track and had_entry:
		changed = bool(bank.untrack_status_aura(source_owner_id, status_id))

	_handle_status_aura_projection_change(
		api,
		source_owner_id,
		impact_info,
		changed or (should_track and impact_info.known),
		[_make_status_aura_source_key(source_owner_id, status_id)]
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


static func _source_has_live_aura_stack(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> bool:
	if api == null or api.state == null or source_owner_id <= 0 or status_id == &"":
		return false

	var source: CombatantState = api.state.get_unit(source_owner_id)
	if source == null or !source.is_alive() or source.statuses == null:
		return false

	# Pending aura tokens are fully live and project immediately. The projection bank
	# tracks the aura source once, and the cached projected tokens collapse both
	# lanes into a single non-pending projected view for targets.
	return source.statuses.has(status_id, false) or source.statuses.has(status_id, true)


static func _handle_status_aura_projection_change(
	api: SimBattleAPI,
	source_owner_id: int,
	impact_info: ProjectionImpactInfo,
	should_process: bool,
	source_keys: Array[String] = []
) -> void:
	if api == null or api.state == null or !should_process:
		return

	var impacted_ids := PackedInt32Array()
	var known := impact_info != null and impact_info.known
	if known:
		impacted_ids = impact_info.target_ids

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
		api._cancel_invalid_plan_immediately_if_needed(cid)

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


static func _refresh_projection_source_for_all_units(
	api: SimBattleAPI,
	source_owner_id: int,
	source_keys: Array[String]
) -> void:
	if api == null or api.state == null:
		return
	for cid_variant in api.state.units.keys():
		var cid := int(cid_variant)
		if cid <= 0 or cid == int(source_owner_id):
			continue
		api._refresh_projected_status_cache_for(cid, source_keys)


static func _make_status_aura_source_key(source_owner_id: int, status_id: StringName) -> String:
	return ProjectionSourceEntry.make_source_key(
		ProjectionBank.SOURCE_KIND_STATUS_AURA,
		source_owner_id,
		status_id
	)
