# npcai_behavior.gd
class_name NPCAIBehavior extends FighterBehavior

#const KEY_PLANNED_CHANCE_IDX := "planned_chance_idx"
const KEY_PLANNED_IDX := "planned_idx"

@export var ai_profile: NPCAIProfile

# ---- Action execution state (MOVED from NPCAction) ----
var current_action: NPCAction = null
var action_ctx: NPCAIContext = null
var remaining_effect_packages: Array[NPCEffectPackage] = []


# -------------------------------------------------------------------
# Context construction
# -------------------------------------------------------------------

func _make_context() -> NPCAIContext:
	var fighter: Fighter = get_parent()

	var ctx := NPCAIContext.new()
	ctx.combatant = fighter
	ctx.battle_scene = fighter.battle_scene
	ctx.state = get_meta("ai_state")
	ctx.rng = get_meta("ai_rng")
	ctx.params = {}
	ctx.forecast = false
	return ctx


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func _on_combatant_data_set(_data: CombatantData) -> void:
	assert(_data.ai, "CombatantData has no ai profile")
	ai_profile = _data.ai

	# Init persistent AI state + RNG ONCE
	set_meta("ai_state", {})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_meta("ai_rng", rng)

	if not _data.combatant_data_changed.is_connected(_on_stats_changed):
		_data.combatant_data_changed.connect(_on_stats_changed)


# -------------------------------------------------------------------
# Planning logic (UNCHANGED)
# -------------------------------------------------------------------

func _on_stats_changed() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		return

	var ctx := _make_context()
	var cond_idx := _get_first_conditional_idx(ctx)
	if cond_idx != -1:
		ctx.state[KEY_PLANNED_IDX] = cond_idx

	_refresh_intent_display_only()


func update_action_intent() -> void:
	# Cooper was here
	_refresh_intent_display_only()


func _get_action_by_idx(idx: int) -> NPCAction:
	if !ai_profile or idx < 0 or idx >= ai_profile.actions.size():
		return null
	return ai_profile.actions[idx]


func _get_first_conditional_idx(ctx: NPCAIContext) -> int:
	for i in range(ai_profile.actions.size()):
		var action := ai_profile.actions[i]
		if action.choice_type == NPCAction.ChoiceType.CONDITIONAL and _is_action_performable(action, ctx):
			return i
	return -1


func _roll_chance_idx(ctx: NPCAIContext) -> int:
	var total := 0.0
	var pool: Array[int] = []

	for i in range(ai_profile.actions.size()):
		var action := ai_profile.actions[i]
		if action.choice_type == NPCAction.ChoiceType.CHANCE and _is_action_performable(action, ctx):
			var weight := _get_action_chance_weight(action, ctx)
			if weight > 0.0:
				total += weight
				pool.append(i)

	if pool.is_empty() or total <= 0.0:
		return -1

	var roll := ctx.rng.randf() * total
	var acc := 0.0
	for i in pool:
		acc += _get_action_chance_weight(ai_profile.actions[i], ctx)
		if roll <= acc:
			return i

	return pool[-1]

func plan_next_intent() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		return

	var ctx := _make_context()

	# 1) CONDITIONAL actions have priority
	for i in range(ai_profile.actions.size()):
		var action := ai_profile.actions[i]
		if action.choice_type == NPCAction.ChoiceType.CONDITIONAL:
			if _is_action_performable(action, ctx):
				ctx.state[KEY_PLANNED_IDX] = i
				return

	# 2) Otherwise, roll among CHANCE actions
	var chance_idx := _roll_chance_idx(ctx)
	ctx.state[KEY_PLANNED_IDX] = chance_idx


# -------------------------------------------------------------------
# Intent display
# -------------------------------------------------------------------

func _refresh_intent_display_only() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		fighter.intent_container.clear_display()
		return
	var ctx := _make_context()
	# Do not show intent while acting
	if ctx.state.get("is_acting", false):
		return
	if not ctx.state.has(KEY_PLANNED_IDX):
		return
	var action := _get_action_by_idx(int(ctx.state[KEY_PLANNED_IDX]))
	if !action:
		fighter.intent_container.clear_display()
		return
	var intent := _build_intent_from_action(action, ctx)
	fighter.intent_container.display_icons([intent])

func refresh_intent_display_only() -> void:
	_refresh_intent_display_only()


func _build_intent_from_action(action: NPCAction, ctx: NPCAIContext) -> IntentData:
	var intent := IntentData.new()
	ctx.params.clear()
	_change_params_only(action, ctx)
	# Base authored data
	intent.icon = action.intent_icon
	if action.intent_text_model:
		intent.base_text = action.intent_text_model.get_text(ctx)
	else:
		intent.base_text = ""
	if action.tooltip_model:
		intent.tooltip = action.tooltip_model.get_text(ctx)
	else:
		intent.tooltip = ""
	#ctx.params.clear()
	return intent

func _change_params_only(action: NPCAction, ctx: NPCAIContext) -> void:
	for pkg in action.effect_packages:
		for model in pkg.param_models:
			model.change_params(ctx)

# -------------------------------------------------------------------
# Turn lifecycle
# -------------------------------------------------------------------

func _on_enter() -> void:
	_refresh_intent_display_only()


func _on_exit() -> void:
	print("_on_exit()")
	var ctx := _make_context()
	ctx.state["is_acting"] = false
	plan_next_intent()
	_refresh_intent_display_only()

# -------------------------------------------------------------------
# ACTION UTILITIES
# -------------------------------------------------------------------

func _is_action_performable(action: NPCAction, ctx: NPCAIContext) -> bool:
	for model in action.performable_models:
		if not model.is_performable(ctx):
			return false
	return true

func _get_action_chance_weight(action: NPCAction, ctx: NPCAIContext) -> float:
	var weight := action.chance_weight
	var state := ctx.state if ctx and ctx.state else {}

	if state.get(NPCKeys.CHANCE_DISABLED, false):
		return 0.0

	weight += float(state.get(NPCKeys.CHANCE_ADD, 0.0))
	weight *= float(state.get(NPCKeys.CHANCE_MULT, 1.0))

	return maxf(weight, 0.0)


# -------------------------------------------------------------------
# ACTION EXECUTION (MOVED FROM NPCAction)
# -------------------------------------------------------------------

func _on_do_turn() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		fighter.resolve_action()
		return

	var ctx := _make_context()
	ctx.state["is_acting"] = true

	if not ctx.state.has(KEY_PLANNED_IDX):
		print("_on_do_turn() there's no KEY_PLANNED_IDX")
		plan_next_intent()

	var action := _get_action_by_idx(int(ctx.state.get(KEY_PLANNED_IDX, -1)))
	if not action:
		fighter.resolve_action()
		return

	_start_action(action, ctx)


func _start_action(action: NPCAction, ctx: NPCAIContext) -> void:
	current_action = action
	action_ctx = ctx
	remaining_effect_packages = action.effect_packages.duplicate()

	# Action-level state models (once)
	for m in action.state_models:
		if m:
			m.change_state(ctx)

	_next_effect_package()


func _next_effect_package() -> void:
	if remaining_effect_packages.is_empty():
		_finish_action()
		return

	var pkg : NPCEffectPackage = remaining_effect_packages.pop_front()

	# Clear per-effect params
	action_ctx.params.clear()

	# Package-level state models
	for m in pkg.state_models:
		if m:
			m.change_state(action_ctx)

	# Package-level param models
	for m in pkg.param_models:
		if m:
			m.change_params(action_ctx)

	_execute_effect_sequence(pkg)


func _execute_effect_sequence(pkg: NPCEffectPackage) -> void:
	if pkg.effect:
		pkg.effect.execute(
			action_ctx,
			Callable(self, "_on_sequence_done")
		)
	else:
		_on_sequence_done()


func _on_sequence_done() -> void:
	_next_effect_package()


func _finish_action() -> void:
	var fighter := action_ctx.combatant
	current_action = null
	action_ctx = null
	remaining_effect_packages.clear()

	if fighter:
		fighter.resolve_action()


# -------------------------------------------------------------------
# Reset
# -------------------------------------------------------------------

func _on_battle_reset() -> void:
	if has_meta("ai_state"):
		set_meta("ai_state", {})
