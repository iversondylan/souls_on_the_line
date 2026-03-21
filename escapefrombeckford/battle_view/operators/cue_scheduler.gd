# cue_scheduler.gd

class_name CueScheduler extends RefCounted

func play_plan(clock: BattleClock, director: BattleEventDirector, plan: DirectorPlan, gen: int) -> void:
	for cue in plan.cues:
		var fire_t := plan.t_start_sec + cue.beat_q * clock.seconds_per_quarter()
		if fire_t > clock.now_sec():
			await clock.wait_until(fire_t)

		#print(_debug_cue_fire_line(clock, plan, cue))
		director.on_director_cue(cue, gen)

	var end_t := plan.get_end_sec()
	if end_t > clock.now_sec():
		await clock.wait_until(end_t)


func _debug_cue_fire_line(clock: BattleClock, plan: DirectorPlan, cue: DirectorCue) -> String:
	var now := clock.now_sec()
	var fire_t := plan.t_start_sec + cue.beat_q * clock.seconds_per_quarter()
	var slip := now - fire_t
	return "[CUE] idx=%d q=%.2f fire=%.3f now=%.3f slip=%.3f label=%s orders=%s events=%d" % [
		int(cue.index),
		float(cue.beat_q),
		fire_t,
		now,
		slip,
		String(cue.label),
		_debug_order_summary_local(cue.orders),
		cue.events.size(),
	]


func _debug_order_summary_local(orders: Array[PresentationOrder]) -> String:
	if orders == null or orders.is_empty():
		return "[]"

	var parts: Array[String] = []
	for o in orders:
		if o == null:
			parts.append("<null>")
			continue

		var kind_name := str(int(o.kind))
		if int(o.kind) >= 0 and int(o.kind) < PresentationOrder.Kind.keys().size():
			kind_name = PresentationOrder.Kind.keys()[int(o.kind)]

		var bit := "%s(a=%d" % [kind_name, int(o.actor_id)]
		if o.target_ids != null and !o.target_ids.is_empty():
			bit += " tgts=%s" % str(o.target_ids)
		bit += ")"
		parts.append(bit)

	return "[" + " | ".join(parts) + "]"
