extends NPCAction

var spree: int = 0


func perform_action() -> void:
	if !combatant:
		return
	###updating target to front combatant###
	#if combatant.battle_group is BattleGroupEnemy:
		#target = battle_scene.get_front_or_focus(0)
	#else:
		#target = battle_scene.get_front_or_focus(1)
	if target:
		var buff_effect := BuffEffect.new()
		buff_effect.targets = [combatant]
		buff_effect.sound = sound
		buff_effect.execute()
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			action_performed.emit(self)
			combatant.turn_complete()
	)
	
	


func is_performable() -> bool:
	if spree <= 1:
		return true
	else:
		return false
#
func update_action_intent() -> void:
	intent_data.base_text = ""

func other_action_performed(npc_action: NPCAction) -> void:
	spree = 0

func get_tooltip() -> String:
	var base_string := "[center]This character will empower itself.[/center]"
	#var modified_dmg := combatant.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	return base_string
