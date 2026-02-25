# attack_targeting.gd

class_name AttackTargeting extends RefCounted
#
#
#static func get_targets_for_attack_sequence(api: BattleAPI, ai_ctx: NPCAIContext) -> Array[int]:
	#if !api or !ai_ctx:
		#return []
#
	#var attacker_id := 0
#
	## Prefer explicit ctx.cid if you’re carrying it
	#if "cid" in ai_ctx and int(ai_ctx.cid) > 0:
		#attacker_id = int(ai_ctx.cid)
	#elif ai_ctx.combatant:
		#attacker_id = int(ai_ctx.combatant.combat_id)
	#elif ai_ctx.combatant_data:
		#attacker_id = int(ai_ctx.combatant_data.combat_id)
#
	#if attacker_id <= 0:
		#print("[SIM][TGT] no attacker_id")
		#return []
#
	#if !api.is_alive(attacker_id):
		#print("[SIM][TGT] attacker dead attacker_id=%d" % attacker_id)
		#return []
#
	#var params: Dictionary = ai_ctx.params if ai_ctx.params else {}
#
	#print("[SIM][TGT] attacker=%d group=%d opp=%d params=%s"
		#% [
			#attacker_id,
			#api.get_group(attacker_id),
			#api.get_opposing_group(api.get_group(attacker_id)),
			#params
		#])
#
	## 1) base targets
	#var base_targets := _get_base_targets(api, attacker_id, params)
	#base_targets = base_targets.filter(func(id): return int(id) > 0 and api.is_alive(int(id)))
#
	#print("[SIM][TGT] base=%s (type=%s mode=%s)"
		#% [
			#base_targets,
			#String(params.get(NPCKeys.TARGET_TYPE, "??")),
			#String(params.get(NPCKeys.ATTACK_MODE, "??"))
		#])
#
	## 2) final targets (copy)
	#var final_targets: Array[int] = base_targets.duplicate()
#
	## 3) modifiers (Marked redirect etc.)
	#var is_single := _is_single_target(params)
	#_apply_target_modifiers(api, attacker_id, params, is_single, final_targets)
#
	#print("[SIM][TGT] final=%s" % [final_targets])
	#return final_targets

static func _get_base_targets(api: BattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	var target_type := String(params.get(NPCKeys.TARGET_TYPE, NPCAttackSequence.TARGET_STANDARD))

	match target_type:
		NPCAttackSequence.TARGET_STANDARD:
			var enemy_group := api.get_opposing_group(api.get_group(attacker_id))
			var front_id := api.get_front_combatant_id(enemy_group)
			return [front_id] as Array[int] if front_id > 0 else [] as Array[int]

		NPCAttackSequence.TARGET_OPPONENTS:
			return api.get_enemies_of(attacker_id)

		NPCAttackSequence.TARGET_ALL:
			# If you want this, add api.get_all_combatant_ids().
			# For now: concat both groups.
			var g0 := api.get_combatants_in_group(0, false)
			var g1 := api.get_combatants_in_group(1, false)
			return g0 + g1

	return []


static func _is_single_target(params: Dictionary) -> bool:
	var target_type := String(params.get(NPCKeys.TARGET_TYPE, NPCAttackSequence.TARGET_STANDARD))
	return target_type == NPCAttackSequence.TARGET_STANDARD


static func _apply_target_modifiers(
	api: BattleAPI,
	attacker_id: int,
	params: Dictionary,
	is_single_target_intent: bool,
	final_targets: Array[int]
) -> void:
	# Example: Marked redirect for RANGED only
	var attack_mode := String(params.get(NPCKeys.ATTACK_MODE, NPCAttackSequence.ATTACK_MODE_MELEE))
	if attack_mode != NPCAttackSequence.ATTACK_MODE_RANGED:
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
	var attack_mode : int = params.get(NPCKeys.ATTACK_MODE, Attack.Mode.MELEE)

	if is_single and attack_mode == Attack.Mode.RANGED:
		var redirect := api.find_marked_ranged_redirect_target(attacker_id)
		if redirect > 0:
			if final.size() == 1:
				final[0] = redirect

	return final


static func _get_base_target_ids(api: BattleAPI, attacker_id: int, params: Dictionary) -> Array[int]:
	print("attack_targeting.gd _get_base_target_ids() attacker_id: %s, params: %s" % [attacker_id, params])
	var target_type := String(params.get(NPCKeys.TARGET_TYPE, NPCAttackSequence.TARGET_STANDARD))

	match target_type:
		NPCAttackSequence.TARGET_STANDARD:
			var my_group := api.get_group(attacker_id)
			var opp := api.get_opposing_group(my_group)
			var front := api.get_front_combatant_id(opp)
			return [front] as Array[int] if front > 0 else [] as Array[int]

		NPCAttackSequence.TARGET_OPPONENTS:
			return api.get_enemies_of(attacker_id)

		NPCAttackSequence.TARGET_ALL:
			# if you want, add api.get_all_combatant_ids()
			return api.get_combatants_in_group(0, false) + api.get_combatants_in_group(1, false)

	return []


static func _is_single(params: Dictionary) -> bool:
	var target_type := String(params.get(NPCKeys.TARGET_TYPE, NPCAttackSequence.TARGET_STANDARD))
	return target_type == NPCAttackSequence.TARGET_STANDARD
