class_name EmptyFortitudeStatus extends Status

const ID := &"empty_fortitude"

func get_id() -> StringName:
	return ID

func on_apply(ctx: SimStatusContext, apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or apply_ctx == null:
		return

	var amount := maxi(int(apply_ctx.delta_intensity), 0)
	if amount <= 0:
		return

	ctx.api.change_max_health(int(ctx.owner_id), amount, false, "empty_fortitude")

func on_remove(ctx: SimStatusContext, _remove_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return

	var amount := maxi(int(ctx.get_intensity()), 0)
	if amount <= 0:
		return

	ctx.api.change_max_health(int(ctx.owner_id), -amount, false, "empty_fortitude")

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Empty Fortitude: gain +%s max health. Added health is not healed." % intensity
