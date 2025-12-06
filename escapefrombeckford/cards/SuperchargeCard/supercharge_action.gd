class_name SuperCharge extends CardAction

const AMPLIFY_STATUS = preload("res://statuses/amplify.tres")
var amplify_duration := 2

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	
	var status_effect := StatusEffect.new()
	status_effect.targets = correct_targets
	var amplify_status := AMPLIFY_STATUS.duplicate()
	amplify_status.duration = amplify_duration
	status_effect.status = amplify_status
	status_effect.execute()
	
	var attack_effect := BasicMeleeAttackEffect.new()
	#attack_effect.targets = [battle_scene.get_front_or_focus(1)]
	#attack_effect.targets = [battle_scene.get_front_or_focus(1)]
	attack_effect.attacker = correct_targets[0]
	attack_effect.n_damage = correct_targets[0].combatant_data.max_mana_red
	attack_effect.n_attacks = 1
	attack_effect.battle_scene = battle_scene
	attack_effect.sound = card_data.sound
	attack_effect.execute()
	
	return true

## Overwrite this function for special playable conditions like space for allies
#func is_playable() -> bool:
	#return player.can_play_card(card_data)

func get_description(description: String, _target_fighter: Fighter = null) -> String:
	var modified_duration := amplify_duration#player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description % [str(floori(AmplifyStatus.MODIFIER*100)), str(modified_duration)]

func get_unmod_description(description: String) -> String:
	return description % [str(floori(AmplifyStatus.MODIFIER*100)), str(amplify_duration)]
