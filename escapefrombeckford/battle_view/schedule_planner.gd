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
	var attack_info: AttackPresentationInfo = null
	var action_timeline: ActionTimelinePresentationInfo = null

	if primary_kind == DirectorAction.ActionKind.MELEE_STRIKE \
	or primary_kind == DirectorAction.ActionKind.RANGED_STRIKE:
		attack_info = _build_attack_presentation_info(action_units, DirectorAction.Phase.FOLLOWTHROUGH)
	else:
		action_timeline = _build_action_timeline_presentation_info(action_units)

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

			# deaths now belong to followthrough, not resolve
			if int(be.type) == BattleEvent.Type.DIED or int(be.type) == BattleEvent.Type.FADED:
				follow_payload.append(be)
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
	a_focus.presentation = attack_info if attack_info != null else action_timeline

	var a_windup := _make_phase_action(
		DirectorAction.Phase.WINDUP,
		primary_kind,
		q,
		q,
		windup_payload,
		"windup"
	)
	a_windup.event = _make_windup_event_from_unit(action_units[0])
	a_windup.presentation = attack_info if attack_info != null else action_timeline

	var a_follow := _make_phase_action(
		DirectorAction.Phase.FOLLOWTHROUGH,
		primary_kind,
		2.0 * q,
		q,
		follow_payload,
		"followthrough"
	)
	a_follow.event = _make_followthrough_event_from_unit(action_units[0])
	a_follow.presentation = attack_info if attack_info != null else action_timeline

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
	var attack_info: AttackPresentationInfo = null
	var action_timeline: ActionTimelinePresentationInfo = null

	if primary_kind == DirectorAction.ActionKind.MELEE_STRIKE \
	or primary_kind == DirectorAction.ActionKind.RANGED_STRIKE:
		attack_info = _build_attack_presentation_info(action_units, DirectorAction.Phase.FOLLOWTHROUGH)
	else:
		action_timeline = _build_action_timeline_presentation_info(action_units)
	
	
	
	
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
	a_focus.presentation = attack_info if attack_info != null else action_timeline
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
	a_windup.presentation = attack_info if attack_info != null else action_timeline
	actions.append(a_windup)

	var follow_slots := total_beats - 5
	if follow_slots < 1:
		follow_slots = 1

	var resolve_payload: Array = []

	# deaths now stay in followthrough payload space
	var a_follow := _make_phase_action(
		DirectorAction.Phase.FOLLOWTHROUGH,
		primary_kind,
		4.0 * beat_sec,
		float(follow_slots) * beat_sec,
		[],
		"followthrough"
	)
	a_follow.event = _make_followthrough_event_from_unit(action_units[0])
	a_follow.presentation = attack_info if attack_info != null else action_timeline
	actions.append(a_follow)

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

		if t == BattleEvent.Type.STRIKE \
		or t == BattleEvent.Type.SUMMONED:
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

func _build_attack_presentation_info(action_units: Array[Dictionary], phase: int) -> AttackPresentationInfo:
	var info := AttackPresentationInfo.new()
	if action_units.is_empty():
		return info

	var first_marker: BattleEvent = action_units[0].get("marker")
	if first_marker == null or first_marker.data == null:
		return info

	info.attacker_id = int(first_marker.data.get(Keys.SOURCE_ID, first_marker.data.get(Keys.ACTOR_ID, 0)))
	info.attack_mode = int(first_marker.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	info.projectile_scene_path = String(first_marker.data.get(Keys.PROJECTILE_SCENE, ""))

	# If this is not actually a strike action, just return minimal info.
	if int(first_marker.type) != int(BattleEvent.Type.STRIKE):
		return info
	
	info.strike_count = action_units.size()

	var n := action_units.size()
	for i in range(n):
		var unit := action_units[i]
		var strike := _build_strike_presentation_info(unit)
		strike.strike_index = i

		var marker: BattleEvent = unit.get("marker")
		if marker != null and marker.data != null:
			if info.projectile_scene_path == "":
				info.projectile_scene_path = String(marker.data.get(Keys.PROJECTILE_SCENE, ""))

		var t0 := 0.0
		var t1 := 1.0
		if n > 0:
			t0 = float(i) / float(n)
			t1 = float(i + 1) / float(n)

		strike.t0_ratio = t0
		strike.t1_ratio = t1

		info.strikes.append(strike)
		info.total_hit_count += strike.hit_count
		if strike.has_lethal_hit:
			info.has_lethal_hit = true

	info.t0_ratio = 0.0
	info.t1_ratio = 1.0

	if info.projectile_scene_path == "" and int(info.attack_mode) == int(Attack.Mode.RANGED):
		info.projectile_scene_path = "res://VFX/projectiles/fireball/fireball.tscn"

	return info


func _build_strike_presentation_info(unit: Dictionary) -> StrikePresentationInfo:
	var out := StrikePresentationInfo.new()
	if unit.is_empty():
		return out

	var marker: BattleEvent = unit.get("marker")
	var events: Array = unit.get("events", [])

	if marker != null and marker.data != null:
		out.target_ids = []
		var raw_targets: Array = marker.data.get(Keys.TARGET_IDS, [])
		for tid in raw_targets:
			out.target_ids.append(int(tid))

	out.strike_index = 0 # caller may overwrite if desired

	var hits_by_target := {}

	for e in events:
		var be := e as BattleEvent
		if be == null:
			continue

		match int(be.type):
			BattleEvent.Type.DAMAGE_APPLIED:
				var h := HitPresentationInfo.new()
				h.target_id = int(be.data.get(Keys.TARGET_ID, 0))
				h.amount = int(be.data.get(Keys.FINAL_AMOUNT, be.data.get(Keys.AMOUNT, 0)))
				h.before_health = int(be.data.get(Keys.BEFORE_HEALTH, 0))
				h.after_health = int(be.data.get(Keys.AFTER_HEALTH, 0))
				h.was_lethal = bool(be.data.get(Keys.WAS_LETHAL, false))

				hits_by_target[h.target_id] = h
				out.hits.append(h)
				out.hit_count += 1

				if h.was_lethal:
					out.has_lethal_hit = true

			BattleEvent.Type.STATUS:
				var status_target := int(be.data.get(Keys.TARGET_ID, 0))
				if hits_by_target.has(status_target):
					var hit: HitPresentationInfo = hits_by_target[status_target]
					hit.status_events.append(be)

			BattleEvent.Type.DIED:
				var dead_id := int(be.data.get(Keys.TARGET_ID, 0))
				if hits_by_target.has(dead_id):
					var hit2: HitPresentationInfo = hits_by_target[dead_id]
					hit2.died_event = be
					hit2.was_lethal = true
					out.has_lethal_hit = true

			BattleEvent.Type.FADED:
				var faded_id := int(be.data.get(Keys.TARGET_ID, 0))
				if hits_by_target.has(faded_id):
					var hit3: HitPresentationInfo = hits_by_target[faded_id]
					hit3.faded_event = be
					hit3.was_lethal = true
					out.has_lethal_hit = true

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

func _build_action_timeline_presentation_info(action_units: Array[Dictionary]) -> ActionTimelinePresentationInfo:
	var info := ActionTimelinePresentationInfo.new()
	if action_units.is_empty():
		return info

	var first_marker: BattleEvent = action_units[0].get("marker")
	if first_marker != null and first_marker.data != null:
		info.actor_id = int(first_marker.data.get(Keys.SOURCE_ID, first_marker.data.get(Keys.ACTOR_ID, 0)))
		info.action_kind = int(action_units[0].get("action_kind", DirectorAction.ActionKind.GENERIC))

	var n := action_units.size()
	for i in range(n):
		var unit := action_units[i]
		var marker: BattleEvent = unit.get("marker")
		var events: Array = unit.get("events", [])

		var step := ActionStepPresentationInfo.new()
		step.marker = marker
		step.events = []

		if marker != null:
			step.step_kind = _action_kind_for_marker(marker)
			if marker.data != null:
				step.actor_id = int(marker.data.get(Keys.SOURCE_ID, marker.data.get(Keys.ACTOR_ID, 0)))
				step.target_ids = _extract_target_ids_from_event(marker)

		for e in events:
			var be := e as BattleEvent
			if be != null:
				step.events.append(be)

		if n > 0:
			step.t0_ratio = float(i) / float(n)
			step.t1_ratio = float(i + 1) / float(n)

		info.steps.append(step)

	return info


func _extract_target_ids_from_event(e: BattleEvent) -> Array[int]:
	var out: Array[int] = []
	if e == null or e.data == null:
		return out

	if e.data.has(Keys.TARGET_IDS):
		for tid in e.data.get(Keys.TARGET_IDS, []):
			out.append(int(tid))
	elif e.data.has(Keys.TARGET_ID):
		out.append(int(e.data.get(Keys.TARGET_ID, 0)))

	return out
