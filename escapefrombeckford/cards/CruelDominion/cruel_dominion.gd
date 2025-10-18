extends CardAction

const CRUEL_DOMINION_STATUS = preload("res://cards/CruelDominion/cruel_dominion.tres")
var cruel_dominion_intensity := 1

func activate(targets: Array[Node]) -> bool:
	
	var player_fighter: Fighter
	if targets[0].fighter is Player:
		player_fighter = targets[0]
	
	if !player_fighter:
		return false
	
	player.spend_mana(card_data)
	
	var status_effect := StatusEffect.new()
	var cruel_dominion := CRUEL_DOMINION_STATUS.duplicate()
	cruel_dominion.intensity = cruel_dominion_intensity
	status_effect.status = cruel_dominion
	status_effect.execute([player_fighter])
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)
