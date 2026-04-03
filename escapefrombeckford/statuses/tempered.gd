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
	ctx.stack.intensity += max_health_per_strike
	var before_max_health := int(ctx.owner.max_health) if ctx.owner != null else 0
	var before_health := int(ctx.owner.health) if ctx.owner != null else 0
	ctx.api.change_max_health(ctx.owner_id, max_health_per_strike, false, "tempered")
	var bound_card_uid := String(ctx.owner.bound_card_uid) if ctx.owner != null else ""
	print(
		"[TEMPERED] proc owner=%d card_uid=%s before_hp=%d before_max=%d stack=%d damage=%d lethal=%s" % [
			int(ctx.owner_id),
			bound_card_uid,
			before_health,
			before_max_health,
			int(ctx.stack.intensity),
			int(damage_ctx.health_damage),
			str(bool(damage_ctx.was_lethal)),
		]
	)
	if !bound_card_uid.is_empty():
		ctx.api.add_summon_card_max_health_bonus(bound_card_uid, max_health_per_strike)
	else:
		print(
			"[TEMPERED] proc owner=%d has no bound card uid; skipping persistent bonus" % [
				int(ctx.owner_id),
			]
		)

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Tempered: gains %s maximum health for each strike survived. +%s maximum health." % [
		max_health_per_strike,
		intensity
	]
