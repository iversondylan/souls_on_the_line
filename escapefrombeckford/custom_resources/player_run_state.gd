class_name PlayerRunState extends Resource

@export var current_health: int = 0

func heal(max_health: int, ctx: HealContext) -> int:
	if ctx == null:
		return 0
	if ctx.flat_amount < 0 or ctx.of_total < 0.0 or ctx.of_missing < 0.0:
		push_warning("PlayerRunState.heal(): negative heal")
		return 0

	var clamped_max := maxi(int(max_health), 0)
	var initial_health := clampi(int(current_health), 0, clamped_max)
	var new_health := clampi(initial_health + int(ctx.flat_amount), 0, clamped_max)
	new_health = clampi(new_health + floori(float(new_health) * float(ctx.of_total)), 0, clamped_max)
	new_health = clampi(new_health + floori(float(clamped_max - new_health) * float(ctx.of_missing)), 0, clamped_max)
	current_health = new_health
	return int(current_health - initial_health)
