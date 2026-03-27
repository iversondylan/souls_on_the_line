# param_model.gd

class_name ParamModel extends Resource

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

static func _actor_id(ctx: NPCAIContext) -> int:
	if ctx == null:
		return 0

	# SIM-first: CombatantState is deterministic and always present in headless.
	if ctx.combatant_state != null:
		return int(ctx.combatant_state.id)

	# NPCAIContext always has cid (RefCounted field), no need for `"cid" in ctx`.
	if int(ctx.cid) > 0:
		return int(ctx.cid)

	# LIVE fallback
	if ctx.combatant != null and is_instance_valid(ctx.combatant):
		return int(ctx.combatant.combat_id)

	return 0
