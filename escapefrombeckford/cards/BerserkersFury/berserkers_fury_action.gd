extends CardAction


func activate(targets: Array[Node]) -> bool:
	var sacrifice_target: SummonedAlly = null
	var attack_damage: int = 0
	var attack_count: int = 0
	var attack_targets: Array[Fighter] = []
	var action_processed: bool = false

	
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is SummonedAlly:
				sacrifice_target = target.combatant
	
	
	if !player.can_play_card(card_data) or !sacrifice_target:
		return action_processed
	
	player.spend_mana(card_data)
	attack_targets = battle_scene.get_combatants_in_group(1)
	attack_damage = sacrifice_target.combatant_data.max_mana_red + 2
	attack_count = 1
	
	var attack_effect := AttackEffect.new()
	attack_effect.targets = attack_targets
	attack_effect.n_damage = attack_damage
	attack_effect.n_attacks = attack_count
	attack_effect.explode = true
	attack_effect.sound = card_data.sound
	attack_effect.execute([sacrifice_target])
	action_processed = true
	return action_processed
