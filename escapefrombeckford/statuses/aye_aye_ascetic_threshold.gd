class_name AyeAyeAsceticThresholdStatus extends Status

const ID := &"aye_aye_ascetic_threshold"
const ABSORB := preload("res://statuses/absorb.tres")
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")

func get_id() -> StringName:
	return ID

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if int(damage_ctx.health_damage) <= 0:
		return
	if bool(damage_ctx.was_lethal):
		return
	if !ctx.owner.is_alive():
		return

	var max_health := maxi(int(ctx.owner.max_health), 1)
	var crossed_below_half := (
		int(damage_ctx.before_health) * 2 >= max_health
		and int(damage_ctx.after_health) * 2 < max_health
	)
	if !crossed_below_half:
		return

	_apply_status(ctx, ABSORB, 1, "aye_aye_ascetic_absorb")
	_apply_status(ctx, FULL_FORTITUDE, 2, "aye_aye_ascetic_fortitude")
	_update_bound_card_max_health(ctx, 2)
	ctx.remove_self("aye_aye_ascetic_triggered")

func get_tooltip(_stacks: int = 0) -> String:
	return "The first time each round damage leaves this below 50%% health, gain Absorb and +2 Full Fortitude."

func _apply_status(ctx: SimStatusContext, status: Status, stacks: int, reason: String) -> void:
	if ctx == null or status == null:
		return
	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = status.get_id()
	status_ctx.stacks = stacks
	status_ctx.reason = reason
	ctx.api.apply_status(status_ctx)

func _update_bound_card_max_health(ctx: SimStatusContext, amount: int) -> void:
	if ctx == null or ctx.api == null or ctx.owner == null or amount <= 0:
		return
	var bound_card_uid := String(ctx.owner.bound_card_uid)
	if bound_card_uid.is_empty():
		return
	var before_bonus := ctx.api.get_summon_card_max_health_bonus(bound_card_uid)
	var after_bonus := ctx.api.add_summon_card_max_health_bonus(bound_card_uid, amount)
	if after_bonus == before_bonus:
		return
	ctx.api.emit_modify_battle_card(
		bound_card_uid,
		{Keys.SUMMON_MAX_HEALTH: int(ctx.owner.max_health)},
		"aye_aye_ascetic_threshold"
	)
