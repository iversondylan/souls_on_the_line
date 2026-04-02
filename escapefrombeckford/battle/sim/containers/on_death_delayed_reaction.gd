class_name OnDeathDelayedReaction extends DelayedReaction

var dead_id: int = 0
var killer_id: int = 0
var group_index: int = -1
var insert_index: int = -1
var reason: String = ""
var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	timing = Timing.AFTER_STRIKE


func execute(runtime: SimRuntime) -> void:
	if runtime == null or runtime.sim == null or runtime.sim.api == null:
		return

	SimStatusSystem.on_death(runtime.sim.api, int(dead_id), int(killer_id), String(reason))
