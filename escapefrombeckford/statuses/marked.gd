# marked.gd

class_name MarkedStatus extends Status

const ID := &"marked"

func on_apply(ctx: SimStatusContext, apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null:
		return

	var owner_id := int(ctx.owner_id)
	if owner_id <= 0:
		return

	var owner_group := int(ctx.owner.team)
	var ids := ctx.api.get_combatants_in_group(owner_group, true)

	for other_id in ids:
		var oid := int(other_id)
		if oid <= 0 or oid == owner_id:
			continue

		var remove_ctx := StatusContext.new()
		remove_ctx.source_id = int(apply_ctx.source_id if apply_ctx != null else owner_id)
		remove_ctx.target_id = oid
		remove_ctx.status_id = ID

		ctx.api.remove_status(remove_ctx)

func get_id() -> StringName:
	return ID

func get_targeting_priority(stage: int) -> int:
	if int(stage) == int(TargetingContext.Stage.RETARGET):
		return 100
	return 1000

func listens_for_targeting_retarget() -> bool:
	return true


func on_targeting_retarget(ctx: SimStatusContext, targeting_ctx: TargetingContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.owner == null or targeting_ctx == null:
		return
	if !targeting_ctx.is_single_target_intent:
		return
	if int(targeting_ctx.attack_mode) != int(Attack.Mode.RANGED):
		return

	var owner_id := int(ctx.owner_id)
	if owner_id <= 0:
		return
	if int(ctx.owner.team) != int(targeting_ctx.defending_group_index):
		return
	if !targeting_ctx.api.is_alive(owner_id):
		return

	targeting_ctx.redirect_target_id = owner_id
	targeting_ctx.working_target_ids = [owner_id]

func get_tooltip(stacks: int = 0) -> String:
	if stacks == 1:
		return "Marked: ranged attacks prioritize this target for 1 turn."
	return "Marked: ranged attacks prioritize this target for %s turns." % stacks

func get_tooltip_sim(ctx: SimStatusContext) -> String:
	if ctx == null or !ctx.is_valid():
		return get_tooltip()
	return get_tooltip(ctx.get_stacks())
