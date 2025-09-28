extends CardAction

func activate(targets: Array[Node]) -> bool:
	var attack_damage: int = 0
	var attack_count: int = 0
	var attack_targets: Array[Fighter] = []
	var action_processed: bool = false
	
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is Enemy:
				attack_targets.push_back(target.combatant)
	
	if player.can_play_card(card_data) && attack_targets:
		player.spend_mana(card_data)
		attack_damage = 6
		attack_count = 1
		
		var damage_effect := DamageEffect.new()
		damage_effect.n_damage = attack_damage
		damage_effect.sound = card_data.sound
		damage_effect.execute(attack_targets)

		action_processed = true
	return action_processed
