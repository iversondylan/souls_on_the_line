# action_planner.gd
class_name ActionPlanner extends RefCounted

const KEY_PLANNED_IDX := NPCAIBehavior.KEY_PLANNED_IDX
const HP_AT_TURN_START := NPCAIBehavior.HP_AT_TURN_START
const DMG_SINCE_LAST_TURN := NPCAIBehavior.DMG_SINCE_LAST_TURN
const STABILITY_BROKEN := NPCAIBehavior.STABILITY_BROKEN
const IS_ACTING := NPCAIBehavior.IS_ACTING
const ACTIONS_TAKEN := NPCAIBehavior.ACTIONS_TAKEN
const FIRST_INTENTS_READY := NPCAIBehavior.FIRST_INTENTS_READY

static var debug := true

static func run_turn(api: SimBattleAPI, cid: int) -> void:
	print("ation_planner.gd run_turn()")
	if api == null or api.state == null:
		return
	if cid <= 0 or !api.is_alive(cid):
		return

	var u: CombatantState = api.state.get_unit(cid)
	if u == null or u.combatant_data == null:
		return

	var profile: NPCAIProfile = u.combatant_data.ai
	if profile == null:
		_dbg("SIM AI: cid=%d has no profile; skipping" % cid)
		return

	_ensure_ai_state_initialized(u)

	var ctx := _make_context(api, u)

	# Make sure "first intents ready" and a plan exists BEFORE acting
	if !bool(ctx.state.get(FIRST_INTENTS_READY, false)):
		ctx.state[FIRST_INTENTS_READY] = true

	ensure_valid_plan_sim(profile, ctx, true)

	# Hard fallback: if still no plan, force a roll (this is your “don’t bail” policy)
	if int(ctx.state.get(KEY_PLANNED_IDX, -1)) < 0:
		plan_next_intent_sim(profile, ctx, true)
	
	print("SIM plan cid=%d planned_idx=%d rolls=%d seed=%d" % [
		cid,
		int(ctx.state.get(KEY_PLANNED_IDX, -1)),
		int(ctx.rng.rolls) if ctx.rng else -1,
		int(ctx.rng.seed) if ctx.rng else -1
	])
	
	var idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	var action := _get_action_by_idx(profile, idx)
	if action == null:
		_dbg("SIM AI: cid=%d no valid action planned (idx=%d)" % [cid, idx])
		_finish_turn(ctx)
		return

	# NOW mark acting
	ctx.state[IS_ACTING] = true

	_dbg("SIM AI: cid=%d execute action idx=%d" % [cid, idx])

	# Ability started hooks
	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m:
			m.on_ability_started_sim(ctx)

	# Action-level state models (once)
	for sm: StateModel in action.state_models:
		if sm:
			sm.change_state_sim(ctx)

	# Execute packages in order
	for pkg: NPCEffectPackage in action.effect_packages:
		print("ation_planner.gd doing a pkg()")
		if pkg == null:
			continue

		ctx.params.clear()

		for sm2: StateModel in pkg.state_models:
			if sm2:
				sm2.change_state_sim(ctx)

		for pm: ParamModel in pkg.param_models:
			if pm:
				pm.change_params_sim(ctx)

		if pkg.effect != null and pkg.effect.has_method("execute_sim"):
			pkg.effect.execute_sim(ctx)
		else:
			# If you want a hard error:
			_dbg("SIM AI: missing execute_sim on effect %s" % [pkg.effect])

	# Finish (match LIVE semantics)
	ctx.state[KEY_PLANNED_IDX] = -1
	ctx.state[IS_ACTING] = false
	ctx.state[STABILITY_BROKEN] = false
	ctx.state[ACTIONS_TAKEN] = int(ctx.state.get(ACTIONS_TAKEN, 0)) + 1

static func _finish_turn(ctx: NPCAIContext) -> void:
	if ctx == null:
		return
	if ctx.state:
		ctx.state[IS_ACTING] = false
		ctx.state[STABILITY_BROKEN] = false

static func _make_context(api: SimBattleAPI, u: CombatantState) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.cid = int(u.id)
	ctx.combatant_state = u
	ctx.combatant_data = u.combatant_data
	ctx.rng = u.rng
	ctx.state = u.ai_state
	ctx.params = {}
	ctx.forecast = false
	return ctx

static func _ensure_ai_state_initialized(u: CombatantState) -> void:
	if u.ai_state == null:
		u.ai_state = {}
	var s := u.ai_state

	if !s.has(HP_AT_TURN_START):
		s[HP_AT_TURN_START] = int(u.health)
	if !s.has(DMG_SINCE_LAST_TURN):
		s[DMG_SINCE_LAST_TURN] = 0
	if !s.has(KEY_PLANNED_IDX):
		s[KEY_PLANNED_IDX] = -1
	if !s.has("telegraph_committed"):
		s["telegraph_committed"] = false
	if !s.has(IS_ACTING):
		s[IS_ACTING] = false
	if !s.has(FIRST_INTENTS_READY):
		s[FIRST_INTENTS_READY] = false
	if !s.has(STABILITY_BROKEN):
		s[STABILITY_BROKEN] = false
	if !s.has(ACTIONS_TAKEN):
		s[ACTIONS_TAKEN] = 0

static func ensure_valid_plan_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks: bool = true) -> void:
	print("action_planner.gd ensure_valid_plan_sim()")
	if profile == null or ctx == null:
		print("null profile or ctx")
		return
	if bool(ctx.state.get(IS_ACTING, false)):
		# Same as LIVE: don't replan while acting
		print("is acting")
		return

	# If no plan key, plan
	if !ctx.state.has(KEY_PLANNED_IDX):
		print("need to plan")
		plan_next_intent_sim(profile, ctx, allow_hooks)
		return

	var idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	var action := _get_action_by_idx(profile, idx)
	if action == null or !_is_action_performable_sim(action, ctx):
		if allow_hooks:
			_on_planned_intent_changed_sim(profile, idx, -1, ctx)
		ctx.state[KEY_PLANNED_IDX] = -1
		plan_next_intent_sim(profile, ctx, allow_hooks)

static func plan_next_intent_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks: bool = false) -> void:
	print("action_planner.gd plan_next_intent_sim()")
	if profile == null or ctx == null:
		return

	var state := ctx.state if ctx.state else {}
	var prev_idx: int = int(state.get(KEY_PLANNED_IDX, -1))

	# 1) CONDITIONAL always wins
	var cond_idx := _get_first_conditional_idx_sim(profile, ctx)
	if cond_idx != -1:
		if prev_idx == cond_idx:
			return
		if allow_hooks:
			_on_planned_intent_changed_sim(profile, prev_idx, cond_idx, ctx)
		state[KEY_PLANNED_IDX] = cond_idx
		return

	# 2) cannot change plan while acting
	if prev_idx != -1 and !_can_cancel_intent_sim(state):
		return

	# 3) Preserve prior CHANCE during mid-cycle replans (unchanged from LIVE)
	if allow_hooks and prev_idx != -1:
		var prev_action := _get_action_by_idx(profile, prev_idx)
		if prev_action and prev_action.choice_type == NPCAction.ChoiceType.CHANCE:
			if _is_action_performable_sim(prev_action, ctx):
				return
	
	# 4) Roll chance
	var new_idx := _roll_chance_idx_sim(profile, ctx)
	if new_idx == -1:
		if prev_idx == -1:
			return
		if allow_hooks:
			_on_planned_intent_changed_sim(profile, prev_idx, -1, ctx)
		state[KEY_PLANNED_IDX] = -1
		return

	if prev_idx == new_idx:
		return

	if allow_hooks:
		_on_planned_intent_changed_sim(profile, prev_idx, new_idx, ctx)
	print("planning smth indx: ", new_idx)
	state[KEY_PLANNED_IDX] = new_idx

static func _can_cancel_intent_sim(state: Dictionary) -> bool:
	if bool(state.get(IS_ACTING, false)):
		return false
	return true

static func _get_action_by_idx(profile: NPCAIProfile, idx: int) -> NPCAction:
	if profile == null or idx < 0 or idx >= profile.actions.size():
		return null
	return profile.actions[idx]

static func _get_first_conditional_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action and action.choice_type == NPCAction.ChoiceType.CONDITIONAL and _is_action_performable_sim(action, ctx):
			return i
	return -1

static func _roll_chance_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	var total := 0.0
	var pool: Array[int] = []

	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action and action.choice_type == NPCAction.ChoiceType.CHANCE and _is_action_performable_sim(action, ctx):
			var w := _get_action_chance_weight_sim(action, ctx)
			if w > 0.0:
				total += w
				pool.append(i)

	if pool.is_empty() or total <= 0.0:
		return -1

	if ctx.rng == null:
		push_warning("SIM AI: ctx.rng missing (cid=%d)" % int(ctx.cid))
		return pool[0]

	var roll := ctx.rng.randf() * total
	_dbg("SIM AI RNG: cid=%d roll=%f total=%f rolls=%d" % [int(ctx.cid), roll, total, int(ctx.rng.rolls)])

	var acc := 0.0
	for i in pool:
		acc += _get_action_chance_weight_sim(profile.actions[i], ctx)
		if roll <= acc:
			return i

	return pool[-1]

static func _get_action_chance_weight_sim(action: NPCAction, ctx: NPCAIContext) -> float:
	var weight := float(action.chance_weight)
	var state := ctx.state if ctx and ctx.state else {}

	if bool(state.get(Keys.CHANCE_DISABLED, false)):
		return 0.0
	weight += float(state.get(Keys.CHANCE_ADD, 0.0))
	weight *= float(state.get(Keys.CHANCE_MULT, 1.0))
	return maxf(weight, 0.0)

static func _is_action_performable_sim(action: NPCAction, ctx: NPCAIContext) -> bool:
	for m in action.performable_models:
		if m and !m.is_performable_sim(ctx):
			return false
	return true

static func _on_planned_intent_changed_sim(profile: NPCAIProfile, prev_idx: int, _new_idx: int, ctx: NPCAIContext) -> void:
	var prev_action := _get_action_by_idx(profile, prev_idx)
	if prev_action:
		for m in prev_action.intent_lifecycle_models:
			if m:
				m.on_intent_canceled_sim(ctx)

static func _dbg(msg: String) -> void:
	if debug:
		print(msg)
