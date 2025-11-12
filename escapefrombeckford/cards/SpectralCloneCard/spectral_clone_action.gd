extends CardAction

func activate(targets: Array[Node]) -> bool:
	
	#var correct_targets: Array[Fighter] = correct_fighters(targets)
	
	player.spend_mana(card_data)
	
	var combatant_scn: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
	var clone: SummonedAlly = combatant_scn.instantiate()
	battle_scene.add_combatant(clone, 0, targets.size()-1)
	clone.combatant_data = load("res://fighters/BasicClone/basic_clone_data.tres").duplicate()
	
	for child in clone.get_children():
		if child.has_method("bind_card"):
			child.bind_card(card_data)
	#clone.spawned()
	SFXPlayer.play(card_data.sound)
	
	return true

func is_playable() -> bool:
	return player.can_play_card(card_data) and battle_scene.get_n_summoned_allies() < player.combatant_data.max_mana_blue

func get_description(description: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description# % n_damage
