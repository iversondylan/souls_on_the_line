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
