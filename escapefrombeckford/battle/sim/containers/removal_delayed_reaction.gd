class_name RemovalDelayedReaction extends DelayedReaction

const SimArcanaSystemScript = preload("res://battle/sim/operators/sim_arcana_system.gd")

var removal_ctx = null


func _init() -> void:
	timing = Timing.AFTER_STRIKE


func execute(runtime: SimRuntime) -> void:
	if runtime == null or runtime.sim == null or runtime.sim.api == null or removal_ctx == null:
		return

	SimStatusSystem.on_removal(runtime.sim.api, removal_ctx)
	SimArcanaSystemScript.on_removal(runtime.sim.api, removal_ctx)
