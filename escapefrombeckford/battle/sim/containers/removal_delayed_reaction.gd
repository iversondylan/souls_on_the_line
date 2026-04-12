class_name RemovalDelayedReaction extends DelayedReaction

var removal_ctx = null


func _init() -> void:
	timing = Timing.AFTER_STRIKE


func execute(runtime: SimRuntime) -> void:
	if runtime == null or runtime.sim == null or runtime.sim.api == null or removal_ctx == null:
		return

	SimStatusSystem.on_removal(runtime.sim.api, removal_ctx)
	SimArcanaSystem.on_removal(runtime.sim.api, removal_ctx)
