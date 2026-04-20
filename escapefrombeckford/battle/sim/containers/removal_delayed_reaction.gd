class_name RemovalDelayedReaction extends DelayedReaction

const Interceptor := preload("res://battle/sim/interceptors/interceptor.gd")

var removal_ctx = null
var any_death_interceptors: Array[Interceptor] = []


func _init() -> void:
	timing = Timing.AFTER_STRIKE


func execute(runtime: SimRuntime) -> void:
	if runtime == null or runtime.sim == null or runtime.sim.api == null or removal_ctx == null:
		return

	var api := runtime.sim.api
	SimStatusSystem.on_removal(api, removal_ctx)
	SimArcanaSystem.on_removal(api, removal_ctx)
	for interceptor: Interceptor in any_death_interceptors:
		if interceptor != null:
			interceptor.dispatch(api, removal_ctx)
