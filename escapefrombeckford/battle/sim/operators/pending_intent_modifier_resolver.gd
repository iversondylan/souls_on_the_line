# pending_intent_modifier_resolver.gd

class_name PendingIntentModifierResolver extends RefCounted

static func get_modified_value(
	ctx: NPCAIContext,
	base: int,
	mod_type: Modifier.Type,
	source_id: int
) -> int:
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return base

	var api: SimBattleAPI = ctx.api
	if api.state == null:
		return base

	var pending_sources := _collect_realizing_sources(ctx, source_id)
	var tokens := api.state.get_modifier_tokens_for_cid(source_id, mod_type, pending_sources)
	return SimModifierResolver.apply_tokens(base, mod_type, tokens)

static func _collect_realizing_sources(ctx: NPCAIContext, source_id: int) -> Dictionary:
	var out := {}
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return out

	var api: SimBattleAPI = ctx.api
	var group_index := int(api.get_group(source_id))
	if group_index < 0:
		return out

	var order := _get_relevant_group_order(ctx, group_index)
	var source_pos := order.find(int(source_id))
	if source_pos <= 0:
		return out

	for i in range(source_pos):
		var earlier_id := int(order[i])
		if earlier_id <= 0:
			continue
		if _planned_action_realizes_pending(api, earlier_id):
			out[earlier_id] = true

	return out

static func _get_relevant_group_order(ctx: NPCAIContext, group_index: int) -> Array[int]:
	var out: Array[int] = []
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return out

	var api: SimBattleAPI = ctx.api
	var runtime := ctx.runtime if ctx.runtime != null else api.runtime
	if runtime != null and runtime.turn_engine != null and int(runtime.turn_engine.active_group_index) == int(group_index):
		var snapshot := runtime.turn_engine.build_pending_actor_snapshot()
		if int(snapshot.active_id) > 0:
			out.append(int(snapshot.active_id))
		for cid in snapshot.pending_ids:
			var id := int(cid)
			if id > 0 and !out.has(id):
				out.append(id)
		return out

	return api.get_combatants_in_group(group_index, false)

static func _planned_action_realizes_pending(api: SimBattleAPI, source_id: int) -> bool:
	if api == null or api.state == null:
		return false

	var unit: CombatantState = api.state.get_unit(source_id)
	if unit == null or !unit.is_alive() or unit.combatant_data == null or unit.combatant_data.ai == null:
		return false

	ActionPlanner.ensure_ai_state_initialized(unit)
	var planned_idx := int(unit.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var action := ActionPlanner.get_action_by_idx(unit.combatant_data.ai, planned_idx)
	if action == null:
		return false

	for pkg: NPCEffectPackage in action.effect_packages:
		if pkg == null or pkg.effect == null:
			continue
		if pkg.effect is RealizePendingStatusesEffectSequence:
			return true

	return false
