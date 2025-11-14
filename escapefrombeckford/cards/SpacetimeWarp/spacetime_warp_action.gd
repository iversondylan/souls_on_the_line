extends CardAction


func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)

	#SHOULD PROBABLY MAKE MOVE EFFECT TO PROCESS DIFFERENT KINDS OF MOVES AND PLAY SOUND
	correct_targets[0].traverse_player()
	SFXPlayer.play(card_data.sound)
	
	return true

func get_description(description: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description# % n_damage

func get_unmod_description(description: String) -> String:
	return get_description(description)
