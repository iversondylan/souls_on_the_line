class_name AwaseStatus extends Status

const ID := &"awase"
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")

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

	if FULL_FORTITUDE == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = FULL_FORTITUDE.get_id()
	status_ctx.stacks = ctx.get_stacks()
	status_ctx.reason = "awase_absorb_prevented"
	ctx.api.apply_status(status_ctx)

func get_tooltip(stacks: int = 0) -> String:
	return "Awase: whenever Absorb prevents damage, gain %s Full Fortitude." % stacks
