# npcai_behavior.gd
class_name NPCAIBehavior extends FighterBehavior

#const KEY_PLANNED_CHANCE_IDX := "planned_chance_idx"
const KEY_PLANNED_IDX := "planned_idx"
const HP_AT_TURN_START := "hp_at_turn_start"
const DMG_SINCE_LAST_TURN := "dmg_since_last_turn"
const STABILITY_BROKEN := "stability_broken"
const IS_ACTING := "is_acting"

const BASE_WINDUP_DELAY := 1.6
const BASE_IMPACT_DELAY := 1.0
var speed_setting : float = 2.0


@export var ai_profile: NPCAIProfile

# ---- Action execution state ----
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
	ai_profile = _data.ai
	
	# Init persistent AI state + RNG ONCE
	set_meta("ai_state", {})
	var state = get_meta("ai_state")
	state[HP_AT_TURN_START] = _data.health
	state[DMG_SINCE_LAST_TURN] = 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_meta("ai_rng", rng)
	
	if not _data.combatant_data_changed.is_connected(_on_stats_changed):
		_data.combatant_data_changed.connect(_on_stats_changed)
	var grid : StatusGrid = get_parent().combatant.status_grid
	if grid and not grid.intent_conditions_changed.is_connected(_on_intent_conditions_changed):
		grid.intent_conditions_changed.connect(_on_intent_conditions_changed)


# -------------------------------------------------------------------
# Planning logic (UNCHANGED)
# -------------------------------------------------------------------

func _on_stats_changed() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		return
	
	var state : Dictionary = get_meta("ai_state")
	if state and state.has(HP_AT_TURN_START):
		var cur_hp := fighter.combatant_data.health
		var delta : int = state[HP_AT_TURN_START] - cur_hp
		if delta > 0:
			state[DMG_SINCE_LAST_TURN] = delta
	
	plan_next_intent(true)
	_refresh_intent_display_only()

func _on_intent_conditions_changed() -> void:
	# Mid-cycle replanning allowed
	plan_next_intent(true)
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

func plan_next_intent(allow_hooks: bool = false) -> void:
	var fighter: Fighter = get_parent()
	if !fighter or !fighter.is_alive() or !ai_profile:
		return
	
	var ctx := _make_context()
	var state := ctx.state if ctx and ctx.state else {}
	
	var prev_idx: int = int(state.get(KEY_PLANNED_IDX, -1))
	
	# ------------------------------------------------------------
	# 0) Hard lock: if we already have a plan and we are not allowed
	# to change it right now, bail early (prevents mid-cycle rerolls).
	# ------------------------------------------------------------
	if prev_idx != -1 and !_can_cancel_intent(state):
		return
	
	# ------------------------------------------------------------
	# 1) If a CONDITIONAL action is performable, it always wins.
	# (This is your intended pipeline for sequences / overrides.)
	# ------------------------------------------------------------
	var cond_idx := _get_first_conditional_idx(ctx)
	if cond_idx != -1:
		# If nothing changes, do nothing.
		if prev_idx == cond_idx:
			return
	
		# Interrupt-only cleanup hooks
		if allow_hooks:
			_on_planned_intent_changed(prev_idx, cond_idx, ctx)
	
		state[KEY_PLANNED_IDX] = cond_idx
		return
	
	# ------------------------------------------------------------
	# 2) No conditional available.
	# If previous planned CHANCE action is still performable,
	# keep it (prevents reroll spam from death / minor state changes).
	# ------------------------------------------------------------
	if prev_idx != -1:
		var prev_action := _get_action_by_idx(prev_idx)
		if prev_action and prev_action.choice_type == NPCAction.ChoiceType.CHANCE:
			if _is_action_performable(prev_action, ctx):
				return
	
	# ------------------------------------------------------------
	# 3) Otherwise roll a new CHANCE action.
	# ------------------------------------------------------------
	var new_idx := _roll_chance_idx(ctx)
	
	# If no chance actions are available, clear planned index.
	# (Optional, but makes the state explicit.)
	if new_idx == -1:
		if prev_idx == -1:
			return
		if allow_hooks:
			_on_planned_intent_changed(prev_idx, -1, ctx)
		state[KEY_PLANNED_IDX] = -1
		return
	
	# If unchanged, do nothing.
	if prev_idx == new_idx:
		return
	
	# Interrupt-only cleanup hooks
	if allow_hooks:
		_on_planned_intent_changed(prev_idx, new_idx, ctx)
	
	# Commit
	state[KEY_PLANNED_IDX] = new_idx


func _on_planned_intent_changed(prev_idx: int, _new_idx: int, ctx: NPCAIContext) -> void:
	var prev_action := _get_action_by_idx(prev_idx)
	if prev_action:
		for model in prev_action.intent_lifecycle_models:
			model.on_intent_canceled(ctx)

func _can_cancel_intent(state: Dictionary) -> bool:
	if state.get(IS_ACTING, false):
		return false
	if state.get("telegraph_committed", false):
		return false
	return true

func _on_opposing_group_turn_start() -> void:
	var ctx := _make_context()
	var state : Dictionary = ctx.state
	
	# Defensive: no planning data
	if !state.has(KEY_PLANNED_IDX):
		return
	
	# Prevent double-commit in the same cycle
	if state.get("telegraph_committed", false):
		return
	
	var idx : int = int(state.get(KEY_PLANNED_IDX, -1))
	if idx < 0:
		return
	
	var action := _get_action_by_idx(idx)
	if !action:
		return
	
	# Commit intent-time effects (telegraphs, posture, channeling, etc.)
	for model in action.intent_lifecycle_models:
		model.on_opposing_group_start(ctx)
	
	# Mark as committed so it won't reapply mid-cycle
	state["telegraph_committed"] = true

func _on_group_turn_end() -> void:
	var state : Dictionary = get_meta("ai_state")
	if state:
		state["telegraph_committed"] = false

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
	if ctx.state.get(IS_ACTING, false):
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
	# Override icon if attack mode is ranged
	if ctx.params.has(NPCKeys.ATTACK_MODE):
		if ctx.params[NPCKeys.ATTACK_MODE] == NPCAttackSequence.ATTACK_MODE_RANGED:
			if action.intent_icon_ranged:
				intent.icon = action.intent_icon_ranged
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
			if not model:
				push_warning(
					"Null ParamModel in %s (%s)"
					% [pkg.resource_name, action.resource_name]
				)
				continue
			model.change_params(ctx)

# -------------------------------------------------------------------
# Turn lifecycle
# -------------------------------------------------------------------

func _on_enter() -> void:
	var fighter: Fighter = get_parent()
	var state : Dictionary = get_meta("ai_state")
	state[HP_AT_TURN_START] = fighter.combatant_data.health
	state[DMG_SINCE_LAST_TURN] = 0
	_refresh_intent_display_only()


func _on_exit() -> void:
	var ctx := _make_context()
	ctx.state[IS_ACTING] = false
	ctx.state[STABILITY_BROKEN] = false
	plan_next_intent(false)
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
# ACTION EXECUTION
# -------------------------------------------------------------------

func _on_do_turn() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		fighter.resolve_action()
		return
	
	var ctx := _make_context()
	ctx.state[IS_ACTING] = true
	
	if not ctx.state.has(KEY_PLANNED_IDX):
		print("_on_do_turn() there's no KEY_PLANNED_IDX")
		plan_next_intent()
	
	var action := _get_action_by_idx(int(ctx.state.get(KEY_PLANNED_IDX, -1)))
	if not action:
		fighter.resolve_action()
		return
	
	_start_windup_delay(action, ctx)


func _start_action(action: NPCAction, ctx: NPCAIContext) -> void:
	ctx.combatant.intent_container.clear_display()
	current_action = action
	
	for model: IntentLifecycleModel in current_action.intent_lifecycle_models:
		model.on_ability_started(ctx)
	
	action_ctx = ctx
	remaining_effect_packages = action.effect_packages.duplicate()
	
	# Action-level state models (once)
	for m in action.state_models:
		if m:
			m.change_state(ctx)
	
	_next_effect_package()


func _next_effect_package() -> void:
	if remaining_effect_packages.is_empty():
		_start_impact_delay()#_finish_action()
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

func _start_windup_delay(action: NPCAction, ctx: NPCAIContext) -> void:
	print("windup delay: ", ctx.combatant.name)
	get_tree().create_timer(BASE_WINDUP_DELAY/speed_setting, false).timeout.connect(_start_action.bind(action, ctx))

func _start_impact_delay() -> void:
	print("impact delay")
	get_tree().create_timer(BASE_IMPACT_DELAY/speed_setting, false).timeout.connect(_finish_action)
	

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
	pass
	#if has_meta("ai_state"):
		#set_meta("ai_state", {})
