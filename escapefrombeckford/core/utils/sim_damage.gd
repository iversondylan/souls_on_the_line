# sim_damage.gd

class_name SimDamage extends RefCounted

static func compute_damage(battle: SimBattle, attacker_id: int, defender_id: int, base: int) -> int:
	if !battle:
		return maxi(base, 0)
	
	var dealt : int = battle.get_modified_value(attacker_id, base, Modifier.Type.DMG_DEALT)
	# SimModifier.get_modified_value(battle, attacker_id, base, Modifier.Type.DMG_DEALT)
	# battle.get_modified_value(attacker_id, base, Modifier.Type.DMG_DEALT)
	var taken : int = battle.get_modified_value(defender_id, dealt, Modifier.Type.DMG_TAKEN)
	# SimModifier.get_modified_value(battle, defender_id, dealt, Modifier.Type.DMG_TAKEN) 
	# battle.get_modified_value(defender_id, dealt, Modifier.Type.DMG_TAKEN)
	return maxi(taken, 0)
