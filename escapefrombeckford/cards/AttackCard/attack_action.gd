extends CardAction

func activate(targets: Array[Node]) -> bool:
	var attack_damage: int = 6
	var attack_count: int = 1
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
		
	player.spend_mana(card_data)
	
	var damage_effect := DamageEffect.new()
	damage_effect.n_damage = attack_damage
	damage_effect.sound = card_data.sound
	damage_effect.execute(correct_targets)

	return true
