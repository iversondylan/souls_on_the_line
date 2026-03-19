# attack_targeting.gd

class_name AttackTargeting extends RefCounted

static func get_target_ids(api: SimBattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	if api == null or attacker_id <= 0 or !api.is_alive(attacker_id):
		return []

	var base: Array[int] = _get_base_target_ids(api, attacker_id, params)
	base = base.filter(func(id): return int(id) > 0 and api.is_alive(int(id)))

	var final: Array[int] = base.duplicate()

	var is_single := _is_single(params)
	var attack_mode := int(params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))

	if is_single and attack_mode == Attack.Mode.RANGED:
		var redirect := api.find_marked_ranged_redirect_target(attacker_id)
		if redirect > 0 and final.size() == 1:
			final[0] = redirect

	return final


static func _get_base_target_ids(api: SimBattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var target_type := int(params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))

	match target_type:
		Attack.Targeting.STANDARD:
			var my_group := api.get_group(attacker_id)
			if my_group < 0:
				return out

			var opp := api.get_opposing_group(my_group)
			var front := api.get_front_combatant_id(opp)
			if front > 0:
				out.append(int(front))
			return out

		Attack.Targeting.ENEMIES:
			return api.get_enemies_of(attacker_id)

		Attack.Targeting.ALL:
			var ids0: Array[int] = api.get_combatants_in_group(0, false)
			var ids1: Array[int] = api.get_combatants_in_group(1, false)
			out.append_array(ids0)
			out.append_array(ids1)
			return out

	return out


static func _is_single(params: Dictionary) -> bool:
	var target_type := int(params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	return target_type == Attack.Targeting.STANDARD
