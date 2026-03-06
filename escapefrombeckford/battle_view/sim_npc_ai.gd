# sim_npc_ai.gd

class_name SimNPCAI extends RefCounted

static func run_turn(api: SimBattleAPI, state: BattleState, cid: int) -> void:
	if api == null or state == null:
		return
	if cid <= 0 or !api.is_alive(cid):
		return

	var u: CombatantState = state.get_unit(cid)
	if u == null:
		return
	var profile: NPCAIProfile = u.combatant_data.ai if u.combatant_data else null
	if profile == null:
		# no AI, just end turn
		return

	# init ai_state defaults if missing
	_ensure_ai_state_initialized(u, state)

	var ctx := _make_ctx(api, state, u, profile)
	ctx.state[NPCAIBehavior.IS_ACTING] = true

	# Safety: ensure plan exists
	if !bool(ctx.state.get(NPCAIBehavior.FIRST_INTENTS_READY, false)):
		ctx.state[NPCAIBehavior.FIRST_INTENTS_READY] = true
		# like LIVE: one-time plan + show
		ensure_valid_plan_sim(profile, ctx)

	ensure_valid_plan_sim(profile, ctx)

	var idx := int(ctx.state.get(NPCAIBehavior.KEY_PLANNED_IDX, -1))
	var action := _get_action_by_idx(profile, idx)
	if action == null:
		_finish_turn(ctx)
		return

	# ability started hooks
	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m:
			m.on_ability_started_sim(ctx)

	# action-level state models
	for m: StateModel in action.state_models:
		if m:
			m.change_state_sim(ctx)

	# execute packages
	for pkg: NPCEffectPackage in action.effect_packages:
		if pkg == null:
			continue
		ctx.params.clear()

		for sm: StateModel in pkg.state_models:
			if sm:
				sm.change_state_sim(ctx)
		for pm: ParamModel in pkg.param_models:
			if pm:
				pm.change_params_sim(ctx)

		# EFFECT: preferred path
		if pkg.effect and pkg.effect.has_method("execute_sim"):
			pkg.effect.execute_sim(ctx)
		else:
			# fallback: no-op
			pass

	# done: clear plan, etc
	ctx.state[NPCAIBehavior.KEY_PLANNED_IDX] = -1
	ctx.state[NPCAIBehavior.IS_ACTING] = false
	ctx.state[NPCAIBehavior.STABILITY_BROKEN] = false
	ctx.state[NPCAIBehavior.ACTIONS_TAKEN] = int(ctx.state.get(NPCAIBehavior.ACTIONS_TAKEN, 0)) + 1

static func _ensure_ai_state_initialized(u: CombatantState, state: BattleState) -> void:
	if u.ai_state == null:
		u.ai_state = {}
	var s := u.ai_state
	if !s.has(NPCAIBehavior.KEY_PLANNED_IDX):
		s[NPCAIBehavior.KEY_PLANNED_IDX] = -1
	if !s.has(NPCAIBehavior.FIRST_INTENTS_READY):
		s[NPCAIBehavior.FIRST_INTENTS_READY] = false
	if !s.has(NPCAIBehavior.IS_ACTING):
		s[NPCAIBehavior.IS_ACTING] = false
	if !s.has(NPCAIBehavior.STABILITY_BROKEN):
		s[NPCAIBehavior.STABILITY_BROKEN] = false
	if !s.has("telegraph_committed"):
		s["telegraph_committed"] = false
	# etc: HP_AT_TURN_START, DMG_SINCE_LAST_TURN if you want to preserve those semantics

static func _make_ctx(api: SimBattleAPI, state: BattleState, u: CombatantState, profile: NPCAIProfile) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.state = u.ai_state
	ctx.rng = u.rng
	ctx.params = {}
	ctx.forecast = false
	ctx.combatant_state = u
	ctx.cid = u.id
	return ctx

# --- planning functions: copy from NPCAIBehavior and swap to *_sim ---
static func ensure_valid_plan_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks: bool = true) -> void:
	# copy logic; use is_performable_sim, on_intent_canceled_sim, etc.
	pass
