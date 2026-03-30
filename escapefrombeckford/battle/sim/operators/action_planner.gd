# action_planner.gd

class_name ActionPlanner extends RefCounted

const KEY_PLANNED_IDX := &"key_planned_index"
const HP_AT_TURN_START := &"hp_at_turn_start"
const DMG_SINCE_LAST_TURN := &"dmg_since_last_turn"
const STABILITY_BROKEN := &"stability_broken"
const ACTIONS_TAKEN := &"actions_taken"

static var debug := false



static func make_context(api: SimBattleAPI, u: CombatantState) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.runtime = api.runtime if api != null else null
	ctx.cid = int(u.id)
	ctx.combatant_state = u
	ctx.combatant_data = u.combatant_data
	ctx.rng = u.rng
	ctx.state = u.ai_state
	ctx.params = {}
	ctx.forecast = false
	return ctx


static func ensure_ai_state_initialized(u: CombatantState) -> void:
	if u.ai_state == null:
		u.ai_state = {}

	var s := u.ai_state
	s[Keys.PLANNING_NOW] = bool(s.get(Keys.PLANNING_NOW, false))

	if !s.has(HP_AT_TURN_START):
		s[HP_AT_TURN_START] = int(u.health)
	if !s.has(DMG_SINCE_LAST_TURN):
		s[DMG_SINCE_LAST_TURN] = 0
	if !s.has(KEY_PLANNED_IDX):
		s[KEY_PLANNED_IDX] = -1
	if !s.has(&"telegraph_committed"):
		s[&"telegraph_committed"] = false
	if !s.has(Keys.IS_ACTING):
		s[Keys.IS_ACTING] = false
	if !s.has(Keys.FIRST_INTENTS_READY):
		s[Keys.FIRST_INTENTS_READY] = false
	if !s.has(STABILITY_BROKEN):
		s[STABILITY_BROKEN] = false
	if !s.has(ACTIONS_TAKEN):
		s[ACTIONS_TAKEN] = 0
	if !(s.get(Keys.ACTION_STATE, null) is Dictionary):
		s[Keys.ACTION_STATE] = {}


static func ensure_valid_plan_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks := true) -> void:
	if profile == null or ctx == null:
		return
	if bool(ctx.state.get(Keys.IS_ACTING, false)):
		return

	if !ctx.state.has(KEY_PLANNED_IDX):
		plan_next_intent_sim(profile, ctx, allow_hooks)
		return

	var idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	var action := get_action_by_idx(profile, idx)
	if action == null or !_is_action_performable_sim(action, ctx):
		if allow_hooks:
			_on_planned_intent_changed_sim(profile, idx, -1, ctx)
		ctx.state[KEY_PLANNED_IDX] = -1
		plan_next_intent_sim(profile, ctx, allow_hooks)


static func plan_next_intent_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks := false) -> void:
	if profile == null or ctx == null:
		return

	var state := ctx.state if ctx.state else {}
	var prev_idx := int(state.get(KEY_PLANNED_IDX, -1))

	var cond_idx := _get_first_conditional_idx_sim(profile, ctx)
	if cond_idx != -1:
		if prev_idx == cond_idx:
			return
		if allow_hooks:
			_on_planned_intent_changed_sim(profile, prev_idx, cond_idx, ctx)
		state[KEY_PLANNED_IDX] = cond_idx
		return

	if prev_idx != -1 and !_can_cancel_intent_sim(state):
		return

	if allow_hooks and prev_idx != -1:
		var prev_action := get_action_by_idx(profile, prev_idx)
		if prev_action != null and prev_action.choice_type == NPCAction.ChoiceType.CHANCE:
			if _is_action_performable_sim(prev_action, ctx):
				return

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

	state[KEY_PLANNED_IDX] = new_idx


static func get_action_by_idx(profile: NPCAIProfile, idx: int) -> NPCAction:
	if profile == null or idx < 0 or idx >= profile.actions.size():
		return null
	return profile.actions[idx]


static func emit_current_intent(api: SimBattleAPI, cid: int) -> void:
	ActionIntentPresenter.emit_current_intent(api, cid)


static func _can_cancel_intent_sim(state: Dictionary) -> bool:
	if bool(state.get(Keys.IS_ACTING, false)):
		return false
	return true


static func _get_first_conditional_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action != null and action.choice_type == NPCAction.ChoiceType.CONDITIONAL and _is_action_performable_sim(action, ctx):
			return i
	return -1


static func _roll_chance_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	var total := 0.0
	var pool: Array[int] = []

	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action != null and action.choice_type == NPCAction.ChoiceType.CHANCE and _is_action_performable_sim(action, ctx):
			var w := _get_action_chance_weight_sim(action, i, ctx)
			if w > 0.0:
				total += w
				pool.append(i)

	if pool.is_empty() or total <= 0.0:
		push_warning("SIM AI: no valid chance action (cid=%d, total=%f, chance_actions=%d)" % [
			int(ctx.cid if ctx != null else -1),
			total,
			pool.size()
		])
		return -1

	if ctx.rng == null:
		push_warning("SIM AI: ctx.rng missing (cid=%d)" % int(ctx.cid))
		return pool[0]

	var roll := ctx.rng.randf() * total
	_dbg("SIM AI RNG: cid=%d roll=%f total=%f rolls=%d" % [
		int(ctx.cid), roll, total, int(ctx.rng.rolls)
	])

	var acc := 0.0
	for i in pool:
		acc += _get_action_chance_weight_sim(profile.actions[i], i, ctx)
		if roll <= acc:
			return i

	return pool[-1]


static func get_action_state_bucket_sim(state: Dictionary) -> Dictionary:
	if state == null:
		return {}

	var bucket = state.get(Keys.ACTION_STATE, null)
	if bucket is Dictionary:
		return bucket

	bucket = {}
	state[Keys.ACTION_STATE] = bucket
	return bucket


static func ensure_action_state_sim(state: Dictionary, action_idx: int) -> Dictionary:
	if state == null or action_idx < 0:
		return {}

	var bucket := get_action_state_bucket_sim(state)
	var action_state = bucket.get(action_idx, null)
	if action_state is Dictionary:
		return action_state

	action_state = {}
	bucket[action_idx] = action_state
	return action_state


static func _reset_action_chance_state_scratch(action_state: Dictionary) -> void:
	action_state[Keys.CHANCE_ADD] = 0.0
	action_state[Keys.CHANCE_MULT] = 1.0


static func _get_action_chance_weight_sim(action: NPCAction, action_idx: int, ctx: NPCAIContext) -> float:
	var weight := float(action.chance_weight)
	var state := ctx.state if ctx != null and ctx.state else {}
	var action_state := ensure_action_state_sim(state, action_idx)

	if bool(state.get(Keys.CHANCE_DISABLED, false)):
		return 0.0

	_reset_action_chance_state_scratch(action_state)

	var state_models := action.state_models if action.state_models != null else []
	for m: StateModel in state_models:
		if m != null:
			m.change_chance_weight_state_sim(ctx, action_state)

	weight += float(state.get(Keys.CHANCE_ADD, 0.0))
	weight += float(action_state.get(Keys.CHANCE_ADD, 0.0))
	weight *= float(state.get(Keys.CHANCE_MULT, 1.0))
	weight *= float(action_state.get(Keys.CHANCE_MULT, 1.0))
	return maxf(weight, 0.0)


static func _is_action_performable_sim(action: NPCAction, ctx: NPCAIContext) -> bool:
	for m in action.performable_models:
		if m != null and !m.is_performable_sim(ctx):
			return false
	return true


static func _on_planned_intent_changed_sim(profile: NPCAIProfile, prev_idx: int, _new_idx: int, ctx: NPCAIContext) -> void:
	var prev_action := get_action_by_idx(profile, prev_idx)
	if prev_action != null:
		for m in prev_action.intent_lifecycle_models:
			if m != null:
				m.on_intent_canceled(ctx)


static func _dbg(msg: String) -> void:
	if debug:
		print(msg)
