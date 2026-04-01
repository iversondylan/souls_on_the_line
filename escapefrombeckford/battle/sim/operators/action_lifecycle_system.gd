# action_lifecycle_system.gd

class_name ActionLifecycleSystem extends RefCounted

# Owns phase-based invocation of IntentLifecycleModel hooks.
# Planning still belongs to ActionPlanner.
# State mutation still goes through SimBattleAPI.

static func on_group_turn_begin(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	var opposing_group := api.get_opposing_group(group_index)

	for cid in api.get_combatants_in_group(opposing_group, false):
		var u: CombatantState = api.state.get_unit(int(cid))
		if u == null or !u.is_alive():
			continue
		if u.combatant_data == null or u.combatant_data.ai == null:
			continue

		ActionPlanner.ensure_ai_state_initialized(u)
		if !bool(u.ai_state.get(Keys.FIRST_INTENTS_READY, false)):
			continue
		if bool(u.ai_state.get(Keys.IS_ACTING, false)):
			continue

		var ctx := _make_ai_ctx(api, u)
		if bool(u.ai_state.get(&"telegraph_committed", false)):
			continue

		var action := _get_planned_action_for_unit(u)
		if action == null:
			continue

		for m: IntentLifecycleModel in action.intent_lifecycle_models:
			if m != null:
				m.on_opposing_group_turn_started(ctx)

		u.ai_state[&"telegraph_committed"] = true

static func on_group_turn_end(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	for cid in api.get_combatants_in_group(group_index, true):
		var u: CombatantState = api.state.get_unit(int(cid))
		if u == null:
			continue
		if u.combatant_data == null or u.combatant_data.ai == null:
			continue

		ActionPlanner.ensure_ai_state_initialized(u)

		var ctx := _make_ai_ctx(api, u)
		var action := _get_planned_action_for_unit(u)
		if action != null:
			for m: IntentLifecycleModel in action.intent_lifecycle_models:
				if m != null:
					m.on_owner_group_turn_ended(ctx)

	for cid in api.get_combatants_in_group(group_index, true):
		var u2: CombatantState = api.state.get_unit(int(cid))
		if u2 != null and u2.ai_state != null:
			u2.ai_state[&"telegraph_committed"] = false

static func on_action_execution_started(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.api == null or ctx.combatant_data == null or ctx.combatant_data.ai == null:
		return
	if ctx.api.state == null or ctx.api.state.has_terminal_outcome():
		return
	var action := _get_planned_action_for_ctx(ctx)
	if action == null:
		return

	ctx.action_name = action.resolve_display_name(ctx.params)
	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m != null:
			m.on_action_execution_started(ctx)
	ctx.action_name = ""

static func on_action_execution_completed(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.api == null or ctx.combatant_data == null or ctx.combatant_data.ai == null:
		return
	if ctx.api.state == null or ctx.api.state.has_terminal_outcome():
		return
	var action := _get_planned_action_for_ctx(ctx)
	if action == null:
		return

	ctx.action_name = action.resolve_display_name(ctx.params)
	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m != null:
			m.on_action_execution_completed(ctx)
	ctx.action_name = ""

static func _get_planned_action_for_unit(u: CombatantState) -> NPCAction:
	if u == null or u.combatant_data == null or u.combatant_data.ai == null or u.ai_state == null:
		return null
	var idx := int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	return ActionPlanner.get_action_by_idx(u.combatant_data.ai, idx)

static func _get_planned_action_for_ctx(ctx: NPCAIContext) -> NPCAction:
	if ctx == null or ctx.combatant_data == null or ctx.combatant_data.ai == null or ctx.state == null:
		return null
	var idx := int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	return ActionPlanner.get_action_by_idx(ctx.combatant_data.ai, idx)

static func _make_ai_ctx(api: SimBattleAPI, u: CombatantState) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.runtime = api.runtime if api != null else null
	ctx.cid = int(u.id)
	ctx.combatant_state = u
	ctx.combatant_data = u.combatant_data
	ctx.state = u.ai_state
	ctx.rng = u.rng
	ctx.params = {}
	ctx.forecast = false
	return ctx
