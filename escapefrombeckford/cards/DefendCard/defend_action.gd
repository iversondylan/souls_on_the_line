extends CardAction

var n_armor := 5

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	var block_effect = BlockEffect.new()
	block_effect.n_armor = n_armor
	block_effect.sound = card_data.sound
	block_effect.execute(correct_targets)
	
	return true

func get_description(description: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description % n_armor

func get_unmod_description(description: String) -> String:
	print(description)
	return get_description(description)
