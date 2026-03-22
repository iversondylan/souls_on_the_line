# turn_timeline_compiler.gd
class_name TurnTimelineCompiler extends RefCounted

func compile_actor_turn(turn_events: Array[BattleEvent]) -> TurnTimeline:
	var timeline := TurnTimeline.new()
	if turn_events.is_empty():
		return timeline

	timeline.actor_id = _find_actor_id(turn_events)
	timeline.group_index = _find_group_index(turn_events)
	timeline.is_player = false

	if _is_attack_turn(turn_events):
		timeline.action_kind = &"attack"
		var analysis := _build_attack_analysis(turn_events)
		timeline.beats = _build_attack_beats(analysis, turn_events)
		return timeline

	if _is_summon_turn(turn_events):
		timeline.action_kind = &"summon"
		timeline.beats = _build_summon_beats(turn_events)
		return timeline

	if _is_status_turn(turn_events):
		timeline.action_kind = &"status"
		timeline.beats = _build_status_beats(turn_events)
		return timeline

	timeline.action_kind = &"generic"
	timeline.beats = _build_generic_beats(turn_events)
	return timeline


func _find_actor_id(events: Array[BattleEvent]) -> int:
	for e in events:
		if e == null:
			continue
		if int(e.type) == int(BattleEvent.Type.ACTOR_BEGIN):
			return int(e.data.get(Keys.ACTOR_ID, 0)) if e.data != null else 0
		if int(e.type) == int(BattleEvent.Type.SCOPE_BEGIN) and int(e.scope_kind) == int(Scope.Kind.ACTOR_TURN):
			return int(e.data.get(Keys.ACTOR_ID, 0)) if e.data != null else 0
	return 0


func _find_group_index(events: Array[BattleEvent]) -> int:
	for e in events:
		if e == null:
			continue
		if int(e.group_index) != -1:
			return int(e.group_index)
		if e.data != null and e.data.has(Keys.GROUP_INDEX):
			return int(e.data.get(Keys.GROUP_INDEX, -1))
	return -1


func _is_attack_turn(events: Array[BattleEvent]) -> bool:
	for e in events:
		if e == null:
			continue
		if int(e.type) == int(BattleEvent.Type.STRIKE):
			return true
	return false


func _is_summon_turn(events: Array[BattleEvent]) -> bool:
	var has_summon := false
	var has_strike := false
	for e in events:
		if e == null:
			continue
		if int(e.type) == int(BattleEvent.Type.SUMMONED):
			has_summon = true
		elif int(e.type) == int(BattleEvent.Type.STRIKE):
			has_strike = true
	return has_summon and !has_strike


func _is_status_turn(events: Array[BattleEvent]) -> bool:
	var has_status := false
	var has_strike := false
	var has_summon := false
	for e in events:
		if e == null:
			continue
		match int(e.type):
			BattleEvent.Type.STATUS:
				has_status = true
			BattleEvent.Type.STRIKE:
				has_strike = true
			BattleEvent.Type.SUMMONED:
				has_summon = true
	return has_status and !has_strike and !has_summon


func _collect_strike_blocks(events: Array[BattleEvent]) -> Array[Array]:
	var out: Array[Array] = []
	var current: Array = []

	for e in events:
		if e == null:
			continue

		if int(e.type) == int(BattleEvent.Type.STRIKE):
			if !current.is_empty():
				out.append(current)
			current = [e]
			continue

		if current.is_empty():
			continue

		current.append(e)

	if !current.is_empty():
		out.append(current)

	return out


func _build_attack_analysis(events: Array[BattleEvent]) -> AttackAnalysis:
	var analysis := AttackAnalysis.new()
	var blocks := _collect_strike_blocks(events)
	if blocks.is_empty():
		return analysis

	var first_strike: BattleEvent = blocks[0][0]
	analysis.attacker_id = int(first_strike.data.get(Keys.SOURCE_ID, 0)) if first_strike.data != null else 0
	analysis.attack_mode = int(first_strike.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) if first_strike.data != null else int(Attack.Mode.MELEE)
	analysis.strike_count = blocks.size()

	for i in range(blocks.size()):
		var strike_info := _build_strike_info_from_block(blocks[i], i)
		analysis.strikes.append(strike_info)
		if strike_info.has_lethal_hit:
			analysis.lethal_indices.append(i)

	return analysis


func _build_strike_info_from_block(block: Array, strike_index: int) -> StrikePresentationInfo:
	var s := StrikePresentationInfo.new()
	s.strike_index = strike_index

	if block.is_empty():
		return s

	var marker: BattleEvent = block[0]
	if marker != null and marker.data != null:
		if marker.data.has(Keys.TARGET_IDS):
			for tid in marker.data.get(Keys.TARGET_IDS, []):
				s.target_ids.append(int(tid))
		elif marker.data.has(Keys.TARGET_ID):
			var tid := int(marker.data.get(Keys.TARGET_ID, 0))
			if tid > 0:
				s.target_ids.append(tid)

	for i in range(1, block.size()):
		var e: BattleEvent = block[i]
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.DAMAGE_APPLIED:
				var h := HitPresentationInfo.new()
				h.target_id = int(e.data.get(Keys.TARGET_ID, 0)) if e.data != null else 0
				h.amount = int(e.data.get(Keys.FINAL_AMOUNT, 0)) if e.data != null else 0
				h.before_health = int(e.data.get(Keys.BEFORE_HEALTH, 0)) if e.data != null else 0
				h.after_health = int(e.data.get(Keys.AFTER_HEALTH, 0)) if e.data != null else 0
				h.was_lethal = bool(e.data.get(Keys.WAS_LETHAL, false)) if e.data != null else false
				s.hits.append(h)
				s.hit_count += 1
				if h.was_lethal:
					s.has_lethal_hit = true

			BattleEvent.Type.DIED:
				s.has_lethal_hit = true

	return s


func _build_attack_beats(analysis: AttackAnalysis, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	if analysis == null or analysis.strike_count <= 0:
		return _build_generic_beats(turn_events)

	if int(analysis.attack_mode) == int(Attack.Mode.RANGED):
		return _build_ranged_attack_beats(analysis, turn_events)

	return _build_melee_attack_beats(analysis, turn_events)


func _split_attack_events(events: Array[BattleEvent]) -> Dictionary:
	var by_strike: Array[Array] = []
	var trailing: Array[BattleEvent] = []
	var final_strike_events: Array[BattleEvent] = []

	var blocks := _collect_strike_blocks(events)
	for block in blocks:
		var arr: Array[BattleEvent] = []
		for i in range(1, block.size()):
			var e: BattleEvent = block[i]
			if e == null:
				continue
			match int(e.type):
				BattleEvent.Type.DAMAGE_APPLIED, \
				BattleEvent.Type.CHANGE_MAX_HEALTH, \
				BattleEvent.Type.STATUS, \
				BattleEvent.Type.DIED, \
				BattleEvent.Type.FADED:
					arr.append(e)
		by_strike.append(arr)

	for e in events:
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.SET_INTENT:
				final_strike_events.append(e)

			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(e)

	if !by_strike.is_empty() and !final_strike_events.is_empty():
		var last_i := by_strike.size() - 1
		for e in final_strike_events:
			by_strike[last_i].append(e)

	return {
		"by_strike": by_strike,
		"trailing": trailing,
	}


func _build_melee_attack_beats(analysis: AttackAnalysis, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_attack_events(turn_events)
	var by_strike: Array = split["by_strike"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var group_index := _find_group_index(turn_events)

	beats.append(_make_focus_beat(0.0, analysis))
	beats.append(_make_melee_windup_beat(1.0, analysis))

	var n := analysis.strike_count
	var start_q := 2.0
	if n >= 3:
		start_q = 2.5

	var lethal_shift_q := 0.0

	for i in range(n):
		var beat_q := start_q + 0.5 * float(i) + lethal_shift_q
		var strike_events: Array[BattleEvent] = by_strike[i] if i < by_strike.size() else []

		beats.append(_make_melee_strike_beat(
			beat_q,
			analysis,
			i,
			strike_events
		))

		if i < n - 1 and _strike_has_early_lethal(analysis, i):
			lethal_shift_q += 0.5

	var last_hit_q := start_q + 0.5 * float(n - 1) + lethal_shift_q
	var clear_q := last_hit_q + _tail_gap_q_for_attack(analysis)
	var layout_order := _find_post_action_group_layout(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, analysis.attacker_id, trailing, layout_order))

	return beats


func _tail_gap_q_for_attack(analysis: AttackAnalysis) -> float:
	if analysis == null or analysis.strike_count <= 1:
		return 1.0

	for i in range(analysis.strike_count - 1):
		if _strike_has_early_lethal(analysis, i):
			return 1.0

	return 0.5


func _strike_has_early_lethal(analysis: AttackAnalysis, strike_index: int) -> bool:
	if analysis == null:
		return false
	for i in analysis.lethal_indices:
		if int(i) == int(strike_index):
			return true
	return false


func _build_ranged_attack_beats(analysis: AttackAnalysis, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_attack_events(turn_events)
	var by_strike: Array = split["by_strike"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var group_index := _find_group_index(turn_events)

	beats.append(_make_focus_beat(0.0, analysis))
	beats.append(_make_ranged_windup_beat(1.0, analysis))

	var n := analysis.strike_count
	var fire_start_q := 1.5
	if n >= 3:
		fire_start_q = 2.0

	var lethal_shift_q := 0.0

	for i in range(n):
		var fire_q := fire_start_q + 0.5 * float(i) + lethal_shift_q
		var impact_q := fire_q + 0.5
		var strike_events: Array[BattleEvent] = by_strike[i] if i < by_strike.size() else []

		_add_order_to_beat_array(beats, fire_q, _make_ranged_fire_order(analysis, i))

		var impact_orders := _make_impact_orders_for_strike(analysis, i, strike_events)
		_add_orders_to_beat_array(beats, impact_q, impact_orders)
		_add_events_to_beat_array(beats, impact_q, strike_events)

		if i < n - 1 and _strike_has_early_lethal(analysis, i):
			lethal_shift_q += 0.5

	var last_impact_q := fire_start_q + 0.5 * float(n - 1) + lethal_shift_q + 0.5
	var clear_q := last_impact_q + _tail_gap_q_for_attack(analysis)
	var layout_order := _find_post_action_group_layout(turn_events, group_index)
	_add_beat_array_clear_focus(beats, clear_q, analysis.attacker_id, trailing, layout_order)

	return _sort_beats(beats)


func _make_focus_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "focus"

	var o := FocusPresentationOrder.new()
	o.kind = PresentationOrder.Kind.FOCUS
	o.actor_id = analysis.attacker_id
	o.target_ids = _collect_all_attack_targets(analysis)
	o.visual_sec = 0.35

	beat.orders.append(o)
	return beat


func _make_clear_focus_beat(
	beat_q: float,
	actor_id: int,
	trailing: Array[BattleEvent],
	layout_order: GroupLayoutPresentationOrder = null
) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "clear_focus"

	var o := ClearFocusPresentationOrder.new()
	o.kind = PresentationOrder.Kind.CLEAR_FOCUS
	o.actor_id = actor_id
	o.visual_sec = 0.30
	beat.orders.append(o)

	if layout_order != null:
		beat.orders.append(layout_order)

	for e in trailing:
		beat.events.append(e)

	return beat



func _make_melee_windup_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "melee_windup"

	var o := MeleeWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.MELEE_WINDUP
	o.actor_id = analysis.attacker_id
	o.target_ids = _collect_all_attack_targets(analysis)
	o.visual_sec = 0.20
	o.strike_count = analysis.strike_count
	o.total_hit_count = _count_total_hits(analysis)

	beat.orders.append(o)
	return beat


func _make_melee_strike_beat(
	beat_q: float,
	analysis: AttackAnalysis,
	strike_index: int,
	strike_events: Array[BattleEvent]
) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "melee_strike_%d" % strike_index

	var strike := analysis.strikes[strike_index]

	var o := MeleeStrikePresentationOrder.new()
	o.kind = PresentationOrder.Kind.MELEE_STRIKE
	o.actor_id = analysis.attacker_id
	o.target_ids = strike.target_ids
	o.visual_sec = 0.22
	o.strike_index = strike_index
	o.strikes_total = analysis.strike_count
	o.total_hit_count = strike.hit_count
	o.has_lethal = strike.has_lethal_hit
	beat.orders.append(o)

	for impact_order in _make_impact_orders_for_strike(analysis, strike_index, strike_events):
		beat.orders.append(impact_order)

	for e in strike_events:
		beat.events.append(e)

	return beat



func _make_ranged_windup_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "ranged_windup"

	var o := RangedWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.RANGED_WINDUP
	o.actor_id = analysis.attacker_id
	o.target_ids = _collect_all_attack_targets(analysis)
	o.visual_sec = 0.15
	o.strike_count = analysis.strike_count
	o.total_hit_count = _count_total_hits(analysis)

	beat.orders.append(o)
	return beat


func _make_ranged_fire_order(analysis: AttackAnalysis, strike_index: int) -> RangedFirePresentationOrder:
	var strike := analysis.strikes[strike_index]

	var o := RangedFirePresentationOrder.new()
	o.kind = PresentationOrder.Kind.RANGED_FIRE
	o.actor_id = analysis.attacker_id
	o.target_ids = strike.target_ids
	o.visual_sec = 0.18
	o.strike_index = strike_index
	o.strikes_total = analysis.strike_count
	o.total_hit_count = strike.hit_count
	o.has_lethal = strike.has_lethal_hit
	o.projectile_scene_path = "res://VFX/projectiles/fireball/fireball.tscn"

	return o


func _make_impact_orders_for_strike(
	analysis: AttackAnalysis,
	strike_index: int,
	strike_events: Array[BattleEvent] = []
) -> Array[PresentationOrder]:
	var out: Array[PresentationOrder] = []
	if strike_index < 0 or strike_index >= analysis.strikes.size():
		return out

	var strike := analysis.strikes[strike_index]

	for h in strike.hits:
		if h == null:
			continue

		var o := ImpactPresentationOrder.new()
		o.kind = PresentationOrder.Kind.IMPACT
		o.actor_id = analysis.attacker_id
		o.target_id = int(h.target_id)
		o.target_ids = [int(h.target_id)]
		o.visual_sec = 0.18
		o.strike_index = strike_index
		o.was_lethal = bool(h.was_lethal)
		o.amount = int(h.amount)
		o.after_health = int(h.after_health)
		out.append(o)

	for e in strike_events:
		if e == null or e.data == null:
			continue

		match int(e.type):
			BattleEvent.Type.DIED:
				var d := DeathPresentationOrder.new()
				d.kind = PresentationOrder.Kind.DEATH
				d.actor_id = analysis.attacker_id
				d.target_id = int(e.data.get(Keys.TARGET_ID, 0))
				d.group_index = int(e.data.get(Keys.GROUP_INDEX, e.group_index))
				d.after_order_ids = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
				d.visual_sec = 0.24
				out.append(d)

			BattleEvent.Type.FADED:
				var f := FadePresentationOrder.new()
				f.kind = PresentationOrder.Kind.FADE
				f.actor_id = analysis.attacker_id
				f.target_id = int(e.data.get(Keys.TARGET_ID, 0))
				f.group_index = int(e.data.get(Keys.GROUP_INDEX, e.group_index))
				f.after_order_ids = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
				f.visual_sec = 0.20
				out.append(f)

	return out


func _find_or_make_beat(beats: Array[TurnBeat], beat_q: float, label: String = "") -> TurnBeat:
	for b in beats:
		if b != null and is_equal_approx(b.beat_q, beat_q):
			if label != "" and b.label == "":
				b.label = label
			return b

	var b := TurnBeat.new()
	b.beat_q = beat_q
	b.label = label
	beats.append(b)
	return b


func _add_order_to_beat_array(beats: Array[TurnBeat], beat_q: float, order: PresentationOrder, label: String = "") -> void:
	var b := _find_or_make_beat(beats, beat_q, label)
	b.orders.append(order)


func _add_orders_to_beat_array(beats: Array[TurnBeat], beat_q: float, orders: Array[PresentationOrder], label: String = "") -> void:
	var b := _find_or_make_beat(beats, beat_q, label)
	for o in orders:
		b.orders.append(o)


func _add_events_to_beat_array(beats: Array[TurnBeat], beat_q: float, events: Array[BattleEvent], label: String = "") -> void:
	var b := _find_or_make_beat(beats, beat_q, label)
	for e in events:
		b.events.append(e)


func _add_beat_array_clear_focus(
	beats: Array[TurnBeat],
	beat_q: float,
	actor_id: int,
	trailing: Array[BattleEvent],
	layout_order: GroupLayoutPresentationOrder = null
) -> void:
	var b := _make_clear_focus_beat(beat_q, actor_id, trailing, layout_order)
	beats.append(b)


func _sort_beats(beats: Array[TurnBeat]) -> Array[TurnBeat]:
	beats.sort_custom(func(a, b): return a.beat_q < b.beat_q)
	return beats


func _collect_all_attack_targets(analysis: AttackAnalysis) -> Array[int]:
	var seen := {}
	var out: Array[int] = []

	for s in analysis.strikes:
		if s == null:
			continue
		for tid in s.target_ids:
			var k := int(tid)
			if seen.has(k):
				continue
			seen[k] = true
			out.append(k)

	return out


func _count_total_hits(analysis: AttackAnalysis) -> int:
	var n := 0
	for s in analysis.strikes:
		if s != null:
			n += int(s.hit_count)
	return maxi(n, 1)


func _build_generic_beats(events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var actor_id := _find_actor_id(events)
	var group_index := _find_group_index(events)

	var trailing: Array[BattleEvent] = []
	for e in events:
		if e == null:
			continue
		match int(e.type):
			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED, \
			BattleEvent.Type.STATUS, \
			BattleEvent.Type.SUMMONED:
				trailing.append(e)

	var layout_order := _find_post_action_group_layout(events, group_index)

	if actor_id > 0:
		beats.append(_make_basic_focus_beat(0.0, actor_id, _collect_targets_from_events(events)))
		beats.append(_make_clear_focus_beat(1.0, actor_id, trailing, layout_order))
	else:
		var b := TurnBeat.new()
		b.beat_q = 0.0
		b.label = "generic"

		if layout_order != null:
			b.orders.append(layout_order)

		for e in trailing:
			b.events.append(e)
		beats.append(b)

	return beats


func _split_summon_events(events: Array[BattleEvent]) -> Dictionary:
	var summon_events: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []

	for e in events:
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.SUMMONED:
				summon_events.append(e)

			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(e)

	return {
		"summon_events": summon_events,
		"trailing": trailing,
	}


func _split_status_events(events: Array[BattleEvent]) -> Dictionary:
	var status_events: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []

	for e in events:
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.STATUS:
				status_events.append(e)

			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(e)

	return {
		"status_events": status_events,
		"trailing": trailing,
	}


func _build_summon_beats(turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_summon_events(turn_events)
	var summon_events: Array[BattleEvent] = split["summon_events"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var actor_id := _find_actor_id(turn_events)
	var group_index := _find_group_index(turn_events)
	var layout_order := _find_post_action_group_layout(turn_events, group_index)

	if summon_events.is_empty():
		return _build_generic_beats(turn_events)

	beats.append(_make_basic_focus_beat(0.0, actor_id, _collect_targets_from_events(summon_events)))
	beats.append(_make_summon_windup_beat(1.0, actor_id, summon_events))
	beats.append(_make_summon_pop_beat(2.0, actor_id, summon_events))
	beats.append(_make_clear_focus_beat(3.0, actor_id, trailing, layout_order))

	return beats




func _build_status_beats(turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_status_events(turn_events)
	var status_events: Array[BattleEvent] = split["status_events"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var actor_id := _find_actor_id(turn_events)
	var group_index := _find_group_index(turn_events)
	var layout_order := _find_post_action_group_layout(turn_events, group_index)

	if status_events.is_empty():
		return _build_generic_beats(turn_events)

	var targets := _collect_targets_from_events(status_events)

	beats.append(_make_basic_focus_beat(0.0, actor_id, targets))
	beats.append(_make_status_windup_beat(1.0, actor_id, targets))
	beats.append(_make_status_pop_beat(2.0, actor_id, status_events))
	beats.append(_make_clear_focus_beat(3.0, actor_id, trailing, layout_order))

	return beats


func _make_basic_focus_beat(beat_q: float, actor_id: int, target_ids: Array[int]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "focus"

	var o := FocusPresentationOrder.new()
	o.kind = PresentationOrder.Kind.FOCUS
	o.actor_id = actor_id
	o.target_ids = target_ids
	o.visual_sec = 0.35

	beat.orders.append(o)
	return beat


func _collect_targets_from_events(events: Array[BattleEvent]) -> Array[int]:
	var seen := {}
	var out: Array[int] = []

	for e in events:
		if e == null or e.data == null:
			continue

		if e.data.has(Keys.TARGET_IDS):
			for tid in e.data.get(Keys.TARGET_IDS, []):
				var k := int(tid)
				if !seen.has(k) and k > 0:
					seen[k] = true
					out.append(k)
		elif e.data.has(Keys.TARGET_ID):
			var tid := int(e.data.get(Keys.TARGET_ID, 0))
			if tid > 0 and !seen.has(tid):
				seen[tid] = true
				out.append(tid)

	return out


func _make_summon_windup_beat(beat_q: float, actor_id: int, summon_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "summon_windup"

	for e in summon_events:
		if e == null or e.data == null:
			continue

		var o := SummonWindupPresentationOrder.new()
		o.kind = PresentationOrder.Kind.SUMMON_WINDUP
		o.actor_id = actor_id
		o.visual_sec = 0.18
		o.summoned_id = int(e.data.get(Keys.SUMMONED_ID, 0))
		o.group_index = int(e.data.get(Keys.GROUP_INDEX, -1))
		o.insert_index = int(e.data.get(Keys.INSERT_INDEX, -1))
		o.before_order_ids = e.data.get(Keys.BEFORE_ORDER_IDS, PackedInt32Array())
		o.summon_spec = e.data.get(Keys.SUMMON_SPEC, {}).duplicate(true)

		beat.orders.append(o)

	return beat


func _make_summon_pop_beat(beat_q: float, actor_id: int, summon_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "summon_pop"

	for e in summon_events:
		if e == null or e.data == null:
			continue

		var o := SummonPopPresentationOrder.new()
		o.kind = PresentationOrder.Kind.SUMMON_POP
		o.actor_id = actor_id
		o.visual_sec = 0.20
		o.summoned_id = int(e.data.get(Keys.SUMMONED_ID, 0))
		o.group_index = int(e.data.get(Keys.GROUP_INDEX, -1))
		o.insert_index = int(e.data.get(Keys.INSERT_INDEX, -1))
		o.after_order_ids = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
		o.summon_spec = e.data.get(Keys.SUMMON_SPEC, {}).duplicate(true)

		beat.orders.append(o)

	return beat


func _make_status_windup_beat(beat_q: float, actor_id: int, target_ids: Array[int]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "status_windup"

	var o := StatusWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.STATUS_WINDUP
	o.actor_id = actor_id
	o.target_ids = target_ids
	o.visual_sec = 0.16

	beat.orders.append(o)
	return beat


func _make_status_pop_beat(beat_q: float, actor_id: int, status_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "status_pop"

	for e in status_events:
		if e == null or e.data == null:
			continue

		var o := StatusPopPresentationOrder.new()
		o.kind = PresentationOrder.Kind.STATUS_POP
		o.actor_id = actor_id
		o.target_ids = _targets_for_single_event(e)
		o.visual_sec = 0.18
		o.source_id = int(e.data.get(Keys.SOURCE_ID, 0))
		o.target_id = int(e.data.get(Keys.TARGET_ID, 0))
		o.status_id = e.data.get(Keys.STATUS_ID, &"")
		o.op = int(e.data.get(Keys.OP, 0))
		o.intensity = int(e.data.get(Keys.AFTER_INTENSITY, e.data.get(Keys.INTENSITY, 0)))
		o.turns_duration = int(e.data.get(Keys.AFTER_DURATION, e.data.get(Keys.DURATION, 0)))

		beat.orders.append(o)
		beat.events.append(e)

	return beat


func _targets_for_single_event(e: BattleEvent) -> Array[int]:
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


func _find_post_action_group_layout(events: Array[BattleEvent], fallback_group_index: int) -> GroupLayoutPresentationOrder:
	var latest_group := -1
	var latest_order := PackedInt32Array()

	for e in events:
		if e == null or e.data == null:
			continue

		match int(e.type):
			BattleEvent.Type.SUMMONED, \
			BattleEvent.Type.DIED, \
			BattleEvent.Type.FADED, \
			BattleEvent.Type.MOVED:
				if e.data.has(Keys.AFTER_ORDER_IDS):
					latest_order = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
					latest_group = int(e.data.get(Keys.GROUP_INDEX, e.group_index))

	if latest_group == -1:
		latest_group = fallback_group_index

	if latest_group == -1 or latest_order.is_empty():
		return null

	var o := GroupLayoutPresentationOrder.new()
	o.kind = PresentationOrder.Kind.GROUP_LAYOUT
	o.group_index = latest_group
	o.order_ids = latest_order
	o.animate = true
	o.visual_sec = 0.12

	return o
