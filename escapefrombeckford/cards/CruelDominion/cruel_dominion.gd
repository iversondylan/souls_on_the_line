extends CardAction

const CRUEL_DOMINION_STATUS = preload("res://statuses/cruel_dominion.tres")
var cruel_dominion_intensity := 2

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
	#status_effect.battle_scene = battle_scene
	status_effect.execute(correct_targets)
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)

func get_description(description: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description % str(cruel_dominion_intensity)

func get_unmod_description(description: String) -> String:
	print(description)
	return get_description(description)
