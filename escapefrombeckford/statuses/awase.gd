class_name AwaseStatus extends Status

const ID := &"awase"

func get_id() -> StringName:
	return ID

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if damage_ctx.event_extra == null:
		return

	var prevented_amount := int(damage_ctx.event_extra.get(AbsorbStatus.PREVENTED_EVENT_KEY, 0))
	if prevented_amount <= 0:
		return

	ctx.api.change_max_health(int(ctx.owner_id), 1, false, "awase_absorb_prevented")

func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Awase: whenever Absorb on this prevents damage, gain +1 max health."
