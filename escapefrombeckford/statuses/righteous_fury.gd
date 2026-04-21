class_name RighteousFuryStatus extends Status

const ID := &"righteous_fury"
const RAGE := preload("res://statuses/rage.tres")


func get_id() -> StringName:
	return ID


func listens_for_any_death() -> bool:
	return true


func on_any_death(ctx: SimStatusContext, removal_ctx: RemovalContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or removal_ctx == null:
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if ctx.owner == null or int(removal_ctx.group_index) != int(ctx.owner.team):
		return
	if int(removal_ctx.target_id) == int(ctx.owner_id):
		return

	var amount := maxi(int(ctx.get_stacks()), 0)
	if amount <= 0 or RAGE == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = RAGE.get_id()
	status_ctx.stacks = amount
	status_ctx.reason = "righteous_fury"
	ctx.api.apply_status(status_ctx)


func get_tooltip(stacks: int = 0) -> String:
	return "Righteous Fury: whenever another ally dies, gain %s Rage." % stacks
