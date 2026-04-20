# projection_change_system.gd

class_name ProjectionChangeSystem
extends RefCounted

static func sync_status_source(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> void:
	if !_can_use_transformer_registry(api, source_owner_id, status_id):
		return

	var registry := api.state.transformer_registry
	var impact_info := registry.get_projection_impact_info(api.state, source_owner_id, status_id)
	var should_track := _source_has_live_aura_stack(api, source_owner_id, status_id)
	var had_projection := bool(
		registry.has_projection_transformer(
			TransformerRecord.SOURCE_KIND_STATUS_TOKEN,
			source_owner_id,
			status_id
		)
	)
	registry.sync_status_source_transformers(api.state, source_owner_id, status_id)
	registry.mark_source_dirty(TransformerRecord.SOURCE_KIND_STATUS_TOKEN, source_owner_id, status_id)

	# BEFORE: status-sync and arcanum-sync used different projection dirty/refresh paths.
	# AFTER: both feed the same targeted projection-change handler.
	_handle_projection_source_change(
		api,
		source_owner_id,
		impact_info.target_ids if impact_info != null and impact_info.known else PackedInt32Array(),
		impact_info != null and impact_info.known,
		had_projection or should_track or (impact_info != null and impact_info.known),
		[_make_status_aura_source_key(source_owner_id, status_id)]
	)


static func sync_arcanum_source(
	api: SimBattleAPI,
	source_owner_id: int,
	source_group_index: int,
	arcanum_id: StringName
) -> void:
	if api == null or api.state == null or api.state.transformer_registry == null:
		return
	if source_owner_id <= 0 or arcanum_id == &"":
		return

	var registry := api.state.transformer_registry
	var had_projection := bool(
		registry.has_projection_transformer(
			TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
			source_owner_id,
			arcanum_id
		)
	)
	var impact_before := _get_arcanum_projection_impact_info(api, source_owner_id, arcanum_id)

	registry.sync_arcanum_source_transformers(api.state, source_owner_id, source_group_index, arcanum_id)

	var has_projection := bool(
		registry.has_projection_transformer(
			TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
			source_owner_id,
			arcanum_id
		)
	)
	# Only mark dirty while the source is still projection-tracked. When a projection
	# source is removed, cache invalidation is handled via targeted/full refresh with
	# the source key (which removes stale projected contributions).
	if has_projection:
		registry.mark_source_dirty(TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY, source_owner_id, arcanum_id)

	var impact_after := _get_arcanum_projection_impact_info(api, source_owner_id, arcanum_id)
	var merged_impacted_ids := _merge_target_ids(impact_before, impact_after)
	var merged_known := (impact_before != null and impact_before.known) or (impact_after != null and impact_after.known)

	_handle_projection_source_change(
		api,
		source_owner_id,
		merged_impacted_ids,
		merged_known,
		had_projection or has_projection or merged_known,
		[
			TransformerRecord.make_source_key(
				TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
				source_owner_id,
				arcanum_id
			)
		]
	)


static func _can_use_transformer_registry(
	api: SimBattleAPI,
	source_owner_id: int,
	status_id: StringName
) -> bool:
	return (
		api != null
		and api.state != null
		and api.state.transformer_registry != null
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
	if source == null or !source.is_alive():
		return false

	# Pending aura tokens are fully live and project immediately. The projection bank
	# tracks the aura source once, and the cached projected tokens collapse both
	# lanes into a single non-pending projected view for targets.
	return source.statuses.has(status_id, false) or source.statuses.has(status_id, true)


static func _handle_projection_source_change(
	api: SimBattleAPI,
	source_owner_id: int,
	impacted_ids: PackedInt32Array,
	known: bool,
	should_process: bool,
	source_keys: Array[String] = []
) -> void:
	if api == null or api.state == null or !should_process:
		return

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
	return TransformerRecord.make_source_key(
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN,
		source_owner_id,
		status_id
	)


static func _get_arcanum_projection_impact_info(
	api: SimBattleAPI,
	source_owner_id: int,
	arcanum_id: StringName
) -> ProjectionImpactInfo:
	var target_ids := PackedInt32Array()
	if api == null or api.state == null or source_owner_id <= 0 or arcanum_id == &"":
		return ProjectionImpactInfo.new(false, target_ids)
	if api.state.arcana_catalog == null or api.state.arcana == null:
		return ProjectionImpactInfo.new(false, target_ids)

	var entry: ArcanumEntry = api.state.arcana.get_entry(arcanum_id)
	var proto: Arcanum = api.state.arcana_catalog.get_proto(arcanum_id)
	# Arcanum sources only participate in projection cache work when they explicitly
	# project statuses; interceptor-only arcana are handled by interceptor sync alone.
	if entry == null or proto == null or !proto.affects_others():
		return ProjectionImpactInfo.new(false, target_ids)

	var seen := {}
	for unit_value in api.state.units.values():
		var unit: CombatantState = unit_value as CombatantState
		if unit == null or !unit.is_alive():
			continue
		var target_id := int(unit.id)
		if target_id <= 0 or seen.has(target_id):
			continue
		if !proto.affects_target(api.state, int(source_owner_id), target_id):
			continue
		seen[target_id] = true
		target_ids.append(target_id)

	return ProjectionImpactInfo.new(true, target_ids)


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
