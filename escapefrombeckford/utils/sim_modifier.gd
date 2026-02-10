# sim_modifier.gd

class_name SimModifier extends RefCounted

static func get_modified_value(battle: SimBattle, target_id: int, base: int, mod_type: Modifier.Type) -> int:
	if !battle:
		return base
	
	var resolved := ResolvedModifier.new()
	var tokens := battle.get_modifier_tokens_for_target(target_id, mod_type)
	
	for token: ModifierToken in tokens:
		if token.type != mod_type:
			continue
		resolved.flat += token.flat_value
		resolved.mult *= (1.0 + token.mult_value)
	
	return floori((base + resolved.flat) * resolved.mult)

#static func compute_damage(battle: SimBattle, attacker_id: int, defender_id: int, base: int) -> int:
	#var dealt := SimModifier.get_modified_value(battle, attacker_id, base, Modifier.Type.DMG_DEALT)
	#var taken := SimModifier.get_modified_value(battle, defender_id, dealt, Modifier.Type.DMG_TAKEN)
	#return maxi(taken, 0)
