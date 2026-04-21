# tempered.gd

class_name TemperedStatus extends Status

const ID := &"tempered"
var max_health_per_strike := 1

func get_id() -> StringName:
	return ID

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	#print("tempered.gd on_damage_taken()")
	if ctx == null or damage_ctx == null:
		return
	if damage_ctx.target_id <= 0:
		return
	if ctx.owner_id != damage_ctx.target_id:
		return

	# Only care about actual health damage from a survived strike.
	if int(damage_ctx.health_damage) <= 0:
		return
	if bool(damage_ctx.was_lethal):
		return
	if !ctx.owner.is_alive():
		return
	ctx.token.stacks += max_health_per_strike
	ctx.api.change_max_health(ctx.owner_id, max_health_per_strike, false, "tempered")
	var bound_card_uid := String(ctx.owner.bound_card_uid) if ctx.owner != null else ""
	if !bound_card_uid.is_empty():
		var before_bonus := ctx.api.get_summon_card_max_health_bonus(bound_card_uid)
		var after_bonus := ctx.api.add_summon_card_max_health_bonus(bound_card_uid, max_health_per_strike)
		if after_bonus != before_bonus:
			ctx.api.emit_modify_battle_card(
				bound_card_uid,
				{Keys.SUMMON_MAX_HEALTH: int(ctx.owner.max_health)},
				"tempered"
			)

func get_tooltip(stacks: int = 0) -> String:
	return "Tempered: gain %s max health whenever this unit survives strike damage. Current bonus: +%s max health." % [
		max_health_per_strike,
		stacks
	]
