# schedule_planner.gd
class_name SchedulePlanner extends RefCounted

func make_npc_turn_plan(
	clock: BattleClock,
	turn_events: Array[BattleEvent],
	_speed_mode: int,
	start_sec: float
) -> SchedulePlan:
	var plan := SchedulePlan.new()
	plan.t_start = start_sec
	plan.actions = []

	if clock == null or turn_events.is_empty():
		plan.t_end = start_sec
		return plan

	var spq := clock.seconds_per_quarter()

	var action_units := _extract_action_units(turn_events)
	if action_units.is_empty():
		plan.t_end = start_sec
		return plan

	# For now: treat the first "primary" unit kind as the turn's scheduled content.
	# You can later extend this to multiple sequential actions (summon + attack + status).
	var primary_kind := _primary_action_kind(action_units)
	var presentation = _build_presentation_for_primary_kind(primary_kind, action_units)

	# Always: focus at q=0..1
	_add_action_q(plan, spq,
		DirectorAction.Phase.FOCUS,
		primary_kind,
		0.0, 1.0,
		turn_events,
		_make_focus_event_from_payload(primary_kind, turn_events),
		presentation,
		"focus"
	)

	var is_attack := (primary_kind == DirectorAction.ActionKind.MELEE_STRIKE
	or primary_kind == DirectorAction.ActionKind.RANGED_STRIKE)

	var atk := presentation as AttackPresentationInfo

	if is_attack and atk != null and int(atk.attack_mode) == int(Attack.Mode.RANGED):
		# ranged: don't schedule a generic windup at q=1
		# first windup will be scheduled at q=1.5+ by _schedule_ranged_attack
		pass
	else:
		# melee + non-attack keep the early windup
		_add_action_q(plan, spq,
			DirectorAction.Phase.WINDUP,
			primary_kind,
			1.0, 1.0,
			[action_units[0].get("marker")],
			_make_windup_event_from_unit(action_units[0]),
			presentation,
			"windup"
		)

	# Then: variable “hit beats” + resolve
	if primary_kind == DirectorAction.ActionKind.MELEE_STRIKE or primary_kind == DirectorAction.ActionKind.RANGED_STRIKE:
		_schedule_attack_beats(plan, spq, primary_kind, action_units, presentation)
	else:
		# Generic non-attack: just do a single follow + resolve.
		var follow_payload: Array = []
		var resolve_payload: Array = []
		_split_unit_events_into_follow_and_resolve(action_units, follow_payload, resolve_payload)

		_add_action_q(plan, spq,
			DirectorAction.Phase.FOLLOWTHROUGH,
			primary_kind,
			2.0, 1.0,
			follow_payload,
			_make_followthrough_event_from_unit(action_units[0]),
			presentation,
			"followthrough"
		)

		_add_action_q(plan, spq,
			DirectorAction.Phase.RESOLVE,
			_resolve_kind(resolve_payload, primary_kind),
			3.0, 1.0,
			resolve_payload,
			_make_resolve_event(resolve_payload, primary_kind),
			null,
			"resolve"
		)

	# Compute t_end from last action end
	var end_rel := 0.0
	for a in plan.actions:
		end_rel = maxf(end_rel, a.t_rel_sec + a.duration_sec)
	plan.t_end = plan.t_start + end_rel

	return plan


func _add_action_q(
	plan: SchedulePlan,
	spq: float,
	phase: int,
	action_kind: int,
	t_q: float,
	dur_q: float,
	payload: Array,
	ev: BattleEvent,
	presentation: RefCounted,
	label: String
) -> void:
	var a := DirectorAction.new()
	a.phase = phase
	a.action_kind = action_kind
	a.t_rel_sec = t_q * spq
	a.duration_sec = maxf(dur_q * spq, 0.0)
	a.payload = payload
	a.event = ev
	a.presentation = presentation
	a.label = label
	plan.actions.append(a)


func _schedule_attack_beats(
	plan: SchedulePlan,
	spq: float,
	primary_kind: int,
	action_units: Array[Dictionary],
	presentation: RefCounted
) -> void:
	var atk := presentation as AttackPresentationInfo
	if atk == null:
		return

	var n := maxi(1, atk.strike_count)

	# Determine if there is a lethal hit before the last strike (retarget / corpse beat)
	var lethal_before_last := false
	for i in range(mini(n - 1, atk.strikes.size())):
		var s := atk.strikes[i]
		if s != null and bool(s.has_lethal_hit):
			lethal_before_last = true
			break

	var tail_gap_q := 0.5
	if n == 1 or lethal_before_last:
		tail_gap_q = 1.0

	if int(atk.attack_mode) == int(Attack.Mode.RANGED):
		_schedule_ranged_attack(plan, spq, primary_kind, action_units, atk, tail_gap_q)
	else:
		_schedule_melee_attack(plan, spq, primary_kind, action_units, atk, tail_gap_q)


func _schedule_melee_attack(
	plan: SchedulePlan,
	spq: float,
	primary_kind: int,
	action_units: Array[Dictionary],
	atk: AttackPresentationInfo,
	tail_gap_q: float
) -> void:
	var n := maxi(1, atk.strike_count)

	# Your rule: 1 strike uses full-quarter followthrough.
	# Multi-strike uses half-quarter slices.
	var follow_dur_q := 1.0 if n == 1 else 0.5

	var start_follow_q := 2.0 + 0.5 * float(int(floor(float(n - 1) / 2.0)))
	var dead_shift_q := 0.0
	var last_hit_q := start_follow_q

	for i in range(n):
		var t_hit_q := start_follow_q + 0.5 * float(i) + dead_shift_q
		last_hit_q = t_hit_q

		var unit_events: Array = []
		if i < action_units.size():
			unit_events = action_units[i].get("events", [])

		var slice := StrikeFollowthroughSlice.new()
		slice.attack = atk
		slice.strike_index = i
		if i < atk.strikes.size():
			slice.strike = atk.strikes[i]

		_add_action_q(plan, spq,
			DirectorAction.Phase.FOLLOWTHROUGH,
			primary_kind,
			t_hit_q,
			follow_dur_q,
			unit_events,
			_make_followthrough_event_from_unit(action_units[min(i, action_units.size() - 1)]),
			slice,
			"hit_%d" % i
		)

		# If this strike was lethal and there are more strikes, insert a corpse/retarget half-beat.
		if i < n - 1 and i < atk.strikes.size():
			var s := atk.strikes[i]
			if s != null and bool(s.has_lethal_hit):
				dead_shift_q += 0.5

	# Resolve start: your tail-gap rule stays, BUT resolve itself is always 1.0q.
	var t_resolve_q := last_hit_q + tail_gap_q

	var follow_payload: Array = []
	var resolve_payload: Array = []
	_split_unit_events_into_follow_and_resolve(action_units, follow_payload, resolve_payload)

	_add_action_q(plan, spq,
		DirectorAction.Phase.RESOLVE,
		_resolve_kind(resolve_payload, primary_kind),
		t_resolve_q,
		1.0, # <-- always a full quarter
		resolve_payload,
		_make_resolve_event(resolve_payload, primary_kind),
		null,
		"resolve"
	)


func _schedule_ranged_attack(
	plan: SchedulePlan,
	spq: float,
	primary_kind: int,
	action_units: Array[Dictionary],
	atk: AttackPresentationInfo,
	tail_gap_q: float
) -> void:
	var n := maxi(1, atk.strike_count)

	# Fire beats are half-quarter.
	var fire_dur_q := 0.5
	# Impact beat is full-quarter for single-shot, half-quarter for multi.
	var impact_dur_q := 1.0 if n == 1 else 0.5

	var start_fire_q := 1.5 + 0.5 * float(int(floor(float(n - 1) / 2.0)))
	var dead_shift_q := 0.0

	var last_impact_q := start_fire_q + 0.5

	for i in range(n):
		var t_fire_q := start_fire_q + 0.5 * float(i) + dead_shift_q
		var t_impact_q := t_fire_q + 0.5
		last_impact_q = t_impact_q

		var slice := StrikeFollowthroughSlice.new()
		slice.attack = atk
		slice.strike_index = i
		if i < atk.strikes.size():
			slice.strike = atk.strikes[i]

		# FIRE: WINDUP beat (spawns projectile for this strike_index)
		_add_action_q(plan, spq,
			DirectorAction.Phase.WINDUP,
			primary_kind,
			t_fire_q,
			fire_dur_q,
			[],
			null,
			slice,
			"fire_%d" % i
		)

		# IMPACT: FOLLOWTHROUGH beat (projectile impact + hit reactions for this strike)
		var unit_events: Array = []
		if i < action_units.size():
			unit_events = action_units[i].get("events", [])

		_add_action_q(plan, spq,
			DirectorAction.Phase.FOLLOWTHROUGH,
			primary_kind,
			t_impact_q,
			impact_dur_q,
			unit_events,
			null,
			slice,
			"impact_%d" % i
		)

		# Lethal before last => insert corpse/retarget half-beat.
		if i < n - 1 and i < atk.strikes.size():
			var s := atk.strikes[i]
			if s != null and bool(s.has_lethal_hit):
				dead_shift_q += 0.5

	var t_resolve_q := last_impact_q + tail_gap_q

	var follow_payload: Array = []
	var resolve_payload: Array = []
	_split_unit_events_into_follow_and_resolve(action_units, follow_payload, resolve_payload)

	_add_action_q(plan, spq,
		DirectorAction.Phase.RESOLVE,
		_resolve_kind(resolve_payload, primary_kind),
		t_resolve_q,
		1.0, # <-- always a full quarter
		resolve_payload,
		_make_resolve_event(resolve_payload, primary_kind),
		null,
		"resolve"
	)

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

		# NEW:
		# Attach loose post-action events (like STATUS remove / SET_INTENT replan)
		# to the most recent action unit.
		if !out.is_empty() and _belongs_to_current_action_unit(e):
			var last_idx := out.size() - 1
			var unit: Dictionary = out[last_idx]
			var events: Array = unit.get("events", [])

			events.append(e)
			unit["events"] = events

			var t := int(e.type)
			if t == BattleEvent.Type.DIED or t == BattleEvent.Type.FADED:
				unit["has_death"] = true

			out[last_idx] = unit
			i += 1
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
	
