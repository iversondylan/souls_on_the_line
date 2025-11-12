extends CardAction


func activate(targets: Array[Node]) -> bool:
	var attack_damage: int = 0
	var attack_count: int = 0
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	
	var attack_targets: Array[Fighter] = battle_scene.get_combatants_in_group(1)
	
	attack_damage = player.combatant_data.max_mana_red + 2
	attack_count = 1
	
	var attack_effect := BasicMeleeAttackEffect.new()
	#attack_effect.targets = attack_targets
	attack_effect.attacker = correct_targets[0]
	attack_effect.n_damage = attack_damage
	attack_effect.n_attacks = attack_count
	attack_effect.explode = true
	attack_effect.sound = card_data.sound
	attack_effect.execute(attack_targets)
	return true

func get_description(description: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description % str(player.combatant_data.max_mana_red + 2)
