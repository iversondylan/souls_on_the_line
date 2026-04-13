# absorb.gd

class_name AbsorbStatus extends Status

const ID := &"absorb"

func get_id() -> StringName:
	return ID

func on_damage_will_be_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return

	var intensity := int(ctx.get_intensity())
	if intensity <= 0:
		return

	# Absorb is keyed to the next incoming hit, even if mitigation reduces that hit to 0.
	damage_ctx.amount = 0
	if intensity <= 1:
		ctx.remove_self("absorb_consumed")
	else:
		ctx.change_intensity(-1, "absorb_consumed")

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Absorb: negate the next %s hit%s. Clears at the start of the player's turn." % [
		intensity,
		"" if intensity == 1 else "s"
	]
