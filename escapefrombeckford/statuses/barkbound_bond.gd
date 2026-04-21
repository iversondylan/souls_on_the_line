class_name BarkboundBondStatus extends Status

const ID := &"barkbound_bond"
const MIGHT := preload("res://statuses/might.tres")
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

	_apply_status(ctx, MIGHT, 1, "barkbound_bond_might")
	_apply_status(ctx, FULL_FORTITUDE, 2, "barkbound_bond_fortitude")

	if int(ctx.get_stacks()) <= 1:
		ctx.remove_self("barkbound_bond_spent")
	else:
		ctx.change_stacks(-1, "barkbound_bond_trigger")

func get_tooltip(stacks: int = 0) -> String:
	return "Barkbound Bond: the next %s time%s this survives damage, it gains +1 Might and +2 Full Fortitude." % [
		stacks,
		"" if stacks == 1 else "s",
	]

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
