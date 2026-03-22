# cue_scheduler.gd

class_name CueScheduler extends RefCounted

func play_plan(clock: BattleClock, director: BattleEventDirector, plan: DirectorPlan, gen: int) -> void:
	for cue in plan.cues:
		var fire_t := plan.t_start_sec + cue.beat_q * clock.seconds_per_quarter()
		if fire_t > clock.now_sec():
			await clock.wait_until(fire_t)

		print(_debug_cue_fire_line(clock, plan, cue))
		director.on_director_cue(cue, gen)

	var end_t := plan.get_end_sec()
	if end_t > clock.now_sec():
		await clock.wait_until(end_t)


func _debug_cue_fire_line(clock: BattleClock, plan: DirectorPlan, cue: DirectorCue) -> String:
	var now := clock.now_sec()
	var fire_t := plan.t_start_sec + cue.beat_q * clock.seconds_per_quarter()
	var slip := now - fire_t
	return "[CUE] idx=%d q=%.2f fire=%.3f now=%.3f slip=%.3f label=%s orders=%s events=%s" % [
		int(cue.index),
		float(cue.beat_q),
		fire_t,
		now,
		slip,
		String(cue.label),
		_debug_order_summary_local(cue.orders),
		_debug_event_summary_local(cue.events),
	]

func _debug_event_summary_local(events: Array[BattleEvent]) -> String:
	if events == null or events.is_empty():
		return "[]"

	var parts: Array[String] = []
	for e in events:
		if e == null:
			parts.append("<null>")
			continue
		parts.append(_debug_event_short_local(e))

	return "[" + " | ".join(parts) + "]"


func _debug_event_short_local(e: BattleEvent) -> String:
	if e == null:
		return "<null>"

	var type_name := str(int(e.type))
	if int(e.type) >= 0 and int(e.type) < BattleEvent.Type.keys().size():
		type_name = BattleEvent.Type.keys()[int(e.type)]

	var actor_id := 0
	var source_id := 0
	var target_id := 0
	var group_index := int(e.group_index)

	if e.data != null:
		if e.data.has(Keys.ACTOR_ID):
			actor_id = int(e.data[Keys.ACTOR_ID])
		if e.data.has(Keys.SOURCE_ID):
			source_id = int(e.data[Keys.SOURCE_ID])
		if e.data.has(Keys.TARGET_ID):
			target_id = int(e.data[Keys.TARGET_ID])
		if e.data.has(Keys.GROUP_INDEX):
			group_index = int(e.data[Keys.GROUP_INDEX])

	return "%s(a=%s src=%s tgt=%s g=%s seq=%s beat=%s)" % [
		type_name,
		actor_id,
		source_id,
		target_id,
		group_index,
		int(e.seq),
		str(bool(e.defines_beat)),
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
