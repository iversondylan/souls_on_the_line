class_name PhoenixBroochStatus extends Status

const ID := &"phoenix_brooch"

func get_id() -> StringName:
	return ID

func on_removal_will_resolve(ctx: SimStatusContext, removal_ctx: RemovalContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or removal_ctx == null:
		return
	if bool(removal_ctx.prevented):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(ctx.owner.max_health) <= 0:
		return

	removal_ctx.prevented = true
	var heal_ctx := HealContext.new(int(ctx.owner_id), int(ctx.owner_id), int(ctx.owner.max_health), 0.0, 0.0)
	ctx.api.heal(heal_ctx)
	ctx.remove_self("phoenix_brooch_saved")

func get_tooltip(_stacks: int = 0) -> String:
	return "The next time this unit would die, heal it to full instead and remove this status."
