# action_executor.gd

class_name ActionExecutor extends RefCounted

static func execute_npc_turn(api: SimBattleAPI, cid: int) -> void:
	if api == null:
		return
	if cid <= 0 or !api.is_alive(cid):
		return

	var u: CombatantState = api.state.get_unit(int(cid))
	if u == null or u.combatant_data == null:
		return

	var profile: NPCAIProfile = u.combatant_data.ai
	if profile == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	var ctx := ActionPlanner.make_context(api, u)

	if !bool(ctx.state.get(ActionPlanner.FIRST_INTENTS_READY, false)):
		ctx.state[ActionPlanner.FIRST_INTENTS_READY] = true

	ActionPlanner.ensure_valid_plan_sim(profile, ctx, true)

	if int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) < 0:
		ActionPlanner.plan_next_intent_sim(profile, ctx, true)

	var idx := int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var action := ActionPlanner.get_action_by_idx(profile, idx)
	if action == null:
		_finish_turn(ctx)
		return

	ctx.state[ActionPlanner.IS_ACTING] = true

	ActionLifecycleSystem.on_action_execution_started(ctx)

	for sm: StateModel in action.state_models:
		if sm != null:
			sm.change_state_sim(ctx)

	for pkg: NPCEffectPackage in action.effect_packages:
		if pkg == null:
			continue

		ctx.params.clear()

		for sm2: StateModel in pkg.state_models:
			if sm2 != null:
				sm2.change_state_sim(ctx)

		for pm: ParamModel in pkg.param_models:
			if pm != null:
				pm.change_params_sim(ctx)

		if pkg.effect != null and pkg.effect.has_method("execute_sim"):
			pkg.effect.execute_sim(ctx)

	ctx.state[ActionPlanner.KEY_PLANNED_IDX] = -1
	ActionIntentPresenter.emit_set_intent(api, profile, ctx, -1)
	ctx.state[ActionPlanner.IS_ACTING] = false
	ctx.state[ActionPlanner.STABILITY_BROKEN] = false
	ctx.state[ActionPlanner.ACTIONS_TAKEN] = int(ctx.state.get(ActionPlanner.ACTIONS_TAKEN, 0)) + 1


static func _finish_turn(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.state == null:
		return

	ctx.state[ActionPlanner.IS_ACTING] = false
	ctx.state[ActionPlanner.STABILITY_BROKEN] = false
