class_name SuperCharge extends CardAction

const AMPLIFY_STATUS = preload("res://statuses/amplify.tres")
var amplify_duration := 2

func activate(targets: Array[Node]) -> bool:
	
	if !targets:
		return false
	
	var attacker := get_fighters(targets)[0]
	
	player.spend_mana(card_data)
	
	
	var status_effect := StatusEffect.new()
	var amplify_status := AMPLIFY_STATUS.duplicate()
	amplify_status.duration = amplify_duration
	status_effect.status = amplify_status
	status_effect.execute([attacker])
	
	var attack_effect := AttackEffect.new()
	attack_effect.targets = [battle_scene.get_front_or_focus(1)]
	attack_effect.n_damage = player.combatant_data.max_mana_red
	attack_effect.n_attacks = 1
	attack_effect.sound = card_data.sound
	attack_effect.execute([attacker])
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)
