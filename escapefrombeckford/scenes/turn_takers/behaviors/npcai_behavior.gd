class_name NPCAIBehavior extends FighterBehavior

var npc_action_picker: NPCActionPicker
var current_action: NPCAction: set = _set_current_action


@export var ai_profile: NPCAIProfile # or pull from combatant_data

var ai_state := {} # serialize this

func pick_action() -> NPCAction:
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


## 12/27/25 resume here
func _on_combatant_data_set(_data: CombatantData) -> void:
	load_ai()
	if not _data.combatant_data_changed.is_connected(update_action):
		_data.combatant_data_changed.connect(update_action)

func load_ai():
	var fighter: Fighter = get_parent()
	if npc_action_picker:
		npc_action_picker.queue_free()
	if fighter.combatant_data.ai:
		var new_action_picker: NPCActionPicker = fighter.combatant_data.ai.instantiate()
		fighter.add_child(new_action_picker)
		npc_action_picker = new_action_picker
		npc_action_picker.combatant = fighter
		npc_action_picker.battle_scene = fighter.battle_scene

func update_action() -> void:
	# Cooper was here
	var fighter: Fighter = get_parent()
	if !npc_action_picker:
		return
	if !current_action:
		current_action = npc_action_picker.get_action()
		current_action.battle_scene = fighter.battle_scene
		return
	var new_conditional_action := npc_action_picker.get_first_conditional_action()
	if new_conditional_action and current_action != new_conditional_action:
		current_action = new_conditional_action
		current_action.battle_scene = fighter.battle_scene

func update_action_intent() -> void:
	current_action.update_action_intent()
	var fighter: Fighter = get_parent()
	fighter.intent_container.display_icons([current_action.intent_data])

func _set_current_action(_current_action: NPCAction) -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_alive():
		return
	current_action = _current_action
	if current_action:
		var intent_dataz: Array[IntentData]
		#var intent_data: IntentData = current_action.intent_data.duplicate()
		#var icon_with_text: IconWithText = IconWithText.new(icon_texture, icon_string, icon_tooltip_text)
		current_action.update_action_intent()
		intent_dataz.push_back(current_action.intent_data)
		fighter.intent_container.display_icons(intent_dataz)

func _on_exit() -> void:
	update_action()

func _on_do_turn() -> void:
	var fighter: Fighter = get_parent()
	var a := pick_action()
	if !a:
		fighter.resolve_action()
		return

	var ctx := NPCAIContext.new()
	ctx.combatant = fighter
	ctx.battle_scene = fighter.battle_scene
	ctx.state = ai_state

	a.perform(ctx)
	# actions are responsible for calling fighter.resolve_action() or you standardize it.

#func _on_do_turn() -> void:
	#var fighter: Fighter = get_parent()
	#if !current_action:
		#print("npc_fighter.gd do_turn() ERROR: npc_figher has no action to do")
		#return
	#current_action.perform_action()
	#current_action = null
	#fighter.intent_container.clear_display()

func _on_battle_reset() -> void:
	var fighter: Fighter = get_parent()
	fighter.combatant_data.reset_armor()
	fighter.combatant_data.reset_mana()
	fighter.combatant_data.reset_health()
