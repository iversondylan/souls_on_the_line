# double_edge.gd

class_name DoubleEdgeStatus extends Status

const ID := Keys.STATUS_DOUBLE_EDGE


func get_id() -> StringName:
	return ID


func get_attack_self_damage_on_strike(ctx: SimStatusContext, _attack_ctx: AttackContext) -> int:
	if ctx == null or !ctx.is_valid():
		return 0
	return maxi(int(ctx.get_intensity()), 0)


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Double Edge: each damaging strike deals damage back to this unit equal to this status's intensity."
