class_name FightersSpiritStatus extends Status

const ID := &"fighters_spirit"
const SPIRITED_RETURN_STATUS := preload("res://statuses/spirited_return.tres")


func get_id() -> StringName:
	return ID


func on_strike_resolved(
	ctx: SimStatusContext,
	_attack_ctx: AttackContext,
	_strike_index: int,
	_target_ids: Array[int]
) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return

	var amount := maxi(int(ctx.get_stacks()), 0)
	if amount <= 0:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = SPIRITED_RETURN_STATUS.get_id()
	status_ctx.stacks = amount
	status_ctx.reason = "fighters_spirit"
	ctx.api.apply_status(status_ctx)


func get_tooltip(stacks: int = 0) -> String:
	return "Fighter's Spirit: whenever this unit strikes, gain %s Spirited Return." % stacks
