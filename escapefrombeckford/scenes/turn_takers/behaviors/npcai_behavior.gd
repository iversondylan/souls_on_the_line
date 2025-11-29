class_name NPCAIBehavior extends FighterBehavior

var npc_action_picker: NPCActionPicker
var current_action: NPCAction: set = _set_current_action

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
	if !fighter.combatant_data.is_alive:
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
	if !current_action:
		print("npc_fighter.gd do_turn() ERROR: npc_figher has no action to do")
		return
	current_action.perform_action()
	current_action = null
	fighter.intent_container.clear_display()

func _on_battle_reset() -> void:
	var fighter: Fighter = get_parent()
	fighter.combatant_data.reset_armor()
	fighter.combatant_data.reset_mana()
	fighter.combatant_data.reset_health()
