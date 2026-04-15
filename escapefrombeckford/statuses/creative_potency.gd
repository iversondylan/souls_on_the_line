class_name CreativePotencyStatus extends Status

const ID := &"creative_potency"


func get_id() -> StringName:
	return ID


func on_summon_will_resolve(
	ctx: SimStatusContext,
	summon_ctx: SummonContext,
	summoned: CombatantState
) -> void:
	if ctx == null or !ctx.is_valid() or summon_ctx == null or summoned == null:
		return
	if !bool(summon_ctx.eligible_player_soul_summon):
		return
	if int(summon_ctx.source_id) != int(ctx.owner_id):
		return

	var bonus := maxi(int(ctx.get_intensity()), 0)
	if bonus <= 0:
		return

	summoned.ap += bonus
	summoned.max_health += bonus
	summoned.health = clampi(int(summoned.health) + bonus, 0, int(summoned.max_health))

	ctx.remove_self("creative_potency_consumed")


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Creative Potency: the next Soul you summon this turn enters with +%s/+%s." % [
		intensity,
		intensity,
	]
