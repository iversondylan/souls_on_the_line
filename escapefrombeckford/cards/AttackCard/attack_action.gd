extends CardAction

var base_damage: int = 5
var attack_count: int = 1

func activate(targets: Array[Node]) -> bool:
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
		
	player.spend_mana(card_data)
	
	var damage_effect := DamageEffect.new()
	damage_effect.targets = correct_targets
	damage_effect.n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = card_data.sound
	damage_effect.execute()

	return true

func get_description(description: String, _target_fighter: Fighter = null) -> String:
	var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if _target_fighter:
		n_damage = _target_fighter.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_TAKEN)
	return description % str(n_damage)

func get_unmod_description(description: String) -> String:
	return description % str(base_damage)
