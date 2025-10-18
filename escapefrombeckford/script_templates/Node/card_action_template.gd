# meta-name: CardAction
# meta-description: Create an card action 
extends CardAction

#const PINPOINT_STATUS = preload("res://statuses/pinpoint.tres")
#var pinpoint_duration := 1

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	var damage_effect := DamageEffect.new()
	damage_effect.n_damage = 6
	damage_effect.sound = card_data.sound
	damage_effect.execute(correct_targets)
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)
