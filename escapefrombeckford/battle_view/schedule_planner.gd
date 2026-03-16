# schedule_planner.gd
class_name SchedulePlanner extends RefCounted

# ------------------------------------------------------------------------------
# Purpose
# ------------------------------------------------------------------------------
# Converts one resolved NPC actor turn into a SchedulePlan.
#
# Upstream responsibility is intentionally narrow:
# - decide WHICH beat each phase starts on
# - decide HOW MANY beats each phase owns
#
# Consumers own all intra-phase feel.
# ------------------------------------------------------------------------------

var beats_per_bar: int = 4


# ------------------------------------------------------------------------------
# Public entry point
# ------------------------------------------------------------------------------

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


# ------------------------------------------------------------------------------
# Plan builders
# ------------------------------------------------------------------------------

func _build_one_measure_plan(
	plan: SchedulePlan,
	turn_events: Array[BattleEvent],
	action_units: Array[Dictionary],
	total_sec: float
) -> void:
	var q := total_sec / 4.0
	var primary_kind := _primary_action_kind(action_units)
	var presentation = _build_presentation_for_primary_kind(primary_kind, action_units)

	var focus_payload: Array = turn_events
	var windup_payload: Array = [action_units[0].get("marker")]
	var follow_payload: Array = []
	var resolve_payload: Array = []

	_split_unit_events_into_follow_and_resolve(
		action_units,
		follow_payload,
		resolve_payload
	)

	var a_focus := _make_phase_action(
		DirectorAction.Phase.FOCUS,
		primary_kind,
		0.0,
		q,
		focus_payload,
		"focus"
	)
	a_focus.event = _make_focus_event_from_payload(primary_kind, focus_payload)
	a_focus.presentation = presentation

	var a_windup := _make_phase_action(
		DirectorAction.Phase.WINDUP,
		primary_kind,
		q,
		q,
		windup_payload,
		"windup"
	)
	a_windup.event = _make_windup_event_from_unit(action_units[0])
	a_windup.presentation = presentation

	var a_follow := _make_phase_action(
		DirectorAction.Phase.FOLLOWTHROUGH,
		primary_kind,
		2.0 * q,
		q,
		follow_payload,
		"followthrough"
	)
	a_follow.event = _make_followthrough_event_from_unit(action_units[0])
	a_follow.presentation = presentation

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
	var total_beats := measures * beats_per_bar
	var beat_sec := total_sec / float(total_beats)
	var primary_kind := _primary_action_kind(action_units)
	var presentation = _build_presentation_for_primary_kind(primary_kind, action_units)

	var follow_payload: Array = []
	var resolve_payload: Array = []
	_split_unit_events_into_follow_and_resolve(
		action_units,
		follow_payload,
		resolve_payload
	)

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
	a_focus.presentation = presentation
	actions.append(a_focus)

	# strict simplification:
	# extra beats go into windup
	var windup_beats := maxi(1, total_beats - 3)

	var a_windup := _make_phase_action(
		DirectorAction.Phase.WINDUP,
		primary_kind,
		beat_sec,
		float(windup_beats) * beat_sec,
		[action_units[0].get("marker")],
		"windup"
	)
	a_windup.event = _make_windup_event_from_unit(action_units[0])
	a_windup.presentation = presentation
	actions.append(a_windup)

	var a_follow := _make_phase_action(
		DirectorAction.Phase.FOLLOWTHROUGH,
		primary_kind,
		float(1 + windup_beats) * beat_sec,
		beat_sec,
		follow_payload,
		"followthrough"
	)
	a_follow.event = _make_followthrough_event_from_unit(action_units[0])
	a_follow.presentation = presentation
	actions.append(a_follow)

	var a_resolve := _make_phase_action(
		DirectorAction.Phase.RESOLVE,
		_resolve_kind(resolve_payload, primary_kind),
		float(2 + windup_beats) * beat_sec,
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


# ------------------------------------------------------------------------------
# Timing heuristics
# ------------------------------------------------------------------------------

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


func _primary_action_kind(action_units: Array[Dictionary]) -> int:
	if action_units.is_empty():
		return DirectorAction.ActionKind.GENERIC
	return int(action_units[0].get("action_kind", DirectorAction.ActionKind.GENERIC))


# ------------------------------------------------------------------------------
# Action unit extraction
# ------------------------------------------------------------------------------

func _extract_action_units(turn_events: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	var i := 0
	while i < turn_events.size():
		var e := turn_events[i] as BattleEvent
		if e == null:
			i += 1
			continue

		if _is_action_scope_begin(e):
			var scope_events: Array[BattleEvent] = []
			i = _collect_scope_events(turn_events, i, scope_events)

			var units := _build_action_units_from_scope(scope_events)
			for unit in units:
				if !unit.is_empty():
					out.append(unit)
			continue

		i += 1

	if out.is_empty():
		return _extract_action_units_legacy(turn_events)

	return out

func _build_action_units_from_scope(scope_events: Array[BattleEvent]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	if scope_events.is_empty():
		return out

	var root := scope_events[0]
	if root == null:
		return out

	var scope_kind := int(root.scope_kind)

	match scope_kind:
		Scope.Kind.ATTACK:
			return _build_attack_units_from_scope(scope_events)

		Scope.Kind.SUMMON_ACTION, Scope.Kind.STATUS_ACTION:
			var unit := _build_single_action_unit_from_scope(scope_events)
			if !unit.is_empty():
				out.append(unit)
			return out

		_:
			var fallback_unit := _build_single_action_unit_from_scope(scope_events)
			if !fallback_unit.is_empty():
				out.append(fallback_unit)
			return out

func _is_action_scope_begin(e: BattleEvent) -> bool:
	if e == null:
		return false
	if int(e.type) != int(BattleEvent.Type.SCOPE_BEGIN):
		return false

	match int(e.scope_kind):
		Scope.Kind.ATTACK, Scope.Kind.SUMMON_ACTION, Scope.Kind.STATUS_ACTION:
			return true
		_:
			return false


func _collect_scope_events(
	turn_events: Array,
	start_index: int,
	out_scope_events: Array[BattleEvent]
) -> int:
	var root := turn_events[start_index] as BattleEvent
	if root == null:
		return start_index + 1

	var depth := 0
	var i := start_index

	while i < turn_events.size():
		var e := turn_events[i] as BattleEvent
		i += 1

		if e == null:
			continue

		out_scope_events.append(e)

		if int(e.type) == int(BattleEvent.Type.SCOPE_BEGIN):
			depth += 1
		elif int(e.type) == int(BattleEvent.Type.SCOPE_END):
			depth -= 1
			if depth <= 0:
				break

	return i

func _build_attack_units_from_scope(scope_events: Array[BattleEvent]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	var i := 0
	while i < scope_events.size():
		var e := scope_events[i] as BattleEvent
		if e == null:
			i += 1
			continue

		var is_strike_scope_begin := (
			int(e.type) == int(BattleEvent.Type.SCOPE_BEGIN)
			and int(e.scope_kind) == int(Scope.Kind.STRIKE)
		)

		if !is_strike_scope_begin:
			i += 1
			continue

		var strike_scope_events: Array[BattleEvent] = []
		i = _collect_scope_events(scope_events, i, strike_scope_events)

		var unit := _build_strike_unit_from_scope(strike_scope_events)
		if !unit.is_empty():
			out.append(unit)

	return out

func _build_strike_unit_from_scope(scope_events: Array[BattleEvent]) -> Dictionary:
	var unit := {}
	if scope_events.is_empty():
		return unit

	var marker: BattleEvent = null
	var has_death := false
	var events: Array = []

	for e in scope_events:
		var be := e as BattleEvent
		if be == null:
			continue
		
		if int(be.type) == int(BattleEvent.Type.STRIKE):
			marker = be
		
		if int(be.type) == int(BattleEvent.Type.SCOPE_BEGIN) or int(be.type) == int(BattleEvent.Type.SCOPE_END):
			continue
		if int(be.type) == int(BattleEvent.Type.ACTOR_BEGIN) or int(be.type) == int(BattleEvent.Type.ACTOR_END):
			continue
		
		events.append(be)
		
		if int(be.type) == int(BattleEvent.Type.DIED) or int(be.type) == int(BattleEvent.Type.FADED):
			has_death = true
	
	if marker == null:
		return unit

	unit["marker"] = marker
	unit["events"] = events
	unit["action_kind"] = _action_kind_for_marker(marker)
	unit["has_death"] = has_death
	unit["scope_kind"] = int(Scope.Kind.STRIKE)

	return unit

func _build_single_action_unit_from_scope(scope_events: Array[BattleEvent]) -> Dictionary:
	var unit := {}

	if scope_events.is_empty():
		return unit

	var root := scope_events[0]
	if root == null:
		return unit

	var marker := _find_primary_marker_in_scope(scope_events, int(root.scope_kind))
	if marker == null:
		return unit

	var action_kind := _action_kind_for_scope_or_marker(int(root.scope_kind), marker)
	var has_death := false
	var events: Array = []

	for e in scope_events:
		var be := e as BattleEvent
		if be == null:
			continue

		if int(be.type) == int(BattleEvent.Type.SCOPE_BEGIN) or int(be.type) == int(BattleEvent.Type.SCOPE_END):
			continue
		if int(be.type) == int(BattleEvent.Type.ACTOR_BEGIN) or int(be.type) == int(BattleEvent.Type.ACTOR_END):
			continue

		events.append(be)

		if int(be.type) == int(BattleEvent.Type.DIED) or int(be.type) == int(BattleEvent.Type.FADED):
			has_death = true

	unit["marker"] = marker
	unit["events"] = events
	unit["action_kind"] = action_kind
	unit["has_death"] = has_death
	unit["scope_kind"] = int(root.scope_kind)

	return unit


func _find_primary_marker_in_scope(scope_events: Array[BattleEvent], scope_kind: int) -> BattleEvent:
	match scope_kind:
		Scope.Kind.ATTACK:
			for e in scope_events:
				if e != null and int(e.type) == int(BattleEvent.Type.STRIKE):
					return e

		Scope.Kind.SUMMON_ACTION:
			for e in scope_events:
				if e != null and int(e.type) == int(BattleEvent.Type.SUMMONED):
					return e

		Scope.Kind.STATUS_ACTION:
			for e in scope_events:
				if e != null and int(e.type) == int(BattleEvent.Type.STATUS):
					return e

		_:
			pass

	for e in scope_events:
		if e == null:
			continue
		if int(e.type) == int(BattleEvent.Type.SCOPE_BEGIN) or int(e.type) == int(BattleEvent.Type.SCOPE_END):
			continue
		return e

	return null


func _extract_action_units_legacy(turn_events: Array) -> Array[Dictionary]:
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
		or t == BattleEvent.Type.SUMMONED \
		or t == BattleEvent.Type.STATUS:
			if !current.is_empty():
				out.append(current)

			current = {
				"marker": be,
				"events": [be],
				"action_kind": _action_kind_for_marker(be),
				"has_death": false,
				"scope_kind": -1,
			}
			continue

		if current.is_empty():
			continue

		if _belongs_to_current_action_unit(be):
			var arr: Array = current.get("events", [])
			arr.append(be)
			current["events"] = arr

			if t == BattleEvent.Type.DIED or t == BattleEvent.Type.FADED:
				current["has_death"] = true

	if !current.is_empty():
		out.append(current)

	return out


func _belongs_to_current_action_unit(be: BattleEvent) -> bool:
	if be == null:
		return false

	match int(be.type):
		BattleEvent.Type.DAMAGE_APPLIED, \
		BattleEvent.Type.STATUS, \
		BattleEvent.Type.SET_INTENT, \
		BattleEvent.Type.TURN_STATUS, \
		BattleEvent.Type.MOVED, \
		BattleEvent.Type.DIED, \
		BattleEvent.Type.FADED:
			return true
		_:
			return false


func _split_unit_events_into_follow_and_resolve(
	action_units: Array[Dictionary],
	follow_payload: Array,
	resolve_payload: Array
) -> void:
	for unit in action_units:
		var unit_events: Array = unit.get("events", [])
		for e in unit_events:
			var be := e as BattleEvent
			if be == null:
				continue

			match int(be.type):
				BattleEvent.Type.DAMAGE_APPLIED, \
				BattleEvent.Type.SUMMONED, \
				BattleEvent.Type.STATUS:
					follow_payload.append(be)

				BattleEvent.Type.DIED, \
				BattleEvent.Type.FADED, \
				BattleEvent.Type.SET_INTENT, \
				BattleEvent.Type.TURN_STATUS, \
				BattleEvent.Type.MOVED:
					resolve_payload.append(be)

				BattleEvent.Type.SET_INTENT, \
				BattleEvent.Type.TURN_STATUS, \
				BattleEvent.Type.MOVED:
					resolve_payload.append(be)

				_:
					follow_payload.append(be)


# ------------------------------------------------------------------------------
# Presentation selection
# ------------------------------------------------------------------------------

func _build_presentation_for_primary_kind(primary_kind: int, action_units: Array[Dictionary]) -> Variant:
	if primary_kind == DirectorAction.ActionKind.MELEE_STRIKE \
	or primary_kind == DirectorAction.ActionKind.RANGED_STRIKE:
		return _build_attack_presentation_info(action_units)

	return _build_action_timeline_presentation_info(action_units)


# ------------------------------------------------------------------------------
# Attack presentation
# ------------------------------------------------------------------------------

func _build_attack_presentation_info(action_units: Array[Dictionary]) -> AttackPresentationInfo:
	var info := AttackPresentationInfo.new()
	if action_units.is_empty():
		return info

	var first_marker: BattleEvent = action_units[0].get("marker")
	if first_marker == null or first_marker.data == null:
		return info

	info.attacker_id = _event_actor_or_source_id(first_marker)
	info.attack_mode = int(first_marker.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	info.projectile_scene_path = String(first_marker.data.get(Keys.PROJECTILE_SCENE, ""))

	if int(first_marker.type) != int(BattleEvent.Type.STRIKE):
		return info

	info.strike_count = action_units.size()

	for i in range(action_units.size()):
		var unit := action_units[i]
		var strike := _build_strike_presentation_info(unit)
		strike.strike_index = i

		var marker: BattleEvent = unit.get("marker")
		if marker != null and marker.data != null and info.projectile_scene_path == "":
			info.projectile_scene_path = String(marker.data.get(Keys.PROJECTILE_SCENE, ""))

		info.strikes.append(strike)
		info.total_hit_count += strike.hit_count
		if strike.has_lethal_hit:
			info.has_lethal_hit = true

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
		out.target_ids = _extract_target_ids_from_event(marker)

	out.strike_index = 0

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


# ------------------------------------------------------------------------------
# Generic action timeline presentation
# ------------------------------------------------------------------------------

func _build_action_timeline_presentation_info(action_units: Array[Dictionary]) -> ActionTimelinePresentationInfo:
	var info := ActionTimelinePresentationInfo.new()
	if action_units.is_empty():
		return info

	var first_marker: BattleEvent = action_units[0].get("marker")
	if first_marker != null and first_marker.data != null:
		info.actor_id = _event_actor_or_source_id(first_marker)
		info.action_kind = int(action_units[0].get("action_kind", DirectorAction.ActionKind.GENERIC))

	for unit in action_units:
		var marker: BattleEvent = unit.get("marker")
		var events: Array = unit.get("events", [])

		var step := ActionStepPresentationInfo.new()
		step.marker = marker
		step.events = []

		if marker != null:
			step.step_kind = int(unit.get("action_kind", DirectorAction.ActionKind.GENERIC))
			if marker.data != null:
				step.actor_id = _event_actor_or_source_id(marker)
				step.target_ids = _extract_target_ids_from_event(marker)

		for e in events:
			var be := e as BattleEvent
			if be != null:
				step.events.append(be)

		info.steps.append(step)

	return info


# ------------------------------------------------------------------------------
# Classification helpers
# ------------------------------------------------------------------------------

func _action_kind_for_scope_or_marker(scope_kind: int, marker: BattleEvent) -> int:
	match scope_kind:
		Scope.Kind.ATTACK:
			if marker != null and marker.data != null:
				var mode := int(marker.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
				if mode == int(Attack.Mode.RANGED):
					return DirectorAction.ActionKind.RANGED_STRIKE
			return DirectorAction.ActionKind.MELEE_STRIKE

		Scope.Kind.SUMMON_ACTION:
			return DirectorAction.ActionKind.SUMMON

		Scope.Kind.STATUS_ACTION:
			return DirectorAction.ActionKind.STATUS

		_:
			return _action_kind_for_marker(marker)


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


# ------------------------------------------------------------------------------
# Resolve / synthetic phase events
# ------------------------------------------------------------------------------

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
			src = _event_actor_or_source_id(be)

		if target_ids.is_empty():
			target_ids = _extract_target_ids_from_event(be)

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

	var ev_type := BattleEvent.Type.TARGETED
	match int(marker.type):
		BattleEvent.Type.STRIKE:
			ev_type = BattleEvent.Type.STRIKE
		BattleEvent.Type.SUMMONED:
			ev_type = BattleEvent.Type.SUMMONED
		BattleEvent.Type.STATUS:
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


# ------------------------------------------------------------------------------
# Event-data helpers
# ------------------------------------------------------------------------------

func _extract_target_ids_from_event(e: BattleEvent) -> Array[int]:
	var out: Array[int] = []
	if e == null or e.data == null:
		return out

	if e.data.has(Keys.TARGET_IDS):
		for tid in e.data.get(Keys.TARGET_IDS, []):
			out.append(int(tid))
	elif e.data.has(Keys.TARGET_ID):
		var tid := int(e.data.get(Keys.TARGET_ID, 0))
		if tid > 0:
			out.append(tid)

	return out


func _event_actor_or_source_id(e: BattleEvent) -> int:
	if e == null or e.data == null:
		return 0
	return int(e.data.get(Keys.SOURCE_ID, e.data.get(Keys.ACTOR_ID, 0)))
	
