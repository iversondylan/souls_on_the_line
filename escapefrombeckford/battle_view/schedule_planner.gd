# schedule_planner.gd

class_name SchedulePlanner extends RefCounted

var beats_per_bar: int = 4


func make_npc_turn_plan(
	clock: BattleClock,
	turn_events: Array[BattleEvent],
	speed_mode: int,
	start_sec: float
) -> SchedulePlan:
	var plan := SchedulePlan.new()
	plan.t_start = start_sec

	var unit_quarters := _unit_quarters_for_speed(speed_mode)
	var unit_sec := unit_quarters * clock.seconds_per_quarter()

	var action_units := _extract_action_units(turn_events)
	var n_units := action_units.size()
	var measures := _measures_for_action_units(n_units, action_units)
	var total_sec := unit_sec * float(measures)

	plan.measures = measures
	plan.t_end = plan.t_start + total_sec

	if n_units <= 0:
		plan.actions = []
		return plan

	if measures == 1:
		_build_one_measure_plan(plan, turn_events, action_units, total_sec)
	else:
		_build_multi_measure_plan(plan, turn_events, action_units, total_sec, measures)

	return plan


func _build_one_measure_plan(
	plan: SchedulePlan,
	turn_events: Array[BattleEvent],
	action_units: Array[Dictionary],
	total_sec: float
) -> void:
	var q := total_sec / 4.0
	var primary_kind := int(action_units[0].get("action_kind", DirectorAction.ActionKind.GENERIC))

	var focus_payload: Array = turn_events
	var windup_payload: Array = [action_units[0].get("marker")]
	var follow_payload: Array = []
	var resolve_payload: Array = []

	for unit in action_units:
		var unit_events: Array = unit.get("events", [])
		for e in unit_events:
			var be := e as BattleEvent
			if be == null:
				continue
			if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
				resolve_payload.append(be)
			else:
				follow_payload.append(be)

	var a_focus := _make_phase_action(
		DirectorAction.Phase.FOCUS,
		primary_kind,
		0.0,
		q,
		focus_payload,
		"focus"
	)
	a_focus.event = _make_focus_event_from_payload(primary_kind, focus_payload)

	var a_windup := _make_phase_action(
		DirectorAction.Phase.WINDUP,
		primary_kind,
		q,
		q,
		windup_payload,
		"windup"
	)
	a_windup.event = _make_windup_event_from_unit(action_units[0])

	var a_follow := _make_phase_action(
		DirectorAction.Phase.FOLLOWTHROUGH,
		primary_kind,
		2.0 * q,
		q,
		follow_payload,
		"followthrough"
	)
	a_follow.event = _make_followthrough_event_from_unit(action_units[0])

	var a_resolve := _make_phase_action(
		DirectorAction.Phase.RESOLVE,
		_resolve_kind(resolve_payload, primary_kind),
		3.0 * q,
		q,
		resolve_payload,
		"resolve"
	)
	a_resolve.event = _make_resolve_event(resolve_payload, primary_kind)

	plan.actions = [a_focus, a_windup, a_follow, a_resolve]


func _build_multi_measure_plan(
	plan: SchedulePlan,
	turn_events: Array[BattleEvent],
	action_units: Array[Dictionary],
	total_sec: float,
	measures: int
) -> void:
	var total_beats := measures * 4
	var beat_sec := total_sec / float(total_beats)
	var primary_kind := int(action_units[0].get("action_kind", DirectorAction.ActionKind.GENERIC))

	var actions: Array[DirectorAction] = []

	var a_focus := _make_phase_action(
		DirectorAction.Phase.FOCUS,
		primary_kind,
		0.0,
		beat_sec,
		turn_events,
		"focus"
	)
	a_focus.event = _make_focus_event_from_payload(primary_kind, turn_events)
	actions.append(a_focus)

	var a_windup := _make_phase_action(
		DirectorAction.Phase.WINDUP,
		primary_kind,
		beat_sec,
		3.0 * beat_sec,
		[action_units[0].get("marker")],
		"windup"
	)
	a_windup.event = _make_windup_event_from_unit(action_units[0])
	actions.append(a_windup)

	var follow_slots := total_beats - 5
	if follow_slots < 1:
		follow_slots = 1

	var clusters := _cluster_units(action_units, follow_slots)
	for i in range(clusters.size()):
		var cluster: Array = clusters[i]
		if cluster.is_empty():
			continue

		var payload: Array = []
		for unit in cluster:
			var unit_events: Array = unit.get("events", [])
			for e in unit_events:
				var be := e as BattleEvent
				if be == null:
					continue
				if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
					continue
				payload.append(be)

		if payload.is_empty():
			continue

		var slot_t := float(4 + i) * beat_sec
		var cluster_kind := int(cluster[0].get("action_kind", primary_kind))
		var a_follow := _make_phase_action(
			DirectorAction.Phase.FOLLOWTHROUGH,
			cluster_kind,
			slot_t,
			beat_sec,
			payload,
			"follow_%d" % i
		)
		a_follow.event = _make_followthrough_event_from_unit(cluster[0])
		actions.append(a_follow)

	var resolve_payload: Array = []
	for unit in action_units:
		var unit_events: Array = unit.get("events", [])
		for e in unit_events:
			var be := e as BattleEvent
			if be == null:
				continue
			if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
				resolve_payload.append(be)

	var a_resolve := _make_phase_action(
		DirectorAction.Phase.RESOLVE,
		_resolve_kind(resolve_payload, primary_kind),
		float(total_beats - 1) * beat_sec,
		beat_sec,
		resolve_payload,
		"resolve"
	)
	a_resolve.event = _make_resolve_event(resolve_payload, primary_kind)
	actions.append(a_resolve)

	plan.actions = actions


func _make_phase_action(
	phase: int,
	action_kind: int,
	t_rel_sec: float,
	duration_sec: float,
	payload: Array,
	label: String
) -> DirectorAction:
	var a := DirectorAction.new()
	a.phase = phase
	a.action_kind = action_kind
	a.t_rel_sec = t_rel_sec
	a.duration_sec = duration_sec
	a.payload = payload
	a.label = label
	return a


func _unit_quarters_for_speed(speed_mode: int) -> float:
	match speed_mode:
		1:
			return 4.0
		2:
			return 2.0
		4:
			return 1.0
		_:
			return 4.0


func _measures_for_action_units(n_units: int, action_units: Array[Dictionary]) -> int:
	var has_death := false
	for unit in action_units:
		if bool(unit.get("has_death", false)):
			has_death = true
			break

	if n_units <= 3:
		return 1
	if n_units <= 6 and has_death:
		return 2
	if n_units <= 6:
		return 2
	if n_units <= 9:
		return 3
	return 4


func _extract_action_units(turn_events: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var current: Dictionary = {}

	for e in turn_events:
		var be := e as BattleEvent
		if be == null:
			continue

		var t := int(be.type)

		if t == BattleEvent.Type.SCOPE_BEGIN \
		or t == BattleEvent.Type.SCOPE_END \
		or t == BattleEvent.Type.ACTOR_BEGIN \
		or t == BattleEvent.Type.ACTOR_END:
			continue

		if t == BattleEvent.Type.STRIKE or t == BattleEvent.Type.SUMMONED:
			if !current.is_empty():
				out.append(current)
			current = {
				"marker": be,
				"events": [be],
				"action_kind": _action_kind_for_marker(be),
				"has_death": false,
			}
			continue

		if current.is_empty():
			continue

		if t == BattleEvent.Type.DAMAGE_APPLIED \
		or t == BattleEvent.Type.STATUS \
		or t == BattleEvent.Type.SET_INTENT \
		or t == BattleEvent.Type.TURN_STATUS \
		or t == BattleEvent.Type.MOVED \
		or t == BattleEvent.Type.DIED \
		or t == BattleEvent.Type.FADED:
			var arr: Array = current.get("events", [])
			arr.append(be)
			current["events"] = arr

			if t == BattleEvent.Type.DIED or t == BattleEvent.Type.FADED:
				current["has_death"] = true

	if !current.is_empty():
		out.append(current)

	return out


func _action_kind_for_marker(e: BattleEvent) -> int:
	if e == null:
		return DirectorAction.ActionKind.GENERIC

	match int(e.type):
		BattleEvent.Type.SUMMONED:
			return DirectorAction.ActionKind.SUMMON
		BattleEvent.Type.STATUS:
			return DirectorAction.ActionKind.STATUS
		BattleEvent.Type.STRIKE:
			var mode := int(e.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) if e.data != null else Attack.Mode.MELEE
			if mode == int(Attack.Mode.RANGED):
				return DirectorAction.ActionKind.RANGED_STRIKE
			return DirectorAction.ActionKind.MELEE_STRIKE
		_:
			return DirectorAction.ActionKind.GENERIC


func _cluster_units(action_units: Array[Dictionary], slots: int) -> Array:
	var out: Array = []
	out.resize(slots)
	for i in range(slots):
		out[i] = []

	if slots <= 0:
		return out

	for i in range(action_units.size()):
		var idx := clampi(i, 0, slots - 1)
		var bucket: Array = out[idx]
		bucket.append(action_units[i])
		out[idx] = bucket

	return out


func _resolve_kind(resolve_payload: Array, fallback_kind: int) -> int:
	for e in resolve_payload:
		var be := e as BattleEvent
		if be == null:
			continue
		if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
			return DirectorAction.ActionKind.DEATH
	return fallback_kind


func _make_focus_event_from_payload(primary_kind: int, payload: Array) -> BattleEvent:
	var src := 0
	var target_ids: Array[int] = []

	for e in payload:
		var be := e as BattleEvent
		if be == null or be.data == null:
			continue

		if src == 0:
			if be.data.has(Keys.SOURCE_ID):
				src = int(be.data[Keys.SOURCE_ID])
			elif be.data.has(Keys.ACTOR_ID):
				src = int(be.data[Keys.ACTOR_ID])

		if target_ids.is_empty() and be.data.has(Keys.TARGET_IDS):
			var raw: Array = be.data[Keys.TARGET_IDS]
			for tid in raw:
				target_ids.append(int(tid))

	var ev := BattleEvent.new(BattleEvent.Type.TARGETED)
	ev.data = {
		Keys.SOURCE_ID: src,
		Keys.TARGET_IDS: target_ids,
		Keys.PRIMARY_ACTION_KIND: primary_kind,
	}
	return ev


func _make_windup_event_from_unit(unit: Dictionary) -> BattleEvent:
	var marker: BattleEvent = unit.get("marker")
	if marker == null:
		return null

	var t := int(marker.type)
	var ev_type := BattleEvent.Type.TARGETED

	if t == BattleEvent.Type.STRIKE:
		ev_type = BattleEvent.Type.STRIKE
	elif t == BattleEvent.Type.SUMMONED:
		ev_type = BattleEvent.Type.SUMMONED
	elif t == BattleEvent.Type.STATUS:
		ev_type = BattleEvent.Type.STATUS

	var ev := BattleEvent.new(ev_type)
	ev.data = marker.data.duplicate(true) if marker.data != null else {}
	ev.data[Keys.PRIMARY_ACTION_KIND] = int(unit.get("action_kind", DirectorAction.ActionKind.GENERIC))
	return ev


func _make_followthrough_event_from_unit(unit: Dictionary) -> BattleEvent:
	var marker: BattleEvent = unit.get("marker")
	if marker == null:
		return null

	var ev := BattleEvent.new(int(marker.type))
	ev.data = marker.data.duplicate(true) if marker.data != null else {}
	ev.data[Keys.PRIMARY_ACTION_KIND] = int(unit.get("action_kind", DirectorAction.ActionKind.GENERIC))
	return ev


func _make_resolve_event(resolve_payload: Array, primary_kind: int) -> BattleEvent:
	for e in resolve_payload:
		var be := e as BattleEvent
		if be == null:
			continue
		if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
			return be

	var ev := BattleEvent.new(BattleEvent.Type.SCOPE_END)
	ev.data = {
		Keys.PRIMARY_ACTION_KIND: primary_kind,
	}
	return ev
