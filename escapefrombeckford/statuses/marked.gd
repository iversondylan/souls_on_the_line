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

func get_tooltip(_intensity: int = 0, duration: int = 0) -> String:
	if duration == 1:
		return "Marked: ranged attacks prioritize this target for 1 turn."
	return "Marked: ranged attacks prioritize this target for %s turns." % duration

func get_tooltip_sim(ctx: SimStatusContext) -> String:
	if ctx == null or !ctx.is_valid():
		return get_tooltip()
	return get_tooltip(ctx.get_intensity(), ctx.get_duration())
