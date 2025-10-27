extends CardAction

var base_damage: int = 5
var attack_count: int = 1

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
		
	player.spend_mana(card_data)
	
	var damage_effect := DamageEffect.new()
	damage_effect.n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = card_data.sound
	damage_effect.execute(correct_targets)

	return true
