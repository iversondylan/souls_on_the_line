class_name RemovalDelayedReaction extends DelayedReaction

var removal_ctx = null


func _init() -> void:
	timing = Timing.AFTER_STRIKE


func execute(runtime: SimRuntime) -> void:
	if runtime == null or runtime.sim == null or runtime.sim.api == null or removal_ctx == null:
		return

	var api := runtime.sim.api
	var any_death_listener_owner_ids := api.get_owned_any_death_listener_owner_ids_for_group(
		int(removal_ctx.group_index)
	)
	SimStatusSystem.on_removal(api, removal_ctx)
	SimArcanaSystem.on_removal(api, removal_ctx)
	SimStatusSystem.on_any_death(api, removal_ctx, any_death_listener_owner_ids)
