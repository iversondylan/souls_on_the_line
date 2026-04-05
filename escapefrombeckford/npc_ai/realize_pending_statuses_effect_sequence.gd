# realize_pending_statuses_effect_sequence.gd

class_name RealizePendingStatusesEffectSequence extends NPCEffectSequence

func realizes_pending_statuses() -> bool:
	return true

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("realize_pending_statuses_effect_sequence.gd execute(): missing runtime")
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	runtime.run_realize_pending_statuses(actor_id, actor_id, "npc_realize_pending_statuses")
