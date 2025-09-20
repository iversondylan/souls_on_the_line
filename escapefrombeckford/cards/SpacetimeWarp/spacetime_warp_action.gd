extends CardAction


func activate(targets: Array[Node], player: Player) -> bool:
	var warp_targets: Array[SummonedAlly] = []
	
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is SummonedAlly:
				warp_targets.push_back(target.combatant)
	
	if !player.can_play_card(card_data) or !warp_targets:
		return false
	
	player.spend_mana(card_data)

	#SHOULD PROBABLY MAKE MOVE EFFECT TO PROCESS DIFFERENT KINDS OF MOVES AND PLAY SOUND
	for target in warp_targets:
		target.traverse_player()

	SFXPlayer.play(card_data.sound)
	
	return true
