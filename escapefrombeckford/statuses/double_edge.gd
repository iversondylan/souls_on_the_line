# double_edge.gd

class_name DoubleEdgeStatus extends Status

const ID := Keys.STATUS_DOUBLE_EDGE


func get_id() -> StringName:
	return ID


func get_attack_self_damage_on_strike(ctx: SimStatusContext, _attack_ctx: AttackContext) -> int:
	if ctx == null or !ctx.is_valid():
		return 0
	return maxi(int(ctx.get_stacks()), 0)


func get_tooltip(stacks: int = 0) -> String:
	return "Double Edge: on each srike, takes %s damage." % stacks
