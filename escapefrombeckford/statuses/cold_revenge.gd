class_name ColdRevengeStatus extends Status

const ID := &"cold_revenge"
const MIGHT := preload("res://statuses/might.tres")


func get_id() -> StringName:
	return ID


func listens_for_any_death() -> bool:
	return true


func on_any_death(ctx: SimStatusContext, removal_ctx: RemovalContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.state == null or removal_ctx == null:
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if ctx.owner == null or int(removal_ctx.group_index) != int(ctx.owner.team):
		return
	if int(removal_ctx.target_id) == int(ctx.owner_id):
		return

	var removed_unit := ctx.api.state.get_unit(int(removal_ctx.target_id))
	if removed_unit == null:
		return
	if int(removed_unit.mortality) != int(CombatantState.Mortality.BOUND):
		return

	var amount := maxi(int(ctx.get_stacks()), 1)
	if MIGHT == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = MIGHT.get_id()
	status_ctx.stacks = amount
	status_ctx.reason = "cold_revenge"
	ctx.api.apply_status(status_ctx)


func get_tooltip(stacks: int = 0) -> String:
	return "Cold Revenge: whenever a SoulBound ally dies, gain %s Might." % maxi(stacks, 1)
