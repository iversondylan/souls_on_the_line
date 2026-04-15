class_name SpiritedReturnStatus extends Status

const ID := &"spirited_return"
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var released_card_uid := String(removal_ctx.released_reserve_card_uid)
	if released_card_uid.is_empty():
		return

	var amount := maxi(int(ctx.get_intensity()), 0)
	if amount <= 0:
		return

	var ap_bonus := ctx.api.add_summon_card_ap_bonus(released_card_uid, amount)
	var max_health_bonus := ctx.api.add_summon_card_max_health_bonus(released_card_uid, amount)
	ctx.api.emit_modify_battle_card(
		released_card_uid,
		{
			Keys.AP: int(ap_bonus),
			Keys.SUMMON_MAX_HEALTH: int(max_health_bonus),
		},
		"spirited_return"
	)


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Spirited Return: On Death, if this unit has a summon reserve card, that card gains +%s AP and +%s max health." % [
		intensity,
		intensity,
	]
