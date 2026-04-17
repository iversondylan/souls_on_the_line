# action_planner.gd

class_name ActionPlanner extends RefCounted

const KEY_PLANNED_IDX := &"key_planned_index"
const HP_AT_TURN_START := &"hp_at_turn_start"
const DMG_SINCE_LAST_TURN := &"dmg_since_last_turn"
const STABILITY_BROKEN := &"stability_broken"
const SELECTION_SOURCE_NONE := 0
const SELECTION_SOURCE_OVERRIDE := 1
const SELECTION_SOURCE_CHANCE := 2

static var debug := false

static func make_context(api: SimBattleAPI, u: CombatantState) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.runtime = api.runtime if api != null else null
	ctx.cid = int(u.id)
	ctx.combatant_state = u
	ctx.combatant_data = u.combatant_data
	ctx.rng = u.rng
	if ctx.rng == null and api != null and api.state != null:
		api.state.init_unit_rng_for(int(u.id))
		ctx.rng = u.rng
	ctx.state = u.ai_state
	ctx.params = {}
	ctx.summoned_ids = PackedInt32Array()
	ctx.affected_ids = PackedInt32Array()
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
	if !s.has(Keys.ACTIONS_PERFORMED_COUNT):
		s[Keys.ACTIONS_PERFORMED_COUNT] = 0
	if !s.has(Keys.PLANNED_SELECTION_SOURCE):
		s[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_NONE
	if !(s.get(Keys.ACTION_STATE, null) is Dictionary):
		s[Keys.ACTION_STATE] = {}
	if !s.has(Keys.TARGETING_DANGER_ZONE):
		s[Keys.TARGETING_DANGER_ZONE] = false


static func ensure_valid_plan_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks := true) -> void:
	if profile == null or ctx == null:
		return
	if bool(ctx.state.get(Keys.IS_ACTING, false)):
		return

	if !ctx.state.has(KEY_PLANNED_IDX):
		plan_next_intent_sim(profile, ctx, allow_hooks)
		return

	if !is_current_plan_valid_sim(profile, ctx):
		cancel_current_plan_sim(profile, ctx, allow_hooks)
		plan_next_intent_sim(profile, ctx, allow_hooks)


static func plan_next_intent_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks := false) -> void:
	if profile == null or ctx == null:
		return

	var state := ctx.state if ctx.state else {}
	var prev_idx := int(state.get(KEY_PLANNED_IDX, -1))
	var prev_source := int(state.get(Keys.PLANNED_SELECTION_SOURCE, SELECTION_SOURCE_NONE))

	var override_idx := _get_first_override_idx_sim(profile, ctx)
	if override_idx != -1:
		if prev_idx == override_idx and prev_source == SELECTION_SOURCE_OVERRIDE:
			return
		if allow_hooks:
			_transition_planned_intent_sim(profile, prev_idx, override_idx, ctx)
		else:
			state[KEY_PLANNED_IDX] = override_idx
			state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_OVERRIDE
		return

	if prev_idx != -1 and !_can_cancel_intent_sim(state):
		return

	if prev_idx != -1 and prev_source == SELECTION_SOURCE_CHANCE:
		var prev_action := get_action_by_idx(profile, prev_idx)
		if prev_action != null:
			return

	var new_idx := _roll_chance_idx_sim(profile, ctx)
	if new_idx < 0:
		if profile == null or profile.actions.is_empty():
			if prev_idx == -1:
				return
			if allow_hooks:
				_transition_planned_intent_sim(profile, prev_idx, -1, ctx)
			else:
				state[KEY_PLANNED_IDX] = -1
				state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_NONE
			return
		new_idx = 0

	if prev_idx == new_idx and prev_source == SELECTION_SOURCE_CHANCE:
		return

	if allow_hooks:
		_transition_planned_intent_sim(profile, prev_idx, new_idx, ctx)
	else:
		state[KEY_PLANNED_IDX] = new_idx
		state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_CHANCE


static func get_action_by_idx(profile: NPCAIProfile, idx: int) -> NPCAction:
	if profile == null or idx < 0 or idx >= profile.actions.size():
		return null
	return profile.actions[idx]


static func emit_current_intent(api: SimBattleAPI, cid: int) -> void:
	ActionIntentPresenter.emit_current_intent(api, cid)


static func is_current_plan_valid_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> bool:
	if profile == null or ctx == null or ctx.state == null:
		return false

	var idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	var action := get_action_by_idx(profile, idx)
	var selection_source := int(ctx.state.get(Keys.PLANNED_SELECTION_SOURCE, SELECTION_SOURCE_NONE))

	match selection_source:
		SELECTION_SOURCE_OVERRIDE:
			return int(_get_first_override_idx_sim(profile, ctx)) == idx
		SELECTION_SOURCE_CHANCE:
			if action == null:
				return false
			return int(_get_first_override_idx_sim(profile, ctx)) == -1
		_:
			return false


static func cancel_current_plan_sim(profile: NPCAIProfile, ctx: NPCAIContext, allow_hooks := true) -> bool:
	if ctx == null or ctx.state == null:
		return false

	var prev_idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	if prev_idx < 0:
		return false

	if allow_hooks:
		_transition_planned_intent_sim(profile, prev_idx, -1, ctx)
	else:
		ctx.state[KEY_PLANNED_IDX] = -1
		ctx.state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_NONE
	return true


static func _can_cancel_intent_sim(state: Dictionary) -> bool:
	if bool(state.get(Keys.IS_ACTING, false)):
		return false
	return true


static func _get_first_override_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action == null:
			continue
		if _is_action_override_hit_sim(action, ctx):
			return i
	return -1


static func _roll_chance_idx_sim(profile: NPCAIProfile, ctx: NPCAIContext) -> int:
	var total := 0.0
	var pool: Array[int] = []
	var weights_by_idx := {}

	for i in range(profile.actions.size()):
		var action := profile.actions[i]
		if action != null:
			var w := _get_action_chance_weight_sim(action, i, ctx)
			weights_by_idx[i] = w
			if w > 0.0:
				total += w
				pool.append(i)

	if total <= 0.0:
		return -1

	if ctx.rng == null:
		push_warning("SIM AI: ctx.rng missing (cid=%d)" % int(ctx.cid))
		return pool[0] if !pool.is_empty() else -1

	#var should_debug := ctx != null and ctx.api != null and bool(ctx.api.is_main)
	#if should_debug:
		#print("action_planner.gd _roll_chance_idx_sim(): cid=%d pool=%s weights=%s total=%s" % [
			#int(ctx.cid),
			#str(pool),
			#str(weights_by_idx),
			#str(total),
		#])

	var roll := ctx.rng.randf() * total
	#if should_debug:
		#print("action_planner.gd _roll_chance_idx_sim(): cid=%d roll=%f total=%f rolls=%d" % [
			#int(ctx.cid),
			#roll,
			#total,
			#int(ctx.rng.rolls)
		#])

	var acc := 0.0
	for i in pool:
		var weight := float(weights_by_idx.get(i, 0.0))
		acc += weight
		#if should_debug:
			#print("action_planner.gd _roll_chance_idx_sim(): cid=%d checking_idx=%d weight=%f acc=%f roll=%f" % [
				#int(ctx.cid),
				#int(i),
				#weight,
				#acc,
				#roll,
			#])
		if roll <= acc:
			#if should_debug:
				#print("action_planner.gd _roll_chance_idx_sim(): cid=%d selected_idx=%d" % [
					#int(ctx.cid),
					#int(i),
				#])
			return i

	#if should_debug:
		#print("action_planner.gd _roll_chance_idx_sim(): cid=%d fallback_idx=%d" % [
			#int(ctx.cid),
			#int(pool[-1]),
		#])
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
	var final_weight := maxf(weight, 0.0)
	#if ctx != null and ctx.api != null and bool(ctx.api.is_main):
		#print("action_planner.gd _get_action_chance_weight_sim(): cid=%d action_idx=%d base=%s state_add=%s action_add=%s state_mult=%s action_mult=%s final=%s" % [
			#int(ctx.cid if ctx != null else -1),
			#int(action_idx),
			#str(action.chance_weight if action != null else 0.0),
			#str(state.get(Keys.CHANCE_ADD, 0.0)),
			#str(action_state.get(Keys.CHANCE_ADD, 0.0)),
			#str(state.get(Keys.CHANCE_MULT, 1.0)),
			#str(action_state.get(Keys.CHANCE_MULT, 1.0)),
			#str(final_weight),
		#])
	return final_weight


static func _is_action_override_hit_sim(action: NPCAction, ctx: NPCAIContext) -> bool:
	if action == null or action.performable_models == null or action.performable_models.is_empty():
		return false
	var has_performable := false
	for m in action.performable_models:
		if m == null:
			continue
		has_performable = true
		if !m.is_performable_sim(ctx):
			return false
	return has_performable


static func _on_planned_intent_changed_sim(profile: NPCAIProfile, prev_idx: int, _new_idx: int, ctx: NPCAIContext) -> void:
	var prev_action := get_action_by_idx(profile, prev_idx)
	if prev_action != null:
		ctx.action_name = prev_action.resolve_display_name()
		for m in prev_action.intent_lifecycle_models:
			if m != null:
				m.on_plan_canceled(ctx)
	ctx.action_name = ""

static func _transition_planned_intent_sim(profile: NPCAIProfile, prev_idx: int, new_idx: int, ctx: NPCAIContext) -> void:
	if ctx == null or ctx.state == null:
		return

	if prev_idx == new_idx:
		ctx.state[KEY_PLANNED_IDX] = new_idx
		ctx.state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_NONE if new_idx < 0 else int(
			ctx.state.get(Keys.PLANNED_SELECTION_SOURCE, SELECTION_SOURCE_NONE)
		)
		return

	_on_planned_intent_changed_sim(profile, prev_idx, new_idx, ctx)
	ctx.state[KEY_PLANNED_IDX] = new_idx
	if new_idx < 0:
		ctx.state[Keys.PLANNED_SELECTION_SOURCE] = SELECTION_SOURCE_NONE
	else:
		var override_idx := _get_first_override_idx_sim(profile, ctx)
		ctx.state[Keys.PLANNED_SELECTION_SOURCE] = (
			SELECTION_SOURCE_OVERRIDE if new_idx == override_idx else SELECTION_SOURCE_CHANCE
		)

	var new_action := get_action_by_idx(profile, new_idx)
	if new_action == null:
		return

	ctx.action_name = new_action.resolve_display_name()
	for m in new_action.intent_lifecycle_models:
		if m != null:
			m.on_plan_chosen(ctx)
	ctx.action_name = ""


static func _dbg(msg: String) -> void:
	if debug:
		print(msg)
