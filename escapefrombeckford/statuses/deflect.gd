# deflect.gd

class_name DeflectStatus extends Status

const ID := &"deflect"
const PREVENTED_EVENT_KEY := &"deflect_prevented_damage"

func get_id() -> StringName:
	return ID

func on_damage_will_be_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return

	var stacks := int(ctx.get_stacks())
	if stacks <= 0:
		return

	var prevented_amount := maxi(int(damage_ctx.amount), 0)

	# Absorb is keyed to the next incoming hit, even if mitigation reduces that hit to 0.
	damage_ctx.amount = 0
	if prevented_amount > 0:
		if damage_ctx.event_extra == null:
			damage_ctx.event_extra = {}
		damage_ctx.event_extra[PREVENTED_EVENT_KEY] = prevented_amount
	if stacks <= 1:
		ctx.remove_self("deflect_consumed")
	else:
		ctx.change_stacks(-1, "deflect_consumed")

func get_tooltip(stacks: int = 0) -> String:
	return "Deflect: negate the next %s hit%s." % [
		stacks,
		"" if stacks == 1 else "s"
	]
