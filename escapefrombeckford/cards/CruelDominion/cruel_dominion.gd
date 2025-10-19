extends CardAction

const CRUEL_DOMINION_STATUS = preload("res://statuses/cruel_dominion.tres")
var cruel_dominion_intensity := 1

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	var status_effect := StatusEffect.new()
	var cruel_dominion := CRUEL_DOMINION_STATUS.duplicate()
	cruel_dominion.intensity = cruel_dominion_intensity
	status_effect.sound = card_data.sound
	status_effect.status = cruel_dominion
	status_effect.execute(correct_targets)
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)
