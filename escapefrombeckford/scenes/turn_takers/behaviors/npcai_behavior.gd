class_name NPCAIBehavior extends FighterBehavior

const KEY_PLANNED_CHANCE_IDX := "planned_chance_idx"
const KEY_PLANNED_IDX := "planned_idx"

@export var ai_profile: NPCAIProfile

func _make_context() -> NPCAIContext:
	var fighter: Fighter = get_parent()
	
	var ctx := NPCAIContext.new()
	ctx.combatant = fighter
	ctx.battle_scene = fighter.battle_scene
	ctx.state = get_meta("ai_state")
	ctx.rng = get_meta("ai_rng")
	return ctx

func _on_combatant_data_set(_data: CombatantData) -> void:
	assert(_data.ai, "CombatantData has no ai profile")
	ai_profile = _data.ai

	# init state + rng ONCE
	set_meta("ai_state", {})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_meta("ai_rng", rng)

	# IMPORTANT: do NOT plan here (battle_scene / turn order may not be ready yet)
	# Instead: Battle.start_battle() should plan initial intents after enemies exist.

	if not _data.combatant_data_changed.is_connected(_on_stats_changed):
		_data.combatant_data_changed.connect(_on_stats_changed)

func _on_stats_changed() -> void:
	# Hard conditional takeover ONLY in response to player/allies causing stat changes
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		return

	var ctx := _make_context()

	# if a conditional is now valid, overwrite the plan and refresh the display
	var cond_idx := _get_first_conditional_idx(ctx)
	if cond_idx != -1:
		ctx.state[KEY_PLANNED_IDX] = cond_idx
	_refresh_intent_display_only()

	## Cooper was here
func update_action_intent() -> void:
	_refresh_intent_display_only()

func _get_action_by_idx(idx: int) -> NPCAction:
	if !ai_profile or idx < 0 or idx >= ai_profile.actions.size():
		return null
	return ai_profile.actions[idx]

func _get_first_conditional_idx(ctx: NPCAIContext) -> int:
	for i in range(ai_profile.actions.size()):
		var a := ai_profile.actions[i]
		if a.choice_type == NPCAction.ChoiceType.CONDITIONAL and a.is_performable(ctx):
			return i
	return -1

func _roll_chance_idx(ctx: NPCAIContext) -> int:
	var total := 0.0
	var pool: Array[int] = []
	
	for i in range(ai_profile.actions.size()):
		var a := ai_profile.actions[i]
		if a.choice_type == NPCAction.ChoiceType.CHANCE and a.is_performable(ctx):
			total += a.get_chance_weight()
			pool.append(i)
	
	if pool.is_empty():
		return -1
	
	var roll := ctx.rng.randf() * total
	if total <= 0.0:
		return -1
	var acc := 0.0
	for i in pool:
		acc += ai_profile.actions[i].get_chance_weight()
		if roll <= acc:
			return i
	
	return pool[-1]

func plan_next_intent() -> void:
	# ONLY RNG HERE.
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		return
	
	var ctx := _make_context()
	
	# Roll a chance plan for next turn (do NOT check conditionals here)
	var chance_idx := _roll_chance_idx(ctx)
	ctx.state[KEY_PLANNED_IDX] = chance_idx

func refresh_intent_display_only() -> void:
	_refresh_intent_display_only()

func _refresh_intent_display_only() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		fighter.intent_container.clear_display()
		return
	
	var ctx := _make_context()
	
	# Do NOT show intent while acting
	if ctx.state.get("is_acting", false):
		return
	
	if not ctx.state.has(KEY_PLANNED_IDX):
	# No plan yet — do NOT clear.
	# This happens transiently on first turn due to modifier churn.
		return
	
	var planned_idx := int(ctx.state[KEY_PLANNED_IDX])
	var action := _get_action_by_idx(planned_idx)
	
	if !action:
		fighter.intent_container.clear_display()
		return
	
	fighter.intent_container.display_icons([action.get_intent_data(ctx)])


func _get_action_for_execution(ctx: NPCAIContext) -> NPCAction:
	var idx: int = int(ctx.state.get(KEY_PLANNED_IDX, -1))
	return _get_action_by_idx(idx)

func _apply_conditional_takeover_if_needed(ctx: NPCAIContext) -> bool:
	# returns true if it changed the plan
	var cond_idx := _get_first_conditional_idx(ctx)
	if cond_idx == -1:
		return false
	
	var cur_idx: int = int(ctx.state.get(KEY_PLANNED_IDX, -1))
	if cur_idx == cond_idx:
		return false # already showing conditional
	
	ctx.state[KEY_PLANNED_IDX] = cond_idx
	ctx.state["locked_conditional"] = true
	return true

func _on_enter() -> void:
	# At start of THIS fighter's turn:
	# show what was already planned earlier
	_refresh_intent_display_only()


func _on_exit() -> void:
	var ctx := _make_context()
	
	# UNLOCK intent display
	ctx.state["is_acting"] = false
	
	# Plan + show next intent
	plan_next_intent()
	_refresh_intent_display_only()

func _on_do_turn() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		fighter.resolve_action()
		return

	var ctx := _make_context()

	# LOCK intent display while acting
	ctx.state["is_acting"] = true

	# Clear intent immediately (visual gap)
	#fighter.intent_container.clear_display()

	# Safety: if nothing planned, plan once
	if not ctx.state.has(KEY_PLANNED_IDX):
		plan_next_intent()

	var idx := int(ctx.state.get(KEY_PLANNED_IDX, -1))
	var action := _get_action_by_idx(idx)
	if !action:
		fighter.resolve_action()
		return

	action.perform(ctx) # must eventually call fighter.resolve_action()

func _on_battle_reset() -> void:
	if has_meta("ai_state"):
		set_meta("ai_state", {})
