# tempered.gd

class_name TemperedStatus extends Status

const ID := &"tempered"

func get_id() -> StringName:
	return ID

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or damage_ctx == null:
		return
	if damage_ctx.target_id <= 0:
		return
	if ctx.owner_id != damage_ctx.target_id:
		return

	var amount := maxi(int(ctx.token.stacks), 0)
	if amount <= 0:
		return

	ctx.api.change_max_health(ctx.owner_id, amount, false, "tempered")
	var bound_card_uid := String(ctx.owner.bound_card_uid) if ctx.owner != null else ""
	if !bound_card_uid.is_empty():
		var before_bonus := ctx.api.get_summon_card_max_health_bonus(bound_card_uid)
		var after_bonus := ctx.api.add_summon_card_max_health_bonus(bound_card_uid, amount)
		if after_bonus != before_bonus:
			ctx.api.emit_modify_battle_card(
				bound_card_uid,
				{Keys.SUMMON_MAX_HEALTH: int(ctx.owner.max_health)},
				"tempered"
			)

func get_tooltip(stacks: int = 0) -> String:
	var amount := maxi(int(stacks), 0)
	return "Tempered: when hit, gain %s max health. This persists on-card for the battle." % amount
