# attack_targeting.gd

class_name AttackTargeting extends RefCounted

static func _apply_target_modifiers(
	api: BattleAPI,
	attacker_id: int,
	params: Dictionary,
	is_single_target_intent: bool,
	final_targets: Array[int]
) -> void:
	# Example: Marked redirect for RANGED only
	var attack_mode := int(params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	if attack_mode != Attack.Mode.RANGED:
		return
	if !is_single_target_intent:
		return

	var redirect_id := api.find_marked_ranged_redirect_target(attacker_id)
	if redirect_id <= 0:
		return

	# Redirect only if not already targeting it
	if final_targets.size() == 1 and final_targets[0] != redirect_id:
		final_targets[0] = redirect_id

static func get_target_ids(api: BattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	if !api or attacker_id <= 0 or !api.is_alive(attacker_id):
		return []

	var base := _get_base_target_ids(api, attacker_id, params)
	base = base.filter(func(id): return id > 0 and api.is_alive(id))

	var final: Array[int] = base.duplicate()

	var is_single := _is_single(params)
	var attack_mode : int = params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)

	if is_single and attack_mode == Attack.Mode.RANGED:
		var redirect := api.find_marked_ranged_redirect_target(attacker_id)
		if redirect > 0:
			if final.size() == 1:
				final[0] = redirect

	return final


static func _get_base_target_ids(api: BattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	#print("attack_targeting.gd _get_base_target_ids() attacker_id: %s, params: %s" % [attacker_id, params])
	var target_type := int(params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))

	match target_type:
		Attack.Targeting.STANDARD:
			var my_group := api.get_group(attacker_id)
			var opp := api.get_opposing_group(my_group)
			var front := api.get_front_combatant_id(opp)
			return [front] as Array[int] if front > 0 else [] as Array[int]

		Attack.Targeting.ENEMIES:
			return api.get_enemies_of(attacker_id)

		Attack.Targeting.ALL:
			# if you want, add api.get_all_combatant_ids()
			return api.get_combatants_in_group(0, false) + api.get_combatants_in_group(1, false)

	return []


static func _is_single(params: Dictionary) -> bool:
	var target_type := int(params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	return target_type == Attack.Targeting.STANDARD
