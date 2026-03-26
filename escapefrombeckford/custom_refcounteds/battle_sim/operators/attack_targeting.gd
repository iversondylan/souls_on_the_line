# attack_targeting.gd

class_name AttackTargeting extends RefCounted

static func get_target_ids(ctx: TargetingContext) -> Array[int]:
	if ctx == null or ctx.api == null:
		return []
	if int(ctx.source_id) <= 0 or !ctx.api.is_alive(int(ctx.source_id)):
		return []

	if !ctx.explicit_target_ids.is_empty():
		ctx.base_target_ids = ctx.explicit_target_ids.duplicate()
	else:
		ctx.base_target_ids = _get_base_target_ids(ctx)

	ctx.base_target_ids = ctx.base_target_ids.filter(func(id):
		return int(id) > 0 and ctx.api.is_alive(int(id))
	)

	ctx.final_target_ids = ctx.base_target_ids.duplicate()
	ctx.is_single_target_intent = _is_single(ctx)

	if ctx.is_single_target_intent and int(ctx.attack_mode) == int(Attack.Mode.RANGED):
		ctx.redirect_target_id = ctx.api.find_marked_ranged_redirect_target(int(ctx.source_id))
		if int(ctx.redirect_target_id) > 0 and ctx.final_target_ids.size() == 1:
			ctx.final_target_ids[0] = int(ctx.redirect_target_id)

	return ctx.final_target_ids


static func _get_base_target_ids(ctx: TargetingContext) -> Array[int]:
	var out: Array[int] = []
	var target_type := int(ctx.target_type)

	match target_type:
		Attack.Targeting.STANDARD:
			var my_group := ctx.api.get_group(int(ctx.source_id))
			if my_group < 0:
				return out

			var opp := ctx.api.get_opposing_group(my_group)
			var front := ctx.api.get_front_combatant_id(opp)
			if front > 0:
				out.append(int(front))
			return out

		Attack.Targeting.ENEMIES:
			return ctx.api.get_enemies_of(int(ctx.source_id))

		Attack.Targeting.ALL:
			var ids0: Array[int] = ctx.api.get_combatants_in_group(0, false)
			var ids1: Array[int] = ctx.api.get_combatants_in_group(1, false)
			out.append_array(ids0)
			out.append_array(ids1)
			return out

	return out


static func _is_single(ctx: TargetingContext) -> bool:
	var target_type := int(ctx.target_type)
	return target_type == Attack.Targeting.STANDARD
