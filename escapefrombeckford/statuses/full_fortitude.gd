class_name FullFortitudeStatus extends Status

const ID := &"full_fortitude"

func get_id() -> StringName:
	return ID

func on_apply(ctx: SimStatusContext, apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or apply_ctx == null:
		return

	var amount := maxi(int(apply_ctx.delta_stacks), 0)
	if amount <= 0:
		return

	ctx.api.change_max_health(int(ctx.owner_id), amount, true, "full_fortitude")

func on_remove(ctx: SimStatusContext, _remove_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return

	var amount := maxi(int(ctx.get_stacks()), 0)
	if amount <= 0:
		return

	ctx.api.change_max_health(int(ctx.owner_id), -amount, true, "full_fortitude")

func get_tooltip(stacks: int = 0) -> String:
	return "Fortitude: increase max health by %s (Fortitude %s)." % [stacks, stacks]
