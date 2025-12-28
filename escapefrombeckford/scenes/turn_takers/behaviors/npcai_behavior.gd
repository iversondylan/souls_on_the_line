class_name NPCAIBehavior extends FighterBehavior

@export var ai_profile: NPCAIProfile

func pick_action() -> NPCAction:
	print("npcai_behavior.gd pick_action()")
	var ctx := _make_context()

	# 1) conditional
	for action in ai_profile.actions:
		if action.choice_type == NPCAction.ChoiceType.CONDITIONAL \
		and action.is_performable(ctx):
			return action

	# 2) weighted chance
	var total := 0.0
	var pool := []

	for action in ai_profile.actions:
		if action.choice_type == NPCAction.ChoiceType.CHANCE \
		and action.is_performable(ctx):
			total += action.chance_weight
			pool.append(action)

	if pool.is_empty():
		return null

	var roll := ctx.rng.randf() * total
	var acc := 0.0
	for action in pool:
		acc += action.chance_weight
		if roll <= acc:
			return action

	return pool[-1]

func _make_context() -> NPCAIContext:
	var fighter: Fighter = get_parent()

	var ctx := NPCAIContext.new()
	ctx.combatant = fighter
	ctx.battle_scene = fighter.battle_scene

	# Persistent per-fighter AI state
	# Initialize once, keep forever (until battle reset)
	if not has_meta("ai_state"):
		set_meta("ai_state", {})
	ctx.state = get_meta("ai_state")

	# Deterministic RNG (optional but recommended)
	if not has_meta("ai_rng"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		set_meta("ai_rng", rng)
	ctx.rng = get_meta("ai_rng")

	return ctx

func _on_combatant_data_set(_data: CombatantData) -> void:
	print("npcai_behavior.gd _on_combatant_data_set()")
	
	assert(_data.ai, "CombatantData has no ai profile")
	ai_profile = _data.ai
	
	# Reset AI runtime state for this combatant
	if has_meta("ai_state"):
		set_meta("ai_state", {})
	
	# Refresh intent immediately (optional but recommended)
	update_action_intent()
	
	# Recompute intent when combatant stats change
	if not _data.combatant_data_changed.is_connected(update_action_intent):
		_data.combatant_data_changed.connect(update_action_intent)

func update_action_intent() -> void:
	## Cooper was here
	print("npcai_behavior.gd update_action_intent()")	
	var fighter: Fighter = get_parent()
	if !fighter.is_alive() or !ai_profile:
		print("update_action_intent() alive: %s, ai_profile: %s" % [fighter.is_alive(), ai_profile])
		print("update_action_intent() not alive or no ai_profile: clearing display")
		fighter.intent_container.clear_display()
		return
	
	var ctx := _make_context()
	var action := pick_action()
	if !action:
		print("update_action_intent() there's no action")
		fighter.intent_container.clear_display()
		return
	
	var intent := action.get_intent_data(ctx)
	fighter.intent_container.display_icons([intent])

func _on_exit() -> void:
	var fighter: Fighter = get_parent()
	fighter.intent_container.clear_display()

func _on_do_turn() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive():
		fighter.resolve_action()
		return

	if !ai_profile:
		fighter.resolve_action()
		return

	var ctx := _make_context()
	var action := pick_action()

	if !action:
		fighter.resolve_action()
		return

	action.perform(ctx)
	# actions are responsible for calling fighter.resolve_action() or you standardize it.

func _on_battle_reset() -> void:
	if has_meta("ai_state"):
		set_meta("ai_state", {})
