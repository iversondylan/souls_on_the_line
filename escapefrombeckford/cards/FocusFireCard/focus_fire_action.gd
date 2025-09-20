extends CardAction


func activate(targets: Array[Node], player: Player) -> bool:
	var focus_target: Array[Fighter] = []
	var action_processed: bool = false
	
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is Enemy:
				focus_target.push_back(target.combatant)
	
	if !player.can_play_card(card_data) or !focus_target:
		return action_processed
	
	player.spend_mana(card_data)
	#attack_group = 1
	
	var focus_effect := FocusEffect.new()
	focus_effect.sound = card_data.sound
	focus_effect.execute(focus_target)
	action_processed = true
	return action_processed
