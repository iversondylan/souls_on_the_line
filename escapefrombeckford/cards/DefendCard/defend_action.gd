extends CardAction

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	var block_effect = BlockEffect.new()
	block_effect.n_armor = 5
	block_effect.sound = card_data.sound
	block_effect.execute(correct_targets)
	
	return true
