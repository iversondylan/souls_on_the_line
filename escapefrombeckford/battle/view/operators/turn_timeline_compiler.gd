# turn_timeline_compiler.gd
class_name TurnTimelineCompiler extends RefCounted



class DelayedReactionNode extends RefCounted:
	var kind: StringName = &""
	var source_strike_index: int = -1
	var scope_id: int = 0
	var events: Array[BattleEvent] = []
	var nested_attack = null


class ParsedDirectStrike extends RefCounted:
	var strike_index: int = -1
	var target_ids: Array[int] = []
	var direct_events: Array[BattleEvent] = []
	var reactions: Array[DelayedReactionNode] = []
	var info: StrikePresentationInfo = null


class TargetWindow extends RefCounted:
	var target_ids: Array[int] = []
	var strikes: Array[ParsedDirectStrike] = []
	var window_span_beats: int = 1
	var retarget_from_previous: bool = false
	var base_q: float = 0.0


class ParsedNpcAttackTurn extends RefCounted:
	var actor_id: int = 0
	var group_index: int = -1
	var attack_mode: int = Attack.Mode.MELEE
	var projectile_scene_path: String = "uid://bxmhi3urqmpfh"
	var focus_target_ids: Array[int] = []
	var direct_strikes: Array[ParsedDirectStrike] = []
	var target_windows: Array[TargetWindow] = []
	var leading_events: Array[BattleEvent] = []
	var trailing_events: Array[BattleEvent] = []
	var analysis: AttackAnalysis = null


class TopLevelTurnSegment extends RefCounted:
	var kind: StringName = &""
	var sequence_kind: StringName = &""
	var scope_id: int = 0
	var scope_ids: Array[int] = []
	var scope_kind: int = -1
	var actor_id: int = 0
	var effect_package_index: int = -1
	var compact_to_previous: bool = false
	var events: Array[BattleEvent] = []
	var status_events: Array[BattleEvent] = []
	var summon_events: Array[BattleEvent] = []
	var heal_events: Array[BattleEvent] = []
	var move_events: Array[BattleEvent] = []
	var target_ids: Array[int] = []
	var summoned_ids: Array[int] = []
	var parsed_attack: ParsedNpcAttackTurn = null

func compile_actor_turn(turn_events: Array[BattleEvent]) -> TurnTimeline:
	var timeline := TurnTimeline.new()
	if turn_events.is_empty():
		return timeline

	timeline.actor_id = _find_actor_id(turn_events)
	timeline.group_index = _find_group_index(turn_events)
	timeline.is_player = false
	var beats: Array[TurnBeat] = []
	var packaged_turn := _build_scope_driven_package_turn(turn_events)

	if !packaged_turn.is_empty():
		timeline.action_kind = packaged_turn.get("action_kind", &"generic")
		beats = packaged_turn.get("beats", [])
	elif _is_attack_turn(turn_events):
		timeline.action_kind = &"attack"
		var parsed_scope_attack := _parse_scope_driven_attack_turn(turn_events)
		if parsed_scope_attack != null:
			beats = _build_scope_driven_attack_beats(parsed_scope_attack, turn_events)
		else:
			var parsed_attack := _parse_attack_turn(turn_events)
			if !parsed_attack.is_empty():
				beats = _build_attack_beats_from_parsed(parsed_attack, turn_events)
			else:
				var analysis := _build_attack_analysis(turn_events)
				beats = _build_attack_beats(analysis, turn_events)
	else:
		var mixed_scope_turn := _build_scope_mixed_nonattack_turn(turn_events)
		if !mixed_scope_turn.is_empty():
			timeline.action_kind = mixed_scope_turn.get("action_kind", &"generic")
			beats = mixed_scope_turn.get("beats", [])
		elif _is_summon_turn(turn_events):
			timeline.action_kind = &"summon"
			beats = _build_summon_beats(turn_events)
		elif _is_status_turn(turn_events):
			timeline.action_kind = &"status"
			beats = _build_status_beats(turn_events)
		else:
			timeline.action_kind = &"generic"
			beats = _build_generic_beats(turn_events)

	timeline.beats = _ensure_lossless_beats(timeline.action_kind, turn_events, beats)
	return timeline


func _build_scope_driven_package_turn(turn_events: Array[BattleEvent]) -> Dictionary:
	var actor_id := _find_actor_id(turn_events)
	if actor_id <= 0:
		return {}

	var scope_ranges := _build_scope_ranges(turn_events)
	if scope_ranges.is_empty():
		return {}

	var compiled_turn_scope_id := _find_compiled_turn_scope_id(turn_events, actor_id)
	if compiled_turn_scope_id <= 0:
		return {}

	var child_scope_ids := _find_direct_child_scope_ids(turn_events, compiled_turn_scope_id)
	if child_scope_ids.is_empty():
		return {}

	var segments := _parse_top_level_package_segments(turn_events, scope_ranges, compiled_turn_scope_id, child_scope_ids)
	if segments.is_empty():
		return {}

	var group_index := _find_group_index(turn_events)
	var external_events := _collect_top_level_package_external_events(turn_events, scope_ranges, compiled_turn_scope_id, child_scope_ids)
	var leading: Array[BattleEvent] = external_events.get("leading", [])
	var trailing: Array[BattleEvent] = external_events.get("trailing", [])
	var beats: Array[TurnBeat] = []
	var focus_targets := _collect_eventual_focus_targets_from_top_level_segments(segments)
	var focus_beat := _make_basic_focus_beat(0.0, actor_id, focus_targets)
	for event in leading:
		focus_beat.events.append(event)
	if !segments.is_empty() and StringName(segments[0].kind) == &"attack":
		for layout_order in _find_pre_attack_group_layouts(turn_events, group_index):
			focus_beat.orders.append(layout_order)
	beats.append(focus_beat)

	var current_q := 1.0
	var previous_followthrough_beat: TurnBeat = null
	var last_work_q := 0.0
	var action_kind: StringName = StringName(segments[0].kind)
	var has_attack := false

	for segment in segments:
		if segment == null:
			continue
		if segment.kind == &"attack":
			has_attack = true
			action_kind = &"attack"

		if segment.compact_to_previous and previous_followthrough_beat != null:
			_merge_compacted_segment_into_beat(previous_followthrough_beat, segment)
			continue

		match segment.kind:
			&"attack":
				var built := _build_scope_driven_attack_package_beats(
					segment.parsed_attack,
					turn_events,
					current_q
				)
				var attack_beats: Array[TurnBeat] = built.get("beats", [])
				for beat in attack_beats:
					beats.append(beat)
				previous_followthrough_beat = built.get("followthrough_beat", null)
				last_work_q = float(built.get("last_work_q", current_q))
				current_q = _next_on_grid_beat_after(last_work_q)
			&"summon":
				var summon_windup := _make_summon_windup_beat(current_q, actor_id, segment.summon_events)
				var summon_pop := _make_summon_pop_beat(current_q + 1.0, actor_id, segment.summon_events)
				_tag_beat(summon_windup, [&"windup"])
				_tag_beat(summon_pop, [&"followthrough"])
				beats.append(summon_windup)
				beats.append(summon_pop)
				previous_followthrough_beat = summon_pop
				last_work_q = current_q + 1.0
				current_q += 2.0
			_:
				var nonattack := _build_effect_sequence_package_beats(current_q, segment)
				var nonattack_beats: Array[TurnBeat] = nonattack.get("beats", [])
				for beat in nonattack_beats:
					beats.append(beat)
				previous_followthrough_beat = nonattack.get("followthrough_beat", null)
				last_work_q = float(nonattack.get("last_work_q", current_q + 1.0))
				current_q += 2.0

	var clear_q := maxi(current_q, _next_on_grid_beat_after(last_work_q))
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, actor_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, actor_id, trailing, layout_orders))
	if has_attack:
		action_kind = &"attack"
	return {
		"action_kind": action_kind,
		"beats": _sort_beats(beats),
	}


func _parse_top_level_package_segments(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	compiled_turn_scope_id: int,
	child_scope_ids: Array[int]
) -> Array[TopLevelTurnSegment]:
	var out: Array[TopLevelTurnSegment] = []
	var group_index := _find_group_index(events)
	var active_segment: TopLevelTurnSegment = null

	for scope_id in child_scope_ids:
		var segment := _build_top_level_package_segment(events, scope_ranges, int(scope_id), group_index)
		if segment == null:
			continue
		if _should_merge_top_level_package_segments(active_segment, segment):
			_merge_top_level_package_segments(active_segment, segment)
			continue
		active_segment = segment
		out.append(segment)

	return out


func _build_top_level_package_segment(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	scope_id: int,
	group_index: int
) -> TopLevelTurnSegment:
	var scope_range: Dictionary = scope_ranges.get(scope_id, {})
	var scope_kind := int(scope_range.get("kind", -1))
	if !_is_top_level_effect_package_scope_kind(scope_kind):
		return null

	var begin_idx := int(scope_range.get("begin", -1))
	var end_idx := int(scope_range.get("end", -1))
	if begin_idx < 0 or end_idx < 0 or end_idx <= begin_idx:
		return null

	var scope_data: Dictionary = scope_range.get("data", {})
	var segment := TopLevelTurnSegment.new()
	segment.scope_id = scope_id
	segment.scope_ids.append(scope_id)
	segment.scope_kind = scope_kind
	segment.actor_id = int(scope_range.get("actor_id", 0))
	segment.effect_package_index = int(scope_data.get(Keys.EFFECT_PACKAGE_INDEX, -1))
	segment.compact_to_previous = bool(scope_data.get(Keys.COMPACT_TO_PREVIOUS, false))
	segment.sequence_kind = _top_level_segment_sequence_kind(scope_kind, scope_data)
	segment.kind = segment.sequence_kind

	if scope_kind == int(Scope.Kind.ATTACK):
		segment.kind = &"attack"
		segment.parsed_attack = _parse_scope_driven_attack_scope(events, scope_ranges, scope_id, group_index)
		if segment.parsed_attack != null:
			segment.target_ids = segment.parsed_attack.focus_target_ids.duplicate()

	for idx in range(begin_idx + 1, end_idx):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		segment.events.append(event)

		match int(event.type):
			BattleEvent.Type.SUMMONED:
				segment.summon_events.append(event)
				var summoned_id := int(event.data.get(Keys.SUMMONED_ID, 0)) if event.data != null else 0
				if summoned_id > 0 and !segment.summoned_ids.has(summoned_id):
					segment.summoned_ids.append(summoned_id)
			BattleEvent.Type.STATUS, BattleEvent.Type.STATUS_CHANGED:
				segment.status_events.append(event)
			BattleEvent.Type.HEAL_APPLIED:
				segment.heal_events.append(event)
			BattleEvent.Type.MOVED:
				segment.move_events.append(event)

	if segment.target_ids.is_empty():
		segment.target_ids = _collect_targets_for_top_level_segment(segment, scope_data)
	return segment


func _should_merge_top_level_package_segments(
	left: TopLevelTurnSegment,
	right: TopLevelTurnSegment
) -> bool:
	if left == null or right == null:
		return false
	if int(left.effect_package_index) < 0 or int(right.effect_package_index) < 0:
		return false
	if int(left.effect_package_index) != int(right.effect_package_index):
		return false
	if int(left.actor_id) != int(right.actor_id):
		return false
	return true


func _merge_unique_events(target_arr: Array[BattleEvent], source_arr: Array[BattleEvent]) -> void:
	for event in source_arr:
		if event != null and !target_arr.has(event):
			target_arr.append(event)


func _merge_unique_ids(target_arr: Array[int], source_arr: Array[int]) -> void:
	var seen := {}
	for id in target_arr:
		seen[int(id)] = true
	for id in source_arr:
		var cid := int(id)
		if cid > 0 and !seen.has(cid):
			seen[cid] = true
			target_arr.append(cid)


func _merge_top_level_package_segments(target: TopLevelTurnSegment, source: TopLevelTurnSegment) -> void:
	if target == null or source == null:
		return

	for scope_id in source.scope_ids:
		if !target.scope_ids.has(int(scope_id)):
			target.scope_ids.append(int(scope_id))

	_merge_unique_events(target.events, source.events)
	_merge_unique_events(target.status_events, source.status_events)
	_merge_unique_events(target.summon_events, source.summon_events)
	_merge_unique_events(target.heal_events, source.heal_events)
	_merge_unique_events(target.move_events, source.move_events)

	_merge_unique_ids(target.target_ids, source.target_ids)
	_merge_unique_ids(target.summoned_ids, source.summoned_ids)

	if target.parsed_attack == null and source.parsed_attack != null:
		target.parsed_attack = source.parsed_attack
	if target.kind == &"":
		target.kind = source.kind
	if target.sequence_kind == &"":
		target.sequence_kind = source.sequence_kind


func _is_top_level_effect_package_scope_kind(scope_kind: int) -> bool:
	return scope_kind == int(Scope.Kind.ATTACK) \
		or scope_kind == int(Scope.Kind.SUMMON_ACTION) \
		or scope_kind == int(Scope.Kind.STATUS_ACTION) \
		or scope_kind == int(Scope.Kind.MOVE) \
		or scope_kind == int(Scope.Kind.HEAL_ACTION)


func _top_level_segment_sequence_kind(scope_kind: int, scope_data: Dictionary) -> StringName:
	var explicit_kind := StringName(scope_data.get(Keys.EFFECT_SEQUENCE_KIND, &""))
	if explicit_kind != &"":
		return explicit_kind
	match scope_kind:
		Scope.Kind.ATTACK:
			return &"attack"
		Scope.Kind.SUMMON_ACTION:
			return &"summon"
		Scope.Kind.STATUS_ACTION:
			return &"status"
		Scope.Kind.MOVE:
			return &"move"
		Scope.Kind.HEAL_ACTION:
			return &"heal"
		_:
			return &"generic"


func _collect_targets_for_top_level_segment(segment: TopLevelTurnSegment, scope_data: Dictionary) -> Array[int]:
	if segment == null:
		return []
	if segment.kind == &"summon":
		var summon_targets := _collect_targets_from_summon_events(segment.summon_events)
		if !summon_targets.is_empty():
			return summon_targets
	if !segment.events.is_empty():
		var event_targets := _collect_targets_from_events(segment.events)
		if !event_targets.is_empty():
			return event_targets

	var out: Array[int] = []
	var seen := {}
	if scope_data.has(Keys.TARGET_IDS):
		for tid in scope_data.get(Keys.TARGET_IDS, []):
			var cid := int(tid)
			if cid > 0 and !seen.has(cid):
				seen[cid] = true
				out.append(cid)
	elif int(scope_data.get(Keys.TARGET_ID, 0)) > 0:
		out.append(int(scope_data.get(Keys.TARGET_ID, 0)))

	if out.is_empty() and segment.kind == &"summon":
		for summoned_id in segment.summoned_ids:
			var cid := int(summoned_id)
			if cid > 0 and !seen.has(cid):
				seen[cid] = true
				out.append(cid)

	return out


func _collect_top_level_package_external_events(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	compiled_turn_scope_id: int,
	child_scope_ids: Array[int]
) -> Dictionary:
	var leading: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []
	var scope_range: Dictionary = scope_ranges.get(compiled_turn_scope_id, {})
	var begin_idx := int(scope_range.get("begin", -1))
	var end_idx := int(scope_range.get("end", -1))
	if begin_idx < 0 or end_idx < 0:
		return {
			"leading": leading,
			"trailing": trailing,
		}

	var first_child_begin := end_idx
	var last_child_end := begin_idx
	for child_scope_id in child_scope_ids:
		var child_range: Dictionary = scope_ranges.get(int(child_scope_id), {})
		first_child_begin = mini(first_child_begin, int(child_range.get("begin", end_idx)))
		last_child_end = maxi(last_child_end, int(child_range.get("end", begin_idx)))

	for idx in range(begin_idx + 1, first_child_begin):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		leading.append(event)

	for idx in range(last_child_end + 1, end_idx):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		trailing.append(event)

	return {
		"leading": leading,
		"trailing": trailing,
	}


func _collect_eventual_focus_targets_from_top_level_segments(segments: Array[TopLevelTurnSegment]) -> Array[int]:
	var out: Array[int] = []
	var seen := {}

	for segment in segments:
		if segment == null:
			continue
		if segment.kind == &"attack" and segment.parsed_attack != null:
			_append_unique_target_ids(out, seen, segment.parsed_attack.focus_target_ids)
			continue
		_append_unique_target_ids(out, seen, segment.target_ids)

	return out


func _build_scope_driven_attack_package_beats(
	parsed: ParsedNpcAttackTurn,
	turn_events: Array[BattleEvent],
	windup_q: float
) -> Dictionary:
	var beats: Array[TurnBeat] = []
	if parsed == null or parsed.analysis == null or parsed.direct_strikes.is_empty():
		return {
			"beats": beats,
			"last_work_q": windup_q,
			"followthrough_beat": null,
		}

	var windup_beat := _make_ranged_windup_beat(windup_q, parsed.analysis) if parsed.attack_mode == int(Attack.Mode.RANGED) else _make_melee_windup_beat(windup_q, parsed.analysis)
	_tag_beat(windup_beat, [&"windup"])
	beats.append(windup_beat)

	var next_window_base_q := windup_q + 1.0
	var last_work_q := windup_q
	var previous_direct_strike: ParsedDirectStrike = null
	var final_followthrough_beat: TurnBeat = windup_beat

	for window_index in range(parsed.target_windows.size()):
		var window := parsed.target_windows[window_index]
		if window == null or window.strikes.is_empty():
			continue

		window.base_q = next_window_base_q
		var segment_start := 0
		var local_base_q := window.base_q

		while segment_start < window.strikes.size():
			var segment_end := _find_reaction_segment_end(window.strikes, segment_start)
			var segment_count := segment_end - segment_start + 1
			var segment_span_beats := _window_span_beats(segment_count)
			var segment_shift_q := 0.5 * float(segment_span_beats - 1)

			for local_index in range(segment_count):
				var strike := window.strikes[segment_start + local_index]
				if strike == null:
					continue

				var impact_q := local_base_q + segment_shift_q + 0.5 * float(local_index)
				var is_window_start := segment_start == 0 and local_index == 0

				if parsed.attack_mode == int(Attack.Mode.RANGED):
					var fire_q := impact_q - 0.5
					if (
						strike.info != null
						and !strike.info.is_cleave
						and previous_direct_strike != null
						and previous_direct_strike.info != null
						and previous_direct_strike.info.is_cleave
					):
						fire_q += 0.001
						impact_q += 0.001
					_add_ranged_direct_strike_to_beats(beats, parsed.analysis, strike, fire_q, impact_q, is_window_start)
				else:
					_add_melee_direct_strike_to_beats(beats, parsed.analysis, strike, impact_q, is_window_start)

				last_work_q = maxf(last_work_q, impact_q)
				previous_direct_strike = strike
				final_followthrough_beat = _find_or_make_beat(beats, impact_q)

			var terminal_strike := window.strikes[segment_end]
			if terminal_strike != null and !terminal_strike.reactions.is_empty():
				var reaction_q := _next_on_grid_beat_after(last_work_q)
				for reaction in terminal_strike.reactions:
					var reaction_beat := _make_delayed_reaction_beat(reaction_q, reaction)
					beats.append(reaction_beat)
					last_work_q = reaction_q
					reaction_q += 1.0
				local_base_q = _next_on_grid_beat_after(last_work_q)
			else:
				local_base_q = _next_on_grid_beat_after(last_work_q)

			segment_start = segment_end + 1

		next_window_base_q = local_base_q

	return {
		"beats": beats,
		"last_work_q": last_work_q,
		"followthrough_beat": final_followthrough_beat,
	}


func _build_effect_sequence_package_beats(beat_q: float, segment: TopLevelTurnSegment) -> Dictionary:
	var beats: Array[TurnBeat] = []
	var targets := segment.target_ids.duplicate()
	var windup := _make_effect_sequence_windup_beat(beat_q, segment.actor_id, targets)
	var followthrough := _make_effect_sequence_followthrough_beat(
		beat_q + 1.0,
		segment.actor_id,
		targets,
		segment.events,
		segment.status_events
	)
	beats.append(windup)
	beats.append(followthrough)
	return {
		"beats": beats,
		"last_work_q": beat_q + 1.0,
		"followthrough_beat": followthrough,
	}


func _make_effect_sequence_windup_beat(
	beat_q: float,
	actor_id: int,
	target_ids: Array[int],
	presentation_mode: StringName = &"effect_sequence_nonattack",
	visual_sec: float = 0.14
) -> TurnBeat:
	var beat := _make_status_windup_beat(beat_q, actor_id, target_ids, presentation_mode, false, visual_sec)
	beat.label = "effect_sequence_windup"
	_tag_beat(beat, [&"windup"])
	return beat


func _make_effect_sequence_followthrough_beat(
	beat_q: float,
	actor_id: int,
	target_ids: Array[int],
	events: Array[BattleEvent],
	status_events: Array[BattleEvent],
	presentation_mode: StringName = &"effect_sequence_nonattack",
	visual_sec: float = 0.16
) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "effect_sequence_followthrough"
	_tag_beat(beat, [&"followthrough"])

	if !status_events.is_empty():
		var pop := _make_status_pop_beat(beat_q, actor_id, status_events, presentation_mode, false, visual_sec)
		for order in pop.orders:
			beat.orders.append(order)
		for event in pop.events:
			beat.events.append(event)
	else:
		var safe_targets := target_ids.duplicate()
		if safe_targets.is_empty() and actor_id > 0:
			safe_targets.append(actor_id)
		for target_id in safe_targets:
			var order := StatusPopPresentationOrder.new()
			order.kind = PresentationOrder.Kind.STATUS_POP
			order.actor_id = actor_id
			order.target_ids = [int(target_id)]
			order.visual_sec = visual_sec
			order.source_id = actor_id
			order.target_id = int(target_id)
			order.presentation_mode = presentation_mode
			beat.orders.append(order)

	for event in events:
		if event == null or beat.events.has(event):
			continue
		beat.events.append(event)

	for order in _make_group_layout_orders_from_events(events, -1):
		beat.orders.append(order)

	return beat


func _merge_compacted_segment_into_beat(target_beat: TurnBeat, segment: TopLevelTurnSegment) -> void:
	if target_beat == null or segment == null:
		return

	var source_beat: TurnBeat = null
	if segment.kind == &"summon":
		source_beat = _make_summon_pop_beat(target_beat.beat_q, segment.actor_id, segment.summon_events)
	else:
		source_beat = _make_effect_sequence_followthrough_beat(
			target_beat.beat_q,
			segment.actor_id,
			segment.target_ids,
			segment.events,
			segment.status_events,
			&"compact_followup",
			0.12
		)
		var compact_windup := _make_effect_sequence_windup_beat(
			target_beat.beat_q,
			segment.actor_id,
			segment.target_ids,
			&"compact_followup",
			0.10
		)
		_merge_beat_contents(target_beat, compact_windup)

	_merge_beat_contents(target_beat, source_beat)


func _merge_beat_contents(target_beat: TurnBeat, source_beat: TurnBeat) -> void:
	if target_beat == null or source_beat == null:
		return

	for tag in source_beat.tags:
		var name := StringName(tag)
		if !target_beat.tags.has(name):
			target_beat.tags.append(name)

	for order in source_beat.orders:
		target_beat.orders.append(order)

	for event in source_beat.events:
		if !target_beat.events.has(event):
			target_beat.events.append(event)


func _build_scope_mixed_nonattack_turn(turn_events: Array[BattleEvent]) -> Dictionary:
	var actor_id := _find_actor_id(turn_events)
	if actor_id <= 0:
		return {}

	var segments := _parse_top_level_nonattack_segments(turn_events, actor_id)
	if segments.is_empty():
		return {}

	var has_summon := false
	for segment in segments:
		if segment != null and segment.kind == &"summon":
			has_summon = true
			break

	if !has_summon:
		return {
			"action_kind": &"status",
			"beats": _build_status_beats(turn_events),
		}

	if segments[0].kind != &"summon":
		return {}

	var beats: Array[TurnBeat] = []
	var group_index := _find_group_index(turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	var trailing := _collect_nonattack_trailing_events(turn_events)

	var current_q := 0.0
	var i := 0
	var is_first_cluster := true

	while i < segments.size():
		var segment: TopLevelTurnSegment = segments[i]
		if segment == null:
			i += 1
			continue

		if segment.kind == &"summon":
			var cluster := _consume_top_level_summon_cluster(segments, i)
			var summon_events: Array[BattleEvent] = cluster.get("summon_events", [])
			var embedded_status_events: Array[BattleEvent] = cluster.get("embedded_status_events", [])
			var focus_targets: Array[int] = cluster.get("focus_targets", [])

			if is_first_cluster:
				beats.append(_make_basic_focus_beat(0.0, actor_id, focus_targets))
				beats.append(_make_summon_windup_beat(1.0, actor_id, summon_events))
				beats.append(_make_summon_pop_beat(2.0, actor_id, summon_events, embedded_status_events))
				current_q = 3.0
				is_first_cluster = false
			else:
				beats.append(_make_summon_windup_beat(current_q, actor_id, summon_events))
				beats.append(_make_summon_pop_beat(current_q + 1.0, actor_id, summon_events, embedded_status_events))
				current_q += 2.0

			i = int(cluster.get("next_index", i + 1))
			continue

		if segment.kind == &"status":
			beats.append(_make_compact_status_beat(current_q, actor_id, segment.status_events))
			current_q += 1.0

		i += 1

	var clear_q := _enforce_min_clear_focus_q_for_self_death(current_q, actor_id, turn_events)
	beats.append(_make_clear_focus_beat(clear_q, actor_id, trailing, layout_orders))
	return {
		"action_kind": &"summon",
		"beats": _sort_beats(beats),
	}


func _parse_top_level_nonattack_segments(events: Array[BattleEvent], actor_id: int) -> Array[TopLevelTurnSegment]:
	var out: Array[TopLevelTurnSegment] = []
	var scope_ranges := _build_scope_ranges(events)
	if scope_ranges.is_empty():
		return out

	var actor_turn_scope_id := _find_compiled_turn_scope_id(events, actor_id)
	if actor_turn_scope_id <= 0:
		return out

	var child_scope_ids := _find_direct_child_scope_ids(events, actor_turn_scope_id)
	for scope_id in child_scope_ids:
		var segment := _build_top_level_nonattack_segment(events, scope_ranges, int(scope_id))
		if segment != null:
			out.append(segment)

	return out


func _build_top_level_nonattack_segment(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	scope_id: int
) -> TopLevelTurnSegment:
	var scope_range: Dictionary = scope_ranges.get(scope_id, {})
	var scope_kind := int(scope_range.get("kind", -1))
	if scope_kind != int(Scope.Kind.SUMMON_ACTION) and scope_kind != int(Scope.Kind.STATUS_ACTION):
		return null

	var begin_idx := int(scope_range.get("begin", -1))
	var end_idx := int(scope_range.get("end", -1))
	if begin_idx < 0 or end_idx < 0:
		return null

	var segment := TopLevelTurnSegment.new()
	segment.kind = &"summon" if scope_kind == int(Scope.Kind.SUMMON_ACTION) else &"status"
	segment.scope_id = scope_id
	segment.actor_id = int(scope_range.get("actor_id", 0))

	for idx in range(begin_idx + 1, end_idx):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		segment.events.append(event)

		match int(event.type):
			BattleEvent.Type.SUMMONED:
				segment.summon_events.append(event)
				var summoned_id := int(event.data.get(Keys.SUMMONED_ID, 0)) if event.data != null else 0
				if summoned_id > 0 and !segment.summoned_ids.has(summoned_id):
					segment.summoned_ids.append(summoned_id)
			BattleEvent.Type.STATUS, BattleEvent.Type.STATUS_CHANGED:
				segment.status_events.append(event)
	segment.target_ids = _collect_targets_from_events(segment.events)
	return segment


func _consume_top_level_summon_cluster(segments: Array[TopLevelTurnSegment], start_index: int) -> Dictionary:
	var summon_events: Array[BattleEvent] = []
	var embedded_status_events: Array[BattleEvent] = []
	var focus_targets: Array[int] = []
	var summoned_ids: Array[int] = []
	var next_index := start_index

	while next_index < segments.size():
		var segment: TopLevelTurnSegment = segments[next_index]
		if segment == null:
			next_index += 1
			continue

		if segment.kind == &"summon":
			for event in segment.summon_events:
				summon_events.append(event)
			for target_id in _collect_targets_from_summon_events(segment.summon_events):
				if !focus_targets.has(target_id):
					focus_targets.append(target_id)
			for summoned_id in segment.summoned_ids:
				if !summoned_ids.has(summoned_id):
					summoned_ids.append(summoned_id)
			next_index += 1
			continue

		if segment.kind == &"status" and _segment_embeds_into_summon(segment, summoned_ids):
			for event in segment.status_events:
				embedded_status_events.append(event)
			next_index += 1
			continue

		break

	return {
		"summon_events": summon_events,
		"embedded_status_events": embedded_status_events,
		"focus_targets": focus_targets,
		"summoned_ids": summoned_ids,
		"next_index": next_index,
	}


func _segment_embeds_into_summon(segment: TopLevelTurnSegment, summoned_ids: Array[int]) -> bool:
	if segment == null or segment.kind != &"status":
		return false
	if segment.target_ids.is_empty() or summoned_ids.is_empty():
		return false

	for target_id in segment.target_ids:
		if !summoned_ids.has(int(target_id)):
			return false
	return true


func _collect_nonattack_trailing_events(events: Array[BattleEvent]) -> Array[BattleEvent]:
	var trailing: Array[BattleEvent] = []
	for event in events:
		if event == null:
			continue
		match int(event.type):
			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(event)
	return trailing


func _parse_scope_driven_attack_turn(events: Array[BattleEvent]) -> ParsedNpcAttackTurn:
	var actor_id := _find_actor_id(events)
	if actor_id <= 0:
		return null

	var scope_ranges := _build_scope_ranges(events)
	if scope_ranges.is_empty():
		return null

	var compiled_turn_scope_id := _find_compiled_turn_scope_id(events, actor_id)
	if compiled_turn_scope_id <= 0:
		return null

	var attack_scope_id := _find_primary_attack_scope_id(events, compiled_turn_scope_id, actor_id)
	if attack_scope_id <= 0:
		return null

	var attack_range: Dictionary = scope_ranges.get(attack_scope_id, {})
	var attack_begin := int(attack_range.get("begin", -1))
	var attack_end := int(attack_range.get("end", -1))
	if attack_begin < 0 or attack_end < 0:
		return null

	var parsed := _parse_scope_driven_attack_scope(
		events,
		scope_ranges,
		attack_scope_id,
		_find_group_index(events)
	)
	if parsed == null:
		return null

	parsed.leading_events = _collect_pre_attack_events(events, attack_begin)
	parsed.trailing_events = _collect_post_attack_events(events, attack_end)
	return parsed


func _parse_scope_driven_attack_scope(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	attack_scope_id: int,
	group_index: int
) -> ParsedNpcAttackTurn:
	var legacy := _parse_attack_scope(events, scope_ranges, attack_scope_id)
	if legacy.is_empty():
		return null

	var analysis: AttackAnalysis = legacy.get("analysis", null)
	if analysis == null or analysis.strikes.is_empty():
		return null

	var parsed := ParsedNpcAttackTurn.new()
	parsed.actor_id = int(analysis.attacker_id)
	parsed.group_index = group_index
	parsed.attack_mode = analysis.attack_mode
	parsed.projectile_scene_path = analysis.projectile_scene_path
	parsed.analysis = analysis

	var direct_infos: Array = legacy.get("direct_infos", [])
	var direct_events_by_step: Array = legacy.get("direct_events_by_step", [])
	var reactions_by_step: Array = legacy.get("reactions_by_step", [])

	for i in range(direct_infos.size()):
		var strike := ParsedDirectStrike.new()
		strike.info = direct_infos[i] as StrikePresentationInfo
		if strike.info == null:
			continue
		strike.strike_index = (
			strike.info.origin_strike_index
			if strike.info.is_cleave and strike.info.origin_strike_index >= 0
			else strike.info.strike_index
		)
		strike.target_ids = strike.info.target_ids.duplicate()

		var direct_events: Array[BattleEvent] = direct_events_by_step[i] if i < direct_events_by_step.size() else []
		strike.direct_events = direct_events.duplicate()

		var reaction_groups: Array = reactions_by_step[i] if i < reactions_by_step.size() else []
		strike.reactions = _build_delayed_reaction_nodes(
			events,
			scope_ranges,
			reaction_groups,
			i,
			group_index
		)
		parsed.direct_strikes.append(strike)

	parsed.focus_target_ids = _collect_eventual_focus_targets_from_parsed_turn(parsed)
	if parsed.focus_target_ids.is_empty():
		parsed.focus_target_ids = _collect_all_attack_targets(analysis)
	parsed.target_windows = _build_target_windows_for_strikes(parsed.direct_strikes)
	return parsed


func _build_delayed_reaction_nodes(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	reaction_groups: Array,
	source_strike_index: int,
	group_index: int
) -> Array[DelayedReactionNode]:
	var out: Array[DelayedReactionNode] = []

	for reaction_group in reaction_groups:
		var reaction := DelayedReactionNode.new()
		reaction.source_strike_index = source_strike_index
		reaction.scope_id = int(reaction_group.get("scope_id", 0))
		var reaction_events: Array[BattleEvent] = reaction_group.get("events", [])
		reaction.events = reaction_events.duplicate()

		var has_summon := false
		var has_status := false
		var has_attack := false
		var has_draw := false
		for event in reaction.events:
			if event == null:
				continue
			match int(event.type):
				BattleEvent.Type.SUMMONED:
					has_summon = true
				BattleEvent.Type.STATUS, BattleEvent.Type.STATUS_CHANGED:
					has_status = true
				BattleEvent.Type.DAMAGE_APPLIED, BattleEvent.Type.REMOVED:
					has_attack = true
				BattleEvent.Type.DRAW_CARDS:
					has_draw = true

		match StringName(reaction_group.get("kind", &"")):
			&"summon":
				reaction.kind = &"summon_reaction"
			&"attack":
				reaction.kind = &"compact_attack_reaction"
			_:
				if has_summon:
					reaction.kind = &"summon_reaction"
				elif has_attack:
					reaction.kind = &"compact_attack_reaction"
				elif has_status:
					reaction.kind = &"status_followup_reaction"
				elif has_draw:
					reaction.kind = &"draw_followup_reaction"
				else:
					reaction.kind = &"reaction"

		if reaction.kind == &"compact_attack_reaction" and reaction.scope_id > 0:
			reaction.nested_attack = _parse_scope_driven_attack_scope(
				events,
				scope_ranges,
				reaction.scope_id,
				group_index
			)

		out.append(reaction)

	return out


func _collect_eventual_focus_targets_from_parsed_turn(parsed: ParsedNpcAttackTurn) -> Array[int]:
	var out: Array[int] = []
	var seen := {}

	if parsed == null:
		return out

	for strike in parsed.direct_strikes:
		if strike == null:
			continue
		_append_unique_target_ids(out, seen, strike.target_ids)

		for reaction in strike.reactions:
			if reaction == null:
				continue
			if reaction.kind != &"compact_attack_reaction":
				continue
			var nested: ParsedNpcAttackTurn = reaction.nested_attack as ParsedNpcAttackTurn
			_append_unique_target_ids(out, seen, _collect_eventual_focus_targets_from_parsed_turn(nested))

	return out


func _append_unique_target_ids(out: Array[int], seen: Dictionary, target_ids: Array[int]) -> void:
	for tid in target_ids:
		var cid := int(tid)
		if cid <= 0 or seen.has(cid):
			continue
		seen[cid] = true
		out.append(cid)


func _build_target_windows_for_strikes(strikes: Array[ParsedDirectStrike]) -> Array[TargetWindow]:
	var windows: Array[TargetWindow] = []
	var retarget_reference_targets: Array[int] = []

	for strike in strikes:
		if strike == null:
			continue

		var starts_new_window := windows.is_empty()
		if !starts_new_window and !bool(strike.info != null and strike.info.chained_from_previous):
			starts_new_window = _strike_introduces_new_targets(retarget_reference_targets, strike.target_ids)
		if starts_new_window:
			var window := TargetWindow.new()
			window.target_ids = strike.target_ids.duplicate()
			window.retarget_from_previous = !windows.is_empty()
			windows.append(window)

		var current_window := windows[windows.size() - 1]
		current_window.strikes.append(strike)
		if strike.info == null or !strike.info.chained_from_previous:
			retarget_reference_targets = strike.target_ids.duplicate()

	for window in windows:
		window.window_span_beats = _window_span_beats(window.strikes.size())

	return windows


func _strike_introduces_new_targets(previous_targets: Array[int], next_targets: Array[int]) -> bool:
	if previous_targets.is_empty():
		return !next_targets.is_empty()

	var prior := {}
	for tid in previous_targets:
		prior[int(tid)] = true

	for tid in next_targets:
		if !prior.has(int(tid)):
			return true

	return false


func _window_span_beats(strike_count: int) -> int:
	if strike_count <= 0:
		return 1
	return maxi(1, (strike_count + 1) / 2)


func _next_on_grid_beat_after(q: float) -> float:
	var rounded: float = round(q)
	if is_equal_approx(q, rounded):
		return rounded + 1.0
	return ceil(q)


func _find_reaction_segment_end(strikes: Array[ParsedDirectStrike], start_index: int) -> int:
	for i in range(start_index, strikes.size()):
		var strike := strikes[i]
		if strike != null and !strike.reactions.is_empty():
			return i
	return strikes.size() - 1


func _build_scope_driven_attack_beats(parsed: ParsedNpcAttackTurn, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	if parsed == null or parsed.analysis == null or parsed.direct_strikes.is_empty():
		return _build_generic_beats(turn_events)

	var focus_beat := _make_basic_focus_beat(0.0, parsed.actor_id, parsed.focus_target_ids)
	_tag_beat(focus_beat, [&"focus"])
	for event in parsed.leading_events:
		focus_beat.events.append(event)
	for layout_order in _find_pre_attack_group_layouts(turn_events, parsed.group_index):
		focus_beat.orders.append(layout_order)
	beats.append(focus_beat)

	var windup_beat := _make_ranged_windup_beat(1.0, parsed.analysis) if parsed.attack_mode == int(Attack.Mode.RANGED) else _make_melee_windup_beat(1.0, parsed.analysis)
	_tag_beat(windup_beat, [&"windup"])
	beats.append(windup_beat)

	var next_window_base_q := 2.0
	var last_work_q := 1.0
	var previous_direct_strike: ParsedDirectStrike = null

	for window_index in range(parsed.target_windows.size()):
		var window := parsed.target_windows[window_index]
		if window == null or window.strikes.is_empty():
			continue

		window.base_q = next_window_base_q
		_debug_log_reaction("window=%d base_q=%.2f span=%d strikes=%d targets=%s" % [
			window_index,
			float(window.base_q),
			int(window.window_span_beats),
			int(window.strikes.size()),
			str(window.target_ids),
		])

		var segment_start := 0
		var local_base_q := window.base_q

		while segment_start < window.strikes.size():
			var segment_end := _find_reaction_segment_end(window.strikes, segment_start)
			var segment_count := segment_end - segment_start + 1
			var segment_span_beats := _window_span_beats(segment_count)
			var segment_shift_q := 0.5 * float(segment_span_beats - 1)

			for local_index in range(segment_count):
				var strike := window.strikes[segment_start + local_index]
				if strike == null:
					continue

				var impact_q := local_base_q + segment_shift_q + 0.5 * float(local_index)
				var is_window_start := segment_start == 0 and local_index == 0

				if parsed.attack_mode == int(Attack.Mode.RANGED):
					var fire_q := impact_q - 0.5
					if (
						strike.info != null
						and !strike.info.is_cleave
						and previous_direct_strike != null
						and previous_direct_strike.info != null
						and previous_direct_strike.info.is_cleave
					):
						fire_q += 0.001
						impact_q += 0.001
					_add_ranged_direct_strike_to_beats(beats, parsed.analysis, strike, fire_q, impact_q, is_window_start)
					if strike.info != null and strike.info.is_cleave:
						_debug_log_reaction("main ranged cleave=%d q=%.2f targets=%s window=%d" % [
							int(strike.strike_index),
							float(impact_q),
							str(strike.target_ids),
							window_index,
						])
					else:
						_debug_log_reaction("main ranged strike=%d fire_q=%.2f impact_q=%.2f targets=%s window=%d" % [
							int(strike.strike_index),
							float(fire_q),
							float(impact_q),
							str(strike.target_ids),
							window_index,
						])
				else:
					_add_melee_direct_strike_to_beats(beats, parsed.analysis, strike, impact_q, is_window_start)
					_debug_log_reaction("main melee %s=%d q=%.2f targets=%s window=%d" % [
						"cleave" if strike.info != null and strike.info.is_cleave else "strike",
						int(strike.strike_index),
						float(impact_q),
						str(strike.target_ids),
						window_index,
					])

				last_work_q = maxf(last_work_q, impact_q)
				previous_direct_strike = strike

			var terminal_strike := window.strikes[segment_end]
			if terminal_strike != null and !terminal_strike.reactions.is_empty():
				var reaction_q := _next_on_grid_beat_after(last_work_q)
				for reaction in terminal_strike.reactions:
					var reaction_beat := _make_delayed_reaction_beat(reaction_q, reaction)
					beats.append(reaction_beat)
					_debug_log_reaction("inserted reaction beat strike=%d q=%.2f kind=%s" % [
						int(terminal_strike.strike_index),
						float(reaction_q),
						String(reaction.kind),
					])
					last_work_q = reaction_q
					reaction_q += 1.0
				local_base_q = _next_on_grid_beat_after(last_work_q)
			else:
				local_base_q = _next_on_grid_beat_after(last_work_q)

			segment_start = segment_end + 1

		next_window_base_q = local_base_q

	var clear_q := _next_on_grid_beat_after(last_work_q)
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, parsed.actor_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, parsed.group_index)
	var clear_focus := _make_clear_focus_beat(clear_q, parsed.actor_id, parsed.trailing_events, layout_orders)
	_tag_beat(clear_focus, [&"clear_focus"])
	beats.append(clear_focus)

	return _sort_beats(beats)


func _add_melee_direct_strike_to_beats(
	beats: Array[TurnBeat],
	analysis: AttackAnalysis,
	strike: ParsedDirectStrike,
	beat_q: float,
	is_window_start: bool
) -> void:
	var beat_label := "melee_cleave_%d" % int(strike.strike_index) if strike != null and strike.info != null and strike.info.is_cleave else "melee_strike_%d" % int(strike.strike_index)
	var beat := _find_or_make_beat(beats, beat_q, beat_label)
	_tag_beat(beat, [&"cleave", &"impact"] if strike != null and strike.info != null and strike.info.is_cleave else [&"strike", &"impact"])
	if is_window_start:
		_tag_beat(beat, [&"window_start"])

	beat.orders.append(_make_melee_strike_order_from_info(analysis, strike.info, int(strike.strike_index)))
	for impact_order in _make_impact_orders_for_info(analysis, strike.info, int(strike.strike_index), strike.direct_events):
		beat.orders.append(impact_order)
	for event in strike.direct_events:
		beat.events.append(event)


func _add_ranged_direct_strike_to_beats(
	beats: Array[TurnBeat],
	analysis: AttackAnalysis,
	strike: ParsedDirectStrike,
	fire_q: float,
	impact_q: float,
	is_window_start: bool
) -> void:
	var is_cleave := strike != null and strike.info != null and strike.info.is_cleave
	if !is_cleave:
		var fire_label := "ranged_fire_%d" % int(strike.strike_index)
		var fire_beat := _find_or_make_beat(beats, fire_q, fire_label)
		_tag_beat(fire_beat, [&"strike", &"fire"])
		if is_window_start:
			_tag_beat(fire_beat, [&"window_start"])
		fire_beat.orders.append(_make_ranged_fire_order_from_info(analysis, strike.info, int(strike.strike_index)))
	else:
		var continuation_beat := _find_or_make_beat(beats, fire_q)
		continuation_beat.orders.append(_make_ranged_cleave_followthrough_order_from_info(analysis, strike.info, int(strike.strike_index)))

	var impact_label := "ranged_cleave_%d" % int(strike.strike_index) if is_cleave else "ranged_impact_%d" % int(strike.strike_index)
	var impact_beat := _find_or_make_beat(beats, impact_q, impact_label)
	_tag_beat(impact_beat, [&"impact", &"cleave"] if is_cleave else [&"impact"])
	if is_cleave and is_window_start:
		_tag_beat(impact_beat, [&"window_start"])
	for impact_order in _make_impact_orders_for_info(analysis, strike.info, int(strike.strike_index), strike.direct_events):
		impact_beat.orders.append(impact_order)
	for event in strike.direct_events:
		impact_beat.events.append(event)


func _make_delayed_reaction_beat(beat_q: float, reaction: DelayedReactionNode) -> TurnBeat:
	if reaction == null:
		var beat := TurnBeat.new()
		beat.beat_q = beat_q
		beat.label = "reaction"
		_tag_beat(beat, [&"reaction"])
		return beat

	match reaction.kind:
		&"summon_reaction":
			return _make_reaction_summon_beat(beat_q, reaction.events)
		&"compact_attack_reaction":
			return _make_compact_reaction_attack_beat(beat_q, reaction)
		&"status_followup_reaction":
			return _make_reaction_status_beat(beat_q, reaction.events)
		&"draw_followup_reaction":
			return _make_reaction_draw_beat(beat_q, reaction.events)
		_:
			var generic_beat := TurnBeat.new()
			generic_beat.beat_q = beat_q
			generic_beat.label = "reaction"
			_tag_beat(generic_beat, [&"reaction"])
			for event in reaction.events:
				generic_beat.events.append(event)
			return generic_beat


func _make_compact_reaction_attack_beat(beat_q: float, reaction: DelayedReactionNode) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "reaction_attack"
	_tag_beat(beat, [&"reaction", &"compact_attack_reaction"])

	var nested: ParsedNpcAttackTurn = reaction.nested_attack as ParsedNpcAttackTurn
	if nested == null or nested.analysis == null:
		for event in reaction.events:
			beat.events.append(event)
		return beat

	if int(nested.attack_mode) == int(Attack.Mode.RANGED):
		for strike in nested.direct_strikes:
			if strike == null:
				continue
			if strike.info != null and strike.info.is_cleave:
				beat.orders.append(_make_ranged_cleave_followthrough_order_from_info(nested.analysis, strike.info, int(strike.strike_index)))
			else:
				beat.orders.append(_make_ranged_fire_order_from_info(nested.analysis, strike.info, int(strike.strike_index)))
	else:
		var nested_info := nested.direct_strikes[0].info if !nested.direct_strikes.is_empty() else null
		beat.orders.append(_make_melee_strike_order_from_info(nested.analysis, nested_info, 0, _collect_eventual_focus_targets_from_parsed_turn(nested)))

	for strike in nested.direct_strikes:
		if strike == null:
			continue
		for impact_order in _make_impact_orders_for_info(nested.analysis, strike.info, int(strike.strike_index), strike.direct_events):
			beat.orders.append(impact_order)
		for event in strike.direct_events:
			beat.events.append(event)

	for event in reaction.events:
		if !beat.events.has(event):
			beat.events.append(event)

	return beat


func _find_actor_id(events: Array[BattleEvent]) -> int:
	for e in events:
		if e == null:
			continue
		if int(e.type) == int(BattleEvent.Type.ACTOR_BEGIN):
			return int(e.data.get(Keys.ACTOR_ID, 0)) if e.data != null else 0
		if int(e.type) == int(BattleEvent.Type.SCOPE_BEGIN) and (
			int(e.scope_kind) == int(Scope.Kind.ACTOR_TURN)
			or int(e.scope_kind) == int(Scope.Kind.CARD_ATTACK_NOW_TURN)
		):
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
		if _is_attack_chain_marker_event_type(int(e.type)):
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
		elif _is_attack_chain_marker_event_type(int(e.type)):
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
			BattleEvent.Type.STRIKE, BattleEvent.Type.CLEAVE:
				has_strike = true
			BattleEvent.Type.SUMMONED:
				has_summon = true
	return has_status and !has_strike and !has_summon


func _parse_attack_turn(events: Array[BattleEvent]) -> Dictionary:
	var actor_id := _find_actor_id(events)
	if actor_id <= 0:
		return {}

	var scope_ranges := _build_scope_ranges(events)
	if scope_ranges.is_empty():
		return {}

	var actor_turn_scope_id := _find_compiled_turn_scope_id(events, actor_id)
	if actor_turn_scope_id <= 0:
		return {}

	var attack_scope_id := _find_primary_attack_scope_id(events, actor_turn_scope_id, actor_id)
	if attack_scope_id <= 0:
		return {}

	var parsed := _parse_attack_scope(events, scope_ranges, attack_scope_id)
	if parsed.is_empty():
		return {}

	var attack_range: Dictionary = scope_ranges.get(attack_scope_id, {})
	var attack_begin := int(attack_range.get("begin", -1))
	var attack_end := int(attack_range.get("end", -1))
	if attack_begin < 0 or attack_end < 0:
		return {}

	parsed["scope_ranges"] = scope_ranges
	parsed["source_events"] = events
	parsed["attack_scope_id"] = attack_scope_id
	parsed["leading"] = _collect_pre_attack_events(events, attack_begin)
	parsed["trailing"] = _collect_post_attack_events(events, attack_end)
	return parsed


func _parse_attack_scope(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	attack_scope_id: int
) -> Dictionary:
	var direct_scope_ids := _find_direct_attack_chain_scope_ids(events, attack_scope_id)
	if direct_scope_ids.is_empty():
		return {}

	var analysis := AttackAnalysis.new()
	var direct_infos: Array[StrikePresentationInfo] = []
	var direct_events_by_step: Array = []
	var reactions_by_step: Array = []
	var top_level_reactions_by_strike := _collect_attack_level_reaction_groups(
		events,
		scope_ranges,
		attack_scope_id,
		direct_scope_ids
	)
	var primary_strike_count := 0

	for i in range(direct_scope_ids.size()):
		var strike_scope_id := int(direct_scope_ids[i])
		var parsed_strike := _parse_attack_strike(events, scope_ranges, strike_scope_id)
		var marker: BattleEvent = parsed_strike.get("marker", null)
		var direct_events: Array[BattleEvent] = parsed_strike.get("direct_events", [])
		var reactions: Array = parsed_strike.get("reactions", [])
		if i < top_level_reactions_by_strike.size():
			reactions.append_array(top_level_reactions_by_strike[i])

		direct_events_by_step.append(direct_events)
		reactions_by_step.append(reactions)

		var display_index := primary_strike_count
		if marker != null and marker.data != null and bool(marker.data.get(Keys.CLEAVE, false)):
			display_index = maxi(int(marker.data.get(Keys.ORIGIN_STRIKE_INDEX, primary_strike_count - 1)), 0)

		var strike_info := _build_strike_info_from_events(marker, direct_events, display_index)
		direct_infos.append(strike_info)
		if !strike_info.is_cleave:
			analysis.strikes.append(strike_info)
			primary_strike_count += 1
		if strike_info.has_lethal_hit:
			_record_lethal_index(analysis, display_index)

		if analysis.attacker_id <= 0 and marker != null and marker.data != null:
			analysis.attacker_id = int(marker.data.get(Keys.SOURCE_ID, 0))
			analysis.attack_mode = int(marker.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
			analysis.projectile_scene_path = String(marker.data.get(Keys.PROJECTILE_SCENE, "uid://bxmhi3urqmpfh"))

		if strike_info.is_cleave and display_index >= 0 and display_index < analysis.strikes.size():
			analysis.strikes[display_index].has_cleave = true

	analysis.strike_count = primary_strike_count

	return {
		"analysis": analysis,
		"direct_infos": direct_infos,
		"direct_events_by_step": direct_events_by_step,
		"reactions_by_step": reactions_by_step,
	}


func _parse_attack_strike(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	strike_scope_id: int
) -> Dictionary:
	var strike_range: Dictionary = scope_ranges.get(strike_scope_id, {})
	var strike_begin := int(strike_range.get("begin", -1))
	var strike_end := int(strike_range.get("end", -1))
	if strike_begin < 0 or strike_end < 0 or strike_end <= strike_begin:
		return {}

	var reactions := _collect_reaction_groups_for_strike(events, scope_ranges, strike_scope_id)
	var marker: BattleEvent = null
	var direct_events: Array[BattleEvent] = []

	for idx in range(strike_begin + 1, strike_end):
		var event: BattleEvent = events[idx]
		if event == null:
			continue

		if _is_attack_chain_marker_event_type(int(event.type)) and _index_is_inside_reaction(idx, reactions):
			continue

		if _is_attack_chain_marker_event_type(int(event.type)):
			if marker == null:
				marker = event
			continue

		if _index_is_inside_reaction(idx, reactions):
			continue

		if _is_attack_direct_event(event) or int(event.type) == int(BattleEvent.Type.SET_INTENT):
			direct_events.append(event)

	for i in range(reactions.size()):
		var reaction: Dictionary = reactions[i]
		var next_begin := strike_end
		if i + 1 < reactions.size():
			next_begin = int(reactions[i + 1].get("begin", strike_end))
		reaction["events"] = _collect_reaction_group_events(events, reaction, next_begin)

	return {
		"marker": marker,
		"direct_events": direct_events,
		"reactions": reactions,
	}


func _collect_attack_level_reaction_groups(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	attack_scope_id: int,
	strike_scope_ids: Array[int]
) -> Array:
	var out: Array = []
	for _i in range(strike_scope_ids.size()):
		out.append([])

	if strike_scope_ids.is_empty():
		return out

	var child_scope_ids := _find_direct_child_scope_ids(events, attack_scope_id)
	if child_scope_ids.is_empty():
		return out

	var strike_index_by_scope_id := {}
	for i in range(strike_scope_ids.size()):
		strike_index_by_scope_id[int(strike_scope_ids[i])] = i

	var attack_range: Dictionary = scope_ranges.get(attack_scope_id, {})
	var attack_end := int(attack_range.get("end", events.size()))
	var active_strike_index := -1

	for child_index in range(child_scope_ids.size()):
		var child_scope_id := int(child_scope_ids[child_index])
		if strike_index_by_scope_id.has(child_scope_id):
			active_strike_index = int(strike_index_by_scope_id[child_scope_id])
			continue

		if active_strike_index < 0:
			continue

		var reaction_range: Dictionary = scope_ranges.get(child_scope_id, {})
		var scope_kind := int(reaction_range.get("kind", -1))
		match scope_kind:
			Scope.Kind.SUMMON_ACTION, Scope.Kind.ATTACK, Scope.Kind.STATUS_ACTION:
				pass
			_:
				continue

		var next_begin := attack_end
		if child_index + 1 < child_scope_ids.size():
			var next_scope_range: Dictionary = scope_ranges.get(int(child_scope_ids[child_index + 1]), {})
			next_begin = int(next_scope_range.get("begin", attack_end))

		var kind_name := _scope_kind_to_reaction_kind_name(scope_kind)
		var reaction := {
			"kind": kind_name,
			"scope_id": int(child_scope_id),
			"begin": int(reaction_range.get("begin", -1)),
			"end": int(reaction_range.get("end", -1)),
			"events": [],
		}
		reaction["events"] = _collect_reaction_group_events(events, reaction, next_begin)
		_debug_log_reaction("attached top-level reaction strike=%d kind=%s scope=%d" % [
			int(active_strike_index),
			String(reaction.get("kind", &"unknown")),
			int(child_scope_id),
		])
		out[active_strike_index].append(reaction)

	return out


func _collect_reaction_group_events(
	events: Array[BattleEvent],
	reaction: Dictionary,
	next_begin: int
) -> Array[BattleEvent]:
	var reaction_events: Array[BattleEvent] = []
	var reaction_begin := int(reaction.get("begin", -1))
	var reaction_end := int(reaction.get("end", -1))
	if reaction_begin < 0 or reaction_end < 0:
		return reaction_events

	for idx in range(reaction_begin + 1, reaction_end):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		reaction_events.append(event)

	for idx in range(reaction_end + 1, next_begin):
		var event: BattleEvent = events[idx]
		if event == null or _is_structural_ignored_event(event):
			continue
		if _is_reaction_followup_event(event):
			reaction_events.append(event)

	return reaction_events


func _collect_reaction_groups_for_strike(
	events: Array[BattleEvent],
	scope_ranges: Dictionary,
	strike_scope_id: int
) -> Array:
	var out: Array = []
	var child_scope_ids: Array[int] = _find_direct_child_scope_ids(events, strike_scope_id)
	for scope_id in child_scope_ids:
		var reaction_range: Dictionary = scope_ranges.get(int(scope_id), {})
		var scope_kind := int(reaction_range.get("kind", -1))
		match scope_kind:
			Scope.Kind.SUMMON_ACTION, Scope.Kind.ATTACK, Scope.Kind.STATUS_ACTION:
				pass
			_:
				continue

		var kind_name := _scope_kind_to_reaction_kind_name(scope_kind)
		out.append({
			"kind": kind_name,
			"scope_id": int(scope_id),
			"begin": int(reaction_range.get("begin", -1)),
			"end": int(reaction_range.get("end", -1)),
			"events": [],
		})
	return out


func _scope_kind_to_reaction_kind_name(scope_kind: int) -> StringName:
	match scope_kind:
		Scope.Kind.SUMMON_ACTION: return &"summon"
		Scope.Kind.STATUS_ACTION: return &"status"
		_: return &"attack"


func _build_scope_ranges(events: Array[BattleEvent]) -> Dictionary:
	var ranges := {}
	for i in range(events.size()):
		var event: BattleEvent = events[i]
		if event == null:
			continue

		if int(event.type) == int(BattleEvent.Type.SCOPE_BEGIN):
			ranges[int(event.scope_id)] = {
				"begin": i,
				"end": -1,
				"kind": int(event.scope_kind),
				"parent": int(event.parent_scope_id),
				"actor_id": int(event.data.get(Keys.ACTOR_ID, 0)) if event.data != null else 0,
				"data": event.data.duplicate(true) if event.data != null else {},
			}
		elif int(event.type) == int(BattleEvent.Type.SCOPE_END):
			if ranges.has(int(event.scope_id)):
				var range: Dictionary = ranges[int(event.scope_id)]
				range["end"] = i
				ranges[int(event.scope_id)] = range
	return ranges


func _find_compiled_turn_scope_id(events: Array[BattleEvent], actor_id: int, include_card_attack_now: bool = true) -> int:
	for event in events:
		if event == null:
			continue
		if int(event.type) != int(BattleEvent.Type.SCOPE_BEGIN):
			continue
		if int(event.scope_kind) != int(Scope.Kind.ACTOR_TURN) \
			and not (include_card_attack_now and int(event.scope_kind) == int(Scope.Kind.CARD_ATTACK_NOW_TURN)):
			continue
		if event.data == null:
			continue
		if int(event.data.get(Keys.ACTOR_ID, 0)) == int(actor_id):
			return int(event.scope_id)
	return 0


func _find_primary_attack_scope_id(events: Array[BattleEvent], compiled_turn_scope_id: int, actor_id: int) -> int:
	for event in events:
		if event == null:
			continue
		if int(event.type) != int(BattleEvent.Type.SCOPE_BEGIN):
			continue
		if int(event.scope_kind) != int(Scope.Kind.ATTACK):
			continue
		if int(event.parent_scope_id) != int(compiled_turn_scope_id):
			continue
		if event.data == null:
			continue
		if int(event.data.get(Keys.ACTOR_ID, 0)) == int(actor_id):
			return int(event.scope_id)
	return 0


func _find_direct_child_scope_ids(events: Array[BattleEvent], parent_scope_id: int, kind: int = -1) -> Array[int]:
	var out: Array[int] = []
	for event in events:
		if event == null:
			continue
		if int(event.type) != int(BattleEvent.Type.SCOPE_BEGIN):
			continue
		if int(event.parent_scope_id) != int(parent_scope_id):
			continue
		if kind != -1 and int(event.scope_kind) != int(kind):
			continue
		out.append(int(event.scope_id))
	return out


func _find_direct_attack_chain_scope_ids(events: Array[BattleEvent], attack_scope_id: int) -> Array[int]:
	var out: Array[int] = []
	for event in events:
		if event == null:
			continue
		if int(event.type) != int(BattleEvent.Type.SCOPE_BEGIN):
			continue
		if int(event.parent_scope_id) != int(attack_scope_id):
			continue
		if int(event.scope_kind) != int(Scope.Kind.STRIKE) and int(event.scope_kind) != int(Scope.Kind.CLEAVE):
			continue
		out.append(int(event.scope_id))
	return out


func _is_attack_chain_marker_event_type(event_type: int) -> bool:
	return int(event_type) == int(BattleEvent.Type.STRIKE) or int(event_type) == int(BattleEvent.Type.CLEAVE)


func _collect_pre_attack_events(events: Array[BattleEvent], attack_begin: int) -> Array[BattleEvent]:
	var leading: Array[BattleEvent] = []
	for idx in range(maxi(attack_begin, 0)):
		var event: BattleEvent = events[idx]
		if event == null:
			continue
		match int(event.type):
			BattleEvent.Type.STATUS, \
			BattleEvent.Type.STATUS_CHANGED, \
			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MANA, \
			BattleEvent.Type.HEAL_APPLIED, \
			BattleEvent.Type.CHANGE_MAX_HEALTH, \
			BattleEvent.Type.MODIFY_BATTLE_CARD, \
			BattleEvent.Type.MOVED:
				leading.append(event)
	return leading


func _collect_post_attack_events(events: Array[BattleEvent], attack_end: int) -> Array[BattleEvent]:
	var trailing: Array[BattleEvent] = []
	for idx in range(attack_end + 1, events.size()):
		var event: BattleEvent = events[idx]
		if event == null:
			continue
		match int(event.type):
			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(event)
	return trailing


func _is_attack_direct_event(event: BattleEvent) -> bool:
	if event == null:
		return false
	match int(event.type):
		BattleEvent.Type.DAMAGE_APPLIED, \
		BattleEvent.Type.CHANGE_MAX_HEALTH, \
		BattleEvent.Type.MODIFY_BATTLE_CARD, \
		BattleEvent.Type.STATUS, \
		BattleEvent.Type.REMOVED:
			return true
	return false


func _is_reaction_followup_event(event: BattleEvent) -> bool:
	if event == null:
		return false
	match int(event.type):
		BattleEvent.Type.STATUS, \
		BattleEvent.Type.STATUS_CHANGED, \
		BattleEvent.Type.SUMMONED, \
		BattleEvent.Type.DRAW_CARDS, \
		BattleEvent.Type.SET_INTENT, \
		BattleEvent.Type.TURN_STATUS, \
		BattleEvent.Type.MOVED:
			return true
	return false


func _index_is_inside_reaction(idx: int, reactions: Array) -> bool:
	for reaction in reactions:
		if idx >= int(reaction.get("begin", -1)) and idx <= int(reaction.get("end", -1)):
			return true
	return false


func _populate_strike_info_from_marker_and_events(
	s: StrikePresentationInfo, marker: BattleEvent, direct_events: Array[BattleEvent], strike_index: int
) -> void:
	if marker != null and marker.data != null:
		if marker.data.has(Keys.TARGET_IDS):
			for tid in marker.data.get(Keys.TARGET_IDS, []):
				s.target_ids.append(int(tid))
		elif marker.data.has(Keys.TARGET_ID):
			var tid := int(marker.data.get(Keys.TARGET_ID, 0))
			if tid > 0:
				s.target_ids.append(tid)
		s.is_cleave = bool(marker.data.get(Keys.CLEAVE, false))
		s.chained_from_previous = bool(marker.data.get(Keys.CHAINED_FROM_PREVIOUS, false)) or s.is_cleave
		s.origin_strike_index = int(marker.data.get(Keys.ORIGIN_STRIKE_INDEX, -1))
		s.chain_source_target_id = int(marker.data.get(Keys.CHAIN_SOURCE_TARGET_ID, 0))
		s.cleave_damage = int(marker.data.get(Keys.CLEAVE_DAMAGE, 0))
		if s.chained_from_previous and s.origin_strike_index < 0:
			s.origin_strike_index = strike_index

	for event in direct_events:
		if event == null:
			continue
		match int(event.type):
			BattleEvent.Type.DAMAGE_APPLIED:
				var h := HitPresentationInfo.new()
				h.target_id = int(event.data.get(Keys.TARGET_ID, 0)) if event.data != null else 0
				h.amount = int(event.data.get(Keys.FINAL_AMOUNT, 0)) if event.data != null else 0
				h.before_health = int(event.data.get(Keys.BEFORE_HEALTH, 0)) if event.data != null else 0
				h.after_health = int(event.data.get(Keys.AFTER_HEALTH, 0)) if event.data != null else 0
				h.was_lethal = bool(event.data.get(Keys.WAS_LETHAL, false)) if event.data != null else false
				h.is_self_recoil = bool(event.data.get(Keys.SELF_RECOIL, false)) if event.data != null else false
				if h.is_self_recoil:
					s.recoil_hits.append(h)
					s.has_self_recoil = true
				else:
					s.hits.append(h)
					s.hit_count += 1
				if h.was_lethal and !h.is_self_recoil:
					s.has_lethal_hit = true
			BattleEvent.Type.REMOVED:
				var died_target_id := int(event.data.get(Keys.TARGET_ID, 0)) if event.data != null else 0
				var is_self_recoil_death := bool(event.data.get(Keys.SELF_RECOIL, false)) if event.data != null else false
				if _is_death_removal_event(event) and !is_self_recoil_death \
					and marker != null and marker.data != null \
					and died_target_id != int(marker.data.get(Keys.SOURCE_ID, 0)):
					s.has_lethal_hit = true


func _build_strike_info_from_events(marker: BattleEvent, direct_events: Array[BattleEvent], strike_index: int) -> StrikePresentationInfo:
	var s := StrikePresentationInfo.new()
	s.strike_index = strike_index
	_populate_strike_info_from_marker_and_events(s, marker, direct_events, strike_index)
	return s


func _collect_strike_blocks(events: Array[BattleEvent]) -> Array[Array]:
	var out: Array[Array] = []
	var current: Array = []

	for e in events:
		if e == null:
			continue

		if _is_attack_chain_marker_event_type(int(e.type)):
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
	analysis.projectile_scene_path = String(first_strike.data.get(Keys.PROJECTILE_SCENE, "uid://bxmhi3urqmpfh")) if first_strike.data != null else "uid://bxmhi3urqmpfh"
	var primary_strike_count := 0

	for i in range(blocks.size()):
		var marker: BattleEvent = blocks[i][0] if !blocks[i].is_empty() else null
		var display_index := primary_strike_count
		if marker != null and marker.data != null and bool(marker.data.get(Keys.CLEAVE, false)):
			display_index = maxi(int(marker.data.get(Keys.ORIGIN_STRIKE_INDEX, primary_strike_count - 1)), 0)

		var strike_info := _build_strike_info_from_block(blocks[i], display_index)
		if !strike_info.is_cleave:
			analysis.strikes.append(strike_info)
			primary_strike_count += 1
		elif display_index >= 0 and display_index < analysis.strikes.size():
			analysis.strikes[display_index].has_cleave = true
		if strike_info.has_lethal_hit:
			_record_lethal_index(analysis, display_index)

	analysis.strike_count = primary_strike_count

	return analysis


func _record_lethal_index(analysis: AttackAnalysis, display_index: int) -> void:
	if !(display_index in analysis.lethal_indices):
		analysis.lethal_indices.append(display_index)


func _build_strike_info_from_block(block: Array, strike_index: int) -> StrikePresentationInfo:
	var s := StrikePresentationInfo.new()
	s.strike_index = strike_index
	if block.is_empty():
		return s
	var direct: Array[BattleEvent] = block.slice(1)
	_populate_strike_info_from_marker_and_events(s, block[0], direct, strike_index)
	return s


func _build_attack_beats(analysis: AttackAnalysis, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	if analysis == null or analysis.strike_count <= 0:
		return _build_generic_beats(turn_events)

	if analysis.attack_mode == int(Attack.Mode.RANGED):
		return _build_ranged_attack_beats(analysis, turn_events)

	return _build_melee_attack_beats(analysis, turn_events)


func _build_attack_beats_from_parsed(parsed: Dictionary, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var analysis: AttackAnalysis = parsed.get("analysis", null)
	if analysis == null or analysis.strike_count <= 0:
		return _build_generic_beats(turn_events)

	if analysis.attack_mode == int(Attack.Mode.RANGED):
		return _build_ranged_attack_beats_from_parsed(parsed, turn_events)

	return _build_melee_attack_beats_from_parsed(parsed, turn_events)


func _build_melee_attack_beats_from_parsed(parsed: Dictionary, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var analysis: AttackAnalysis = parsed.get("analysis", null)
	var leading: Array[BattleEvent] = parsed.get("leading", [])
	var trailing: Array[BattleEvent] = parsed.get("trailing", [])
	var direct_events_by_strike: Array = parsed.get("direct_events_by_strike", [])
	var reactions_by_strike: Array = parsed.get("reactions_by_strike", [])
	var group_index := _find_group_index(turn_events)

	var focus_beat := _make_focus_beat(0.0, analysis)
	for event in leading:
		focus_beat.events.append(event)
	for layout_order in _find_pre_attack_group_layouts(turn_events, group_index):
		focus_beat.orders.append(layout_order)
	beats.append(focus_beat)
	beats.append(_make_melee_windup_beat(1.0, analysis))

	var n := analysis.strike_count
	var start_q := 2.0
	if n >= 3:
		start_q = 2.5

	var reaction_shift_q := 0.0
	var final_q := 0.0

	for i in range(n):
		var beat_q := start_q + 0.5 * float(i) + reaction_shift_q
		var strike_events: Array[BattleEvent] = direct_events_by_strike[i] if i < direct_events_by_strike.size() else []
		beats.append(_make_melee_strike_beat(beat_q, analysis, i, strike_events))
		_debug_log_reaction("main melee strike=%d q=%.2f targets=%s events=%s" % [
			i,
			beat_q,
			str(_targets_for_focus_strike(analysis, i)),
			_debug_event_list_summary(strike_events),
		])
		final_q = maxf(final_q, beat_q)

		var reaction_q := beat_q
		var reactions: Array = reactions_by_strike[i] if i < reactions_by_strike.size() else []
		for reaction in reactions:
			reaction_q += 1.0
			var built := _build_reaction_beats_from_group(parsed, reaction, reaction_q)
			var reaction_beats: Array = built.get("beats", [])
			for reaction_beat in reaction_beats:
				beats.append(reaction_beat)
			reaction_q = float(built.get("last_q", reaction_q))
			final_q = maxf(final_q, reaction_q)
			_debug_log_reaction("inserted melee reaction beat strike=%d q=%.2f kind=%s" % [
				i,
				reaction_q,
				String(reaction.get("kind", &"unknown")),
			])

		if !reactions.is_empty():
			# After a settled reaction beat, give the outer melee cadence one clean step
			# before the next strike starts so it reads as a pause, not a compression.
			reaction_shift_q += (reaction_q - beat_q) + 0.5

	var clear_q := final_q + _tail_gap_q_for_attack(analysis)
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, analysis.attacker_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, analysis.attacker_id, trailing, layout_orders))
	return _sort_beats(beats)


func _build_ranged_attack_beats_from_parsed(parsed: Dictionary, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var analysis: AttackAnalysis = parsed.get("analysis", null)
	var leading: Array[BattleEvent] = parsed.get("leading", [])
	var trailing: Array[BattleEvent] = parsed.get("trailing", [])
	var direct_events_by_strike: Array = parsed.get("direct_events_by_strike", [])
	var reactions_by_strike: Array = parsed.get("reactions_by_strike", [])
	var group_index := _find_group_index(turn_events)

	var focus_beat := _make_focus_beat(0.0, analysis)
	for event in leading:
		focus_beat.events.append(event)
	for layout_order in _find_pre_attack_group_layouts(turn_events, group_index):
		focus_beat.orders.append(layout_order)
	beats.append(focus_beat)
	beats.append(_make_ranged_windup_beat(1.0, analysis))

	var n := analysis.strike_count
	var fire_start_q := 1.5
	if n >= 3:
		fire_start_q = 2.0

	var reaction_shift_q := 0.0
	var final_q := 0.0

	for i in range(n):
		var fire_q := fire_start_q + 0.5 * float(i) + reaction_shift_q
		var impact_q := fire_q + 0.5
		var strike_events: Array[BattleEvent] = direct_events_by_strike[i] if i < direct_events_by_strike.size() else []

		_add_order_to_beat_array(
			beats,
			fire_q,
			_make_focus_order(analysis.attacker_id, _targets_for_focus_strike(analysis, i), 0.20),
			"ranged_fire_%d" % i
		)
		_add_order_to_beat_array(beats, fire_q, _make_ranged_fire_order(analysis, i), "ranged_fire_%d" % i)
		_add_orders_to_beat_array(beats, impact_q, _make_impact_orders_for_strike(analysis, i, strike_events), "ranged_impact_%d" % i)
		_add_events_to_beat_array(beats, impact_q, strike_events, "ranged_impact_%d" % i)
		_debug_log_reaction("main ranged strike=%d fire_q=%.2f impact_q=%.2f targets=%s events=%s" % [
			i,
			fire_q,
			impact_q,
			str(_targets_for_focus_strike(analysis, i)),
			_debug_event_list_summary(strike_events),
		])
		final_q = maxf(final_q, impact_q)

		var reaction_q := impact_q
		var reactions: Array = reactions_by_strike[i] if i < reactions_by_strike.size() else []
		for reaction in reactions:
			reaction_q += 1.0
			var built := _build_reaction_beats_from_group(parsed, reaction, reaction_q)
			var reaction_beats: Array = built.get("beats", [])
			for reaction_beat in reaction_beats:
				beats.append(reaction_beat)
			reaction_q = float(built.get("last_q", reaction_q))
			final_q = maxf(final_q, reaction_q)
			_debug_log_reaction("inserted ranged reaction beat strike=%d q=%.2f kind=%s" % [
				i,
				reaction_q,
				String(reaction.get("kind", &"unknown")),
			])

		if !reactions.is_empty():
			# Ranged attacks normally let the next fire cue start on the previous impact beat.
			# After-strike reactions need their own beat plus a clean next-fire beat afterward.
			reaction_shift_q += (reaction_q - impact_q) + 0.5

	var clear_q := final_q + _tail_gap_q_for_attack(analysis)
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, analysis.attacker_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, analysis.attacker_id, trailing, layout_orders))
	return _sort_beats(beats)


func _build_reaction_beats_from_group(parsed_parent: Dictionary, reaction: Dictionary, beat_q: float) -> Dictionary:
	var kind: StringName = reaction.get("kind", &"")
	match kind:
		&"summon":
			var beat := _make_reaction_summon_beat(beat_q, reaction.get("events", []))
			return {
				"beats": [beat],
				"last_q": beat_q,
			}
		&"attack":
			var events: Array[BattleEvent] = parsed_parent.get("source_events", [])
			var scope_ranges: Dictionary = parsed_parent.get("scope_ranges", {})
			var nested_scope_id := int(reaction.get("scope_id", 0))
			var nested := _parse_attack_scope(events, scope_ranges, nested_scope_id)
			if nested.is_empty():
				var fallback_beat := TurnBeat.new()
				fallback_beat.beat_q = beat_q
				fallback_beat.label = "reaction_attack_fallback"
				for event in reaction.get("events", []):
					fallback_beat.events.append(event)
				_debug_log_reaction("fallback nested attack q=%.2f events=%s" % [
					beat_q,
					_debug_event_list_summary(reaction.get("events", [])),
				])
				return {
					"beats": [fallback_beat],
					"last_q": beat_q,
				}

			nested["scope_ranges"] = scope_ranges
			nested["source_events"] = events
			return _build_compact_reaction_attack_beats(nested, beat_q)
		&"status":
			var reaction_events: Array[BattleEvent] = reaction.get("events", [])
			var has_status := false
			for event in reaction_events:
				if event != null and (
					int(event.type) == int(BattleEvent.Type.STATUS)
					or int(event.type) == int(BattleEvent.Type.STATUS_CHANGED)
				):
					has_status = true
					break
			var beat := _make_reaction_status_beat(beat_q, reaction_events) if has_status else _make_reaction_draw_beat(beat_q, reaction_events)
			return {
				"beats": [beat],
				"last_q": beat_q,
			}
		_:
			var generic_beat := TurnBeat.new()
			generic_beat.beat_q = beat_q
			generic_beat.label = "reaction_generic"
			for event in reaction.get("events", []):
				generic_beat.events.append(event)
			return {
				"beats": [generic_beat],
				"last_q": beat_q,
			}


func _build_compact_reaction_attack_beats(parsed: Dictionary, beat_q: float) -> Dictionary:
	var beats: Array[TurnBeat] = []
	var analysis: AttackAnalysis = parsed.get("analysis", null)
	if analysis == null:
		return {
			"beats": beats,
			"last_q": beat_q,
		}

	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "reaction_attack"

	var focus_beat := _make_basic_focus_beat(beat_q, analysis.attacker_id, _collect_all_attack_targets(analysis))
	for order in focus_beat.orders:
		beat.orders.append(order)

	if analysis.attack_mode == int(Attack.Mode.RANGED):
		beat.orders.append(_make_ranged_fire_order(analysis, 0))
	else:
		var strike_order := MeleeStrikePresentationOrder.new()
		strike_order.kind = PresentationOrder.Kind.MELEE_STRIKE
		strike_order.actor_id = analysis.attacker_id
		strike_order.target_ids = _collect_all_attack_targets(analysis)
		strike_order.visual_sec = 0.22
		strike_order.strike_index = 0
		strike_order.strikes_total = maxi(analysis.strike_count, 1)
		strike_order.total_hit_count = maxi(_count_total_hits(analysis), 1)
		strike_order.has_lethal = !analysis.lethal_indices.is_empty()
		beat.orders.append(strike_order)

	var direct_events_by_strike: Array = parsed.get("direct_events_by_strike", [])
	for i in range(mini(direct_events_by_strike.size(), analysis.strikes.size())):
		var strike_events: Array[BattleEvent] = direct_events_by_strike[i]
		for order in _make_impact_orders_for_strike(analysis, i, strike_events):
			beat.orders.append(order)
		for event in strike_events:
			beat.events.append(event)

	beats.append(beat)
	var final_q := beat_q

	var reactions_by_strike: Array = parsed.get("reactions_by_strike", [])
	for i in range(reactions_by_strike.size()):
		var reactions: Array = reactions_by_strike[i]
		for reaction in reactions:
			final_q += 1.0
			var built := _build_reaction_beats_from_group(parsed, reaction, final_q)
			var reaction_beats: Array[TurnBeat] = built.get("beats", [])
			for reaction_beat in reaction_beats:
				beats.append(reaction_beat)
			final_q = float(built.get("last_q", final_q))
			_debug_log_reaction("inserted nested reaction beat q=%.2f kind=%s" % [
				final_q,
				String(reaction.get("kind", &"unknown")),
			])

	return {
		"beats": beats,
		"last_q": final_q,
	}


func _make_reaction_summon_beat(beat_q: float, summon_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "reaction_summon"
	_tag_beat(beat, [&"reaction", &"summon_reaction"])
	var summoned_events: Array[BattleEvent] = []
	var status_events: Array[BattleEvent] = []
	for event in summon_events:
		if event == null:
			continue
		match int(event.type):
			BattleEvent.Type.SUMMONED:
				summoned_events.append(event)
			BattleEvent.Type.STATUS:
				status_events.append(event)

	var actor_id := _find_source_actor_id(summoned_events, _find_source_actor_id(status_events))

	var windup := _make_summon_windup_beat(beat_q, actor_id, summoned_events)
	for order in windup.orders:
		beat.orders.append(order)

	var pop := _make_summon_pop_beat(beat_q, actor_id, summoned_events)
	for order in pop.orders:
		beat.orders.append(order)
	for event in pop.events:
		beat.events.append(event)

	for event in summon_events:
		if event == null:
			continue
		if !beat.events.has(event):
			beat.events.append(event)

	return beat


func _make_reaction_status_beat(beat_q: float, reaction_events: Array[BattleEvent]) -> TurnBeat:
	var status_events: Array[BattleEvent] = []
	for event in reaction_events:
		if event != null and (
			int(event.type) == int(BattleEvent.Type.STATUS)
			or int(event.type) == int(BattleEvent.Type.STATUS_CHANGED)
		):
			status_events.append(event)

	var actor_id := _find_source_actor_id(status_events)
	var beat := _make_compact_status_beat(beat_q, actor_id, status_events)
	beat.label = "reaction_status"
	_tag_beat(beat, [&"reaction", &"status_followup_reaction"])
	return beat


func _make_reaction_draw_beat(beat_q: float, reaction_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "reaction_draw"
	_tag_beat(beat, [&"reaction", &"draw_followup_reaction"])

	for event in reaction_events:
		if event == null or int(event.type) != int(BattleEvent.Type.DRAW_CARDS):
			continue
		beat.events.append(event)

	return beat


func _split_attack_events(events: Array[BattleEvent]) -> Dictionary:
	var by_strike: Array[Array] = []
	var leading: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []
	var final_strike_events: Array[BattleEvent] = []
	var saw_first_strike := false

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
				BattleEvent.Type.MODIFY_BATTLE_CARD, \
				BattleEvent.Type.STATUS, \
				BattleEvent.Type.REMOVED:
					arr.append(e)
		by_strike.append(arr)

	for e in events:
		if e == null:
			continue

		if _is_attack_chain_marker_event_type(int(e.type)):
			saw_first_strike = true
			continue

		if !saw_first_strike:
			match int(e.type):
				BattleEvent.Type.STATUS, \
				BattleEvent.Type.STATUS_CHANGED, \
				BattleEvent.Type.SET_INTENT, \
				BattleEvent.Type.TURN_STATUS, \
				BattleEvent.Type.MANA, \
				BattleEvent.Type.HEAL_APPLIED, \
				BattleEvent.Type.CHANGE_MAX_HEALTH, \
				BattleEvent.Type.MODIFY_BATTLE_CARD, \
				BattleEvent.Type.MOVED:
					leading.append(e)
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
		"leading": leading,
		"by_strike": by_strike,
		"trailing": trailing,
	}


func _build_melee_attack_beats(analysis: AttackAnalysis, turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_attack_events(turn_events)
	var leading: Array[BattleEvent] = split["leading"]
	var by_strike: Array = split["by_strike"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var group_index := _find_group_index(turn_events)

	var focus_beat := _make_focus_beat(0.0, analysis)
	for e in leading:
		focus_beat.events.append(e)
	for layout_order in _find_pre_attack_group_layouts(turn_events, group_index):
		focus_beat.orders.append(layout_order)
	beats.append(focus_beat)
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
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, analysis.attacker_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, analysis.attacker_id, trailing, layout_orders))

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
	var leading: Array[BattleEvent] = split["leading"]
	var by_strike: Array = split["by_strike"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var group_index := _find_group_index(turn_events)

	var focus_beat := _make_focus_beat(0.0, analysis)
	for e in leading:
		focus_beat.events.append(e)
	for layout_order in _find_pre_attack_group_layouts(turn_events, group_index):
		focus_beat.orders.append(layout_order)
	beats.append(focus_beat)
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

		_add_order_to_beat_array(
			beats,
			fire_q,
			_make_focus_order(analysis.attacker_id, _targets_for_focus_strike(analysis, i), 0.20)
		)
		_add_order_to_beat_array(beats, fire_q, _make_ranged_fire_order(analysis, i))

		var impact_orders := _make_impact_orders_for_strike(analysis, i, strike_events)
		_add_orders_to_beat_array(beats, impact_q, impact_orders)
		_add_events_to_beat_array(beats, impact_q, strike_events)

		if i < n - 1 and _strike_has_early_lethal(analysis, i):
			lethal_shift_q += 0.5

	var last_impact_q := fire_start_q + 0.5 * float(n - 1) + lethal_shift_q + 0.5
	var clear_q := last_impact_q + _tail_gap_q_for_attack(analysis)
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, analysis.attacker_id, turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)
	beats.append(_make_clear_focus_beat(clear_q, analysis.attacker_id, trailing, layout_orders))

	return _sort_beats(beats)


func _make_focus_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "focus"
	_tag_beat(beat, [&"focus"])

	beat.orders.append(_make_focus_order(
		analysis.attacker_id,
		_targets_for_focus_strike(analysis, 0),
		0.35
	))
	return beat


func _make_clear_focus_beat(
	beat_q: float,
	actor_id: int,
	trailing: Array[BattleEvent],
	layout_orders: Array[GroupLayoutPresentationOrder] = []
) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "clear_focus"
	_tag_beat(beat, [&"clear_focus"])

	var o := ClearFocusPresentationOrder.new()
	o.kind = PresentationOrder.Kind.CLEAR_FOCUS
	o.actor_id = actor_id
	o.visual_sec = 0.30
	beat.orders.append(o)

	for layout_order in layout_orders:
		if layout_order != null:
			beat.orders.append(layout_order)

	for e in trailing:
		beat.events.append(e)

	return beat


func _make_generic_removal_beat(beat_q: float, actor_id: int, removal_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "generic_removals"

	for order in _make_generic_removal_orders(actor_id, removal_events):
		beat.orders.append(order)

	for e in removal_events:
		beat.events.append(e)

	return beat


func _make_generic_removal_orders(actor_id: int, removal_events: Array[BattleEvent]) -> Array[PresentationOrder]:
	var out: Array[PresentationOrder] = []

	for e in removal_events:
		if e == null or e.data == null:
			continue

		if int(e.type) == int(BattleEvent.Type.REMOVED):
			out.append(_make_removal_presentation_order(actor_id, e))

	return out



func _make_melee_windup_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "melee_windup"
	_tag_beat(beat, [&"windup"])

	var o := MeleeWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.MELEE_WINDUP
	o.actor_id = analysis.attacker_id
	o.target_ids = _targets_for_focus_strike(analysis, 0)
	o.visual_sec = 0.20
	o.strike_count = analysis.strike_count
	o.total_hit_count = _count_total_hits(analysis)

	beat.orders.append(o)
	return beat


func _make_melee_strike_order(
	analysis: AttackAnalysis,
	strike_index: int,
	override_targets := []
) -> MeleeStrikePresentationOrder:
	var strike := analysis.strikes[strike_index]
	return _make_melee_strike_order_from_info(analysis, strike, strike_index, override_targets)


func _make_melee_strike_order_from_info(
	analysis: AttackAnalysis,
	strike: StrikePresentationInfo,
	strike_index: int,
	override_targets := []
) -> MeleeStrikePresentationOrder:
	if strike == null:
		return MeleeStrikePresentationOrder.new()

	var o := MeleeStrikePresentationOrder.new()
	o.kind = PresentationOrder.Kind.MELEE_STRIKE
	o.actor_id = analysis.attacker_id
	o.target_ids = override_targets.duplicate() if !override_targets.is_empty() else strike.target_ids.duplicate()
	o.visual_sec = 0.22
	o.strike_index = strike_index
	o.strikes_total = analysis.strike_count
	o.total_hit_count = strike.hit_count
	o.has_lethal = strike.has_lethal_hit
	o.chained_from_previous = strike.chained_from_previous
	o.origin_strike_index = int(strike.origin_strike_index if strike.origin_strike_index >= 0 else strike_index)
	o.chain_source_target_id = int(strike.chain_source_target_id)
	return o


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

	beat.orders.append(_make_focus_order(
		analysis.attacker_id,
		_targets_for_focus_strike(analysis, strike_index),
		0.20
	))

	beat.orders.append(_make_melee_strike_order(analysis, strike_index))

	for impact_order in _make_impact_orders_for_strike(analysis, strike_index, strike_events):
		beat.orders.append(impact_order)

	for e in strike_events:
		beat.events.append(e)

	return beat



func _make_ranged_windup_beat(beat_q: float, analysis: AttackAnalysis) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "ranged_windup"
	_tag_beat(beat, [&"windup"])

	var o := RangedWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.RANGED_WINDUP
	o.actor_id = analysis.attacker_id
	o.target_ids = _targets_for_focus_strike(analysis, 0)
	o.visual_sec = 0.15
	o.strike_count = analysis.strike_count
	o.total_hit_count = _count_total_hits(analysis)

	beat.orders.append(o)
	return beat


func _make_ranged_fire_order(analysis: AttackAnalysis, strike_index: int) -> RangedFirePresentationOrder:
	var strike := analysis.strikes[strike_index]
	return _make_ranged_fire_order_from_info(analysis, strike, strike_index)


func _make_ranged_fire_order_from_info(
	analysis: AttackAnalysis,
	strike: StrikePresentationInfo,
	strike_index: int
) -> RangedFirePresentationOrder:
	if strike == null:
		return RangedFirePresentationOrder.new()

	var o := RangedFirePresentationOrder.new()
	o.kind = PresentationOrder.Kind.RANGED_FIRE
	o.actor_id = analysis.attacker_id
	o.target_ids = strike.target_ids
	o.visual_sec = 0.18
	o.strike_index = strike_index
	o.strikes_total = analysis.strike_count
	o.total_hit_count = strike.hit_count
	o.has_lethal = strike.has_lethal_hit
	o.projectile_scene_path = analysis.projectile_scene_path
	o.chained_from_previous = strike.chained_from_previous
	o.origin_strike_index = int(strike.origin_strike_index if strike.origin_strike_index >= 0 else strike_index)
	o.chain_source_target_id = int(strike.chain_source_target_id)
	o.has_chain_continuation = _strike_has_chain_continuation(analysis, strike_index)

	return o


func _make_ranged_cleave_followthrough_order_from_info(
	analysis: AttackAnalysis,
	strike: StrikePresentationInfo,
	strike_index: int
) -> RangedFirePresentationOrder:
	var o := _make_ranged_fire_order_from_info(analysis, strike, strike_index)
	o.kind = PresentationOrder.Kind.RANGED_CLEAVE
	o.chained_from_previous = true
	o.has_chain_continuation = false
	return o


func _make_impact_orders_for_strike(
	analysis: AttackAnalysis,
	strike_index: int,
	strike_events: Array[BattleEvent] = []
) -> Array[PresentationOrder]:
	if strike_index < 0 or strike_index >= analysis.strikes.size():
		return []

	var strike := analysis.strikes[strike_index]
	return _make_impact_orders_for_info(analysis, strike, strike_index, strike_events)


func _make_impact_orders_for_info(
	analysis: AttackAnalysis,
	strike: StrikePresentationInfo,
	strike_index: int,
	strike_events: Array[BattleEvent] = []
) -> Array[PresentationOrder]:
	var out: Array[PresentationOrder] = []
	if strike == null:
		return out

	for h in strike.hits:
		if h != null:
			out.append(_make_single_impact_order(analysis, strike, strike_index, h, false))

	for h in strike.recoil_hits:
		if h != null:
			out.append(_make_single_impact_order(analysis, strike, strike_index, h, true))

	for e in strike_events:
		if e == null or e.data == null:
			continue

		match int(e.type):
			BattleEvent.Type.REMOVED:
				out.append(_make_removal_presentation_order(analysis.attacker_id, e))

	return out


func _make_single_impact_order(
	analysis: AttackAnalysis,
	strike: StrikePresentationInfo,
	strike_index: int,
	h: HitPresentationInfo,
	is_recoil: bool
) -> ImpactPresentationOrder:
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
	o.chained_from_previous = strike.chained_from_previous and !is_recoil
	o.is_self_recoil = is_recoil
	if is_recoil:
		o.meta[Keys.SELF_RECOIL] = true
	return o


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


func _actor_dies_on_own_turn(actor_id: int, events: Array[BattleEvent]) -> bool:
	if actor_id <= 0:
		return false

	for e in events:
		if e == null or e.data == null:
			continue

		match int(e.type):
			BattleEvent.Type.REMOVED:
				if int(e.data.get(Keys.TARGET_ID, 0)) == actor_id:
					return true

	return false


func _enforce_min_clear_focus_q_for_self_death(clear_q: float, actor_id: int, events: Array[BattleEvent]) -> float:
	if !_actor_dies_on_own_turn(actor_id, events):
		return clear_q
	return maxf(clear_q, 3.0)


func _build_generic_beats(events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var actor_id := _find_actor_id(events)
	var group_index := _find_group_index(events)
	var split := _split_generic_events(events)
	var removal_events: Array[BattleEvent] = split["removal_events"]
	var trailing: Array[BattleEvent] = split["trailing"]

	var layout_orders := _find_post_action_group_layouts(events, group_index)

	if actor_id > 0:
		beats.append(_make_basic_focus_beat(0.0, actor_id, _collect_targets_from_events(events)))
		var clear_q := 2.0 if !removal_events.is_empty() else 1.0
		clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, actor_id, events)
		if !removal_events.is_empty():
			beats.append(_make_generic_removal_beat(1.0, actor_id, removal_events))
		beats.append(_make_clear_focus_beat(clear_q, actor_id, trailing, layout_orders))
	else:
		var b := TurnBeat.new()
		b.beat_q = 0.0
		b.label = "generic_removals" if !removal_events.is_empty() else "generic"

		for order in _make_generic_removal_orders(actor_id, removal_events):
			b.orders.append(order)

		for e in removal_events:
			b.events.append(e)

		beats.append(b)

		if !layout_orders.is_empty() or !trailing.is_empty():
			var trailing_beat := TurnBeat.new()
			trailing_beat.beat_q = 1.0 if !removal_events.is_empty() else 0.0
			trailing_beat.label = "generic"

			for layout_order in layout_orders:
				if layout_order != null:
					trailing_beat.orders.append(layout_order)

			for e in trailing:
				trailing_beat.events.append(e)
			beats.append(trailing_beat)

	return beats


func _split_generic_events(events: Array[BattleEvent]) -> Dictionary:
	var removal_events: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []

	for e in events:
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.REMOVED:
				removal_events.append(e)

			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED, \
			BattleEvent.Type.STATUS, \
			BattleEvent.Type.SUMMONED:
				trailing.append(e)

	return {
		"removal_events": removal_events,
		"trailing": trailing,
	}


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
	var removal_events: Array[BattleEvent] = []
	var trailing: Array[BattleEvent] = []

	for e in events:
		if e == null:
			continue

		match int(e.type):
			BattleEvent.Type.STATUS:
				status_events.append(e)

			BattleEvent.Type.REMOVED:
				removal_events.append(e)

			BattleEvent.Type.SET_INTENT, \
			BattleEvent.Type.TURN_STATUS, \
			BattleEvent.Type.MOVED:
				trailing.append(e)

	return {
		"status_events": status_events,
		"removal_events": removal_events,
		"trailing": trailing,
	}


func _build_summon_beats(turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_summon_events(turn_events)
	var summon_events: Array[BattleEvent] = split["summon_events"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var actor_id := _find_actor_id(turn_events)
	var group_index := _find_group_index(turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)

	if summon_events.is_empty():
		return _build_generic_beats(turn_events)

	beats.append(_make_basic_focus_beat(0.0, actor_id, _collect_targets_from_summon_events(summon_events)))
	beats.append(_make_summon_windup_beat(1.0, actor_id, summon_events))
	beats.append(_make_summon_pop_beat(2.0, actor_id, summon_events))
	var clear_q := _enforce_min_clear_focus_q_for_self_death(3.0, actor_id, turn_events)
	beats.append(_make_clear_focus_beat(clear_q, actor_id, trailing, layout_orders))

	return beats




func _build_status_beats(turn_events: Array[BattleEvent]) -> Array[TurnBeat]:
	var beats: Array[TurnBeat] = []
	var split := _split_status_events(turn_events)
	var status_events: Array[BattleEvent] = split["status_events"]
	var removal_events: Array[BattleEvent] = split["removal_events"]
	var trailing: Array[BattleEvent] = split["trailing"]
	var actor_id := _find_actor_id(turn_events)
	var group_index := _find_group_index(turn_events)
	var layout_orders := _find_post_action_group_layouts(turn_events, group_index)

	if status_events.is_empty():
		return _build_generic_beats(turn_events)

	var targets := _collect_targets_from_events(status_events)

	beats.append(_make_basic_focus_beat(0.0, actor_id, targets))
	beats.append(_make_status_windup_beat(1.0, actor_id, targets, &"full_status", false, 0.16))
	beats.append(_make_status_pop_beat(2.0, actor_id, status_events, &"full_status", false, 0.18))
	var clear_q := 4.0 if !removal_events.is_empty() else 3.0
	clear_q = _enforce_min_clear_focus_q_for_self_death(clear_q, actor_id, turn_events)
	if !removal_events.is_empty():
		beats.append(_make_generic_removal_beat(3.0, actor_id, removal_events))
	beats.append(_make_clear_focus_beat(clear_q, actor_id, trailing, layout_orders))

	return beats


func _make_basic_focus_beat(beat_q: float, actor_id: int, target_ids: Array[int]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "focus"
	_tag_beat(beat, [&"focus"])

	beat.orders.append(_make_focus_order(actor_id, target_ids, 0.35))
	return beat


func _collect_targets_from_summon_events(events: Array[BattleEvent]) -> Array[int]:
	var out := _collect_targets_from_events(events)
	if !out.is_empty():
		return out

	var seen := {}
	for e in events:
		if e == null or e.data == null:
			continue
		var summoned_id := int(e.data.get(Keys.SUMMONED_ID, 0))
		if summoned_id <= 0 or seen.has(summoned_id):
			continue
		seen[summoned_id] = true
		out.append(summoned_id)
	return out


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


func _make_summon_pop_beat(
	beat_q: float,
	actor_id: int,
	summon_events: Array[BattleEvent],
	embedded_status_events: Array[BattleEvent] = []
) -> TurnBeat:
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
		beat.events.append(e)

	for e in embedded_status_events:
		if e == null or beat.events.has(e):
			continue
		beat.events.append(e)

	return beat


func _make_status_windup_beat(
	beat_q: float,
	actor_id: int,
	target_ids: Array[int],
	presentation_mode: StringName = &"full_status",
	embedded_in_summon: bool = false,
	visual_sec: float = 0.16
) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "status_windup"

	var o := StatusWindupPresentationOrder.new()
	o.kind = PresentationOrder.Kind.STATUS_WINDUP
	o.actor_id = actor_id
	o.target_ids = target_ids
	o.visual_sec = visual_sec
	o.presentation_mode = presentation_mode
	o.embedded_in_summon = embedded_in_summon

	beat.orders.append(o)
	return beat


func _make_status_pop_beat(
	beat_q: float,
	actor_id: int,
	status_events: Array[BattleEvent],
	presentation_mode: StringName = &"full_status",
	embedded_in_summon: bool = false,
	visual_sec: float = 0.18
) -> TurnBeat:
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
		o.visual_sec = visual_sec
		o.source_id = int(e.data.get(Keys.SOURCE_ID, 0))
		o.target_id = int(e.data.get(Keys.TARGET_ID, 0))
		o.status_id = e.data.get(Keys.STATUS_ID, &"")
		o.pending = bool(e.data.get(Keys.AFTER_PENDING, e.data.get(Keys.STATUS_PENDING, false)))
		o.op = int(e.data.get(Keys.OP, 0))
		o.intensity = int(e.data.get(Keys.AFTER_INTENSITY, e.data.get(Keys.INTENSITY, 0)))
		o.turns_duration = int(e.data.get(Keys.AFTER_DURATION, e.data.get(Keys.DURATION, 0)))
		o.presentation_mode = presentation_mode
		o.embedded_in_summon = embedded_in_summon

		beat.orders.append(o)
		beat.events.append(e)

	return beat


func _make_compact_status_beat(beat_q: float, actor_id: int, status_events: Array[BattleEvent]) -> TurnBeat:
	var beat := TurnBeat.new()
	beat.beat_q = beat_q
	beat.label = "status_followup"
	_tag_beat(beat, [&"status_followup"])

	var targets := _collect_targets_from_events(status_events)
	var windup := _make_status_windup_beat(beat_q, actor_id, targets, &"compact_followup", false, 0.10)
	for order in windup.orders:
		beat.orders.append(order)

	var pop := _make_status_pop_beat(beat_q, actor_id, status_events, &"compact_followup", false, 0.12)
	for order in pop.orders:
		beat.orders.append(order)
	for event in pop.events:
		beat.events.append(event)

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


func _find_source_actor_id(events: Array[BattleEvent], fallback := 0) -> int:
	for event in events:
		if event == null or event.data == null:
			continue
		if event.data.has(Keys.SOURCE_ID):
			var source_id := int(event.data.get(Keys.SOURCE_ID, 0))
			if source_id > 0:
				return source_id
		if event.data.has(Keys.ACTOR_ID):
			var actor_id := int(event.data.get(Keys.ACTOR_ID, 0))
			if actor_id > 0:
				return actor_id
	return int(fallback)


func _make_focus_order(actor_id: int, target_ids: Array[int], visual_sec: float = 0.35) -> FocusPresentationOrder:
	var o := FocusPresentationOrder.new()
	o.kind = PresentationOrder.Kind.FOCUS
	o.actor_id = actor_id
	o.target_ids = target_ids.duplicate()
	o.visual_sec = visual_sec
	return o


func _tag_beat(beat: TurnBeat, tags: Array) -> void:
	if beat == null:
		return

	for tag in tags:
		var name := StringName(tag)
		if !beat.tags.has(name):
			beat.tags.append(name)


func _targets_for_focus_strike(analysis: AttackAnalysis, strike_index: int) -> Array[int]:
	if analysis == null or analysis.strikes.is_empty():
		return []

	var safe_index := clampi(strike_index, 0, analysis.strikes.size() - 1)
	var strike: StrikePresentationInfo = analysis.strikes[safe_index]
	if strike != null and !strike.target_ids.is_empty():
		return strike.target_ids.duplicate()

	return _collect_all_attack_targets(analysis)


func _strike_has_chain_continuation(analysis: AttackAnalysis, strike_index: int) -> bool:
	if analysis == null:
		return false
	if strike_index < 0 or strike_index >= analysis.strikes.size():
		return false
	var strike: StrikePresentationInfo = analysis.strikes[strike_index]
	if strike == null:
		return false
	return bool(strike.has_cleave)


func _find_post_action_group_layouts(
	events: Array[BattleEvent],
	fallback_group_index: int
) -> Array[GroupLayoutPresentationOrder]:
	return _make_group_layout_orders_from_events(events, fallback_group_index)


func _make_group_layout_orders_from_events(
	events: Array[BattleEvent],
	fallback_group_index: int
) -> Array[GroupLayoutPresentationOrder]:
	var latest_by_group := {}

	for e in events:
		if e == null or e.data == null:
			continue

		match int(e.type):
			BattleEvent.Type.SUMMONED, \
			BattleEvent.Type.REMOVED, \
			BattleEvent.Type.MOVED:
				if !e.data.has(Keys.AFTER_ORDER_IDS):
					continue
				var latest_order: PackedInt32Array = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
				if latest_order.is_empty():
					continue
				var latest_group := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
				if latest_group == -1:
					latest_group = fallback_group_index
				if latest_group == -1:
					continue
				latest_by_group[latest_group] = {
					"seq": int(e.seq),
					"order_ids": latest_order,
				}

	return _build_group_layout_orders_from_map(latest_by_group)


func _build_group_layout_orders_from_map(latest_by_group: Dictionary) -> Array[GroupLayoutPresentationOrder]:
	if latest_by_group.is_empty():
		return []

	var sorted_groups: Array = latest_by_group.keys()
	sorted_groups.sort_custom(func(a, b):
		return int(latest_by_group[a].get("seq", -1)) < int(latest_by_group[b].get("seq", -1))
	)

	var out: Array[GroupLayoutPresentationOrder] = []
	for group_key in sorted_groups:
		var info: Dictionary = latest_by_group[group_key]
		var o := GroupLayoutPresentationOrder.new()
		o.kind = PresentationOrder.Kind.GROUP_LAYOUT
		o.group_index = int(group_key)
		o.order_ids = info.get("order_ids", PackedInt32Array())
		o.animate = true
		o.visual_sec = 0.12
		out.append(o)

	return out


func _find_pre_attack_group_layouts(
	events: Array[BattleEvent],
	fallback_group_index: int
) -> Array[GroupLayoutPresentationOrder]:
	# Find the seq of the first STRIKE/CLEAVE marker; MOVED events before it are pre-attack.
	var cutoff_seq := -1
	for e in events:
		if e == null:
			continue
		if _is_attack_chain_marker_event_type(int(e.type)):
			cutoff_seq = int(e.seq)
			break

	if cutoff_seq < 0:
		return []

	# Collect the latest MOVED event per group that occurs before the first strike.
	var latest_by_group := {}
	for e in events:
		if e == null or e.data == null:
			continue
		if int(e.seq) >= cutoff_seq:
			continue
		if int(e.type) != BattleEvent.Type.MOVED:
			continue
		if !e.data.has(Keys.AFTER_ORDER_IDS):
			continue
		var order_ids: PackedInt32Array = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
		if order_ids.is_empty():
			continue
		var group := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
		if group == -1:
			group = fallback_group_index
		if group == -1:
			continue
		if !latest_by_group.has(group) or int(e.seq) > int(latest_by_group[group].get("seq", -1)):
			latest_by_group[group] = {
				"seq": int(e.seq),
				"order_ids": order_ids,
			}

	return _build_group_layout_orders_from_map(latest_by_group)


func _place_delayed_summon_reserve_release_events(beats: Array[TurnBeat], turn_events: Array[BattleEvent]) -> void:
	if beats.is_empty() or turn_events.is_empty():
		return

	var assigned_seqs := {}
	for beat in beats:
		if beat == null:
			continue
		for event in beat.events:
			var be := event as BattleEvent
			if be == null:
				continue
			assigned_seqs[int(be.seq)] = true

	for event in turn_events:
		var reserve_event := event as BattleEvent
		if reserve_event == null:
			continue
		if int(reserve_event.type) != int(BattleEvent.Type.SUMMON_RESERVE_RELEASED):
			continue
		if bool(assigned_seqs.get(int(reserve_event.seq), false)):
			continue
		if reserve_event.data == null:
			continue

		var summoned_id := int(reserve_event.data.get(Keys.SUMMONED_ID, 0))
		if summoned_id <= 0:
			continue

		var anchor_beat := _find_matching_removal_beat_for_summoned(beats, summoned_id, int(reserve_event.seq))
		if anchor_beat == null:
			continue

		var release_beat := _find_or_make_beat(beats, float(anchor_beat.beat_q) + 0.5, "summon_reserve_release")
		release_beat.events.append(reserve_event)
		assigned_seqs[int(reserve_event.seq)] = true


func _find_matching_removal_beat_for_summoned(beats: Array[TurnBeat], summoned_id: int, release_seq: int) -> TurnBeat:
	var best_prior_beat: TurnBeat = null
	var best_prior_seq := -2147483648
	var fallback_beat: TurnBeat = null
	var fallback_seq := -2147483648

	for beat in beats:
		if beat == null:
			continue
		for event in beat.events:
			var be := event as BattleEvent
			if be == null or be.data == null:
				continue
			match int(be.type):
				BattleEvent.Type.REMOVED:
					if int(be.data.get(Keys.TARGET_ID, 0)) != int(summoned_id):
						continue
					var event_seq := int(be.seq)
					if event_seq <= int(release_seq) and event_seq > best_prior_seq:
						best_prior_seq = event_seq
						best_prior_beat = beat
					if event_seq > fallback_seq:
						fallback_seq = event_seq
						fallback_beat = beat

	if best_prior_beat != null:
		return best_prior_beat
	return fallback_beat


func _ensure_lossless_beats(action_kind: StringName, turn_events: Array[BattleEvent], beats: Array[TurnBeat]) -> Array[TurnBeat]:
	var out := beats.duplicate()
	if out.is_empty():
		var fallback := TurnBeat.new()
		fallback.beat_q = 0.0
		fallback.label = "fallback_raw"
		out.append(fallback)

	_place_delayed_summon_reserve_release_events(out, turn_events)

	var assigned_seqs: Dictionary = {}
	for beat in out:
		if beat == null:
			continue
		for event in beat.events:
			var be := event as BattleEvent
			if be == null:
				continue
			var seq := int(be.seq)
			if assigned_seqs.has(seq):
				push_warning("TurnTimelineCompiler: event seq=%d assigned multiple times in action_kind=%s" % [seq, String(action_kind)])
			else:
				assigned_seqs[seq] = true

	for event in turn_events:
		var be := event as BattleEvent
		if be == null:
			continue
		if _is_structural_ignored_event(be):
			continue
		if assigned_seqs.has(int(be.seq)):
			continue

		var fallback_beat := _choose_fallback_beat_for_event(out, be)
		if fallback_beat == null:
			fallback_beat = TurnBeat.new()
			fallback_beat.beat_q = 0.0
			fallback_beat.label = "fallback_raw"
			out.append(fallback_beat)

		fallback_beat.events.append(be)
		assigned_seqs[int(be.seq)] = true
		if _is_known_reaction_event_type(be):
			_debug_log_reaction("fallback placement type=%s seq=%d action_kind=%s beat=%s" % [
				_event_type_name(int(be.type)),
				int(be.seq),
				String(action_kind),
				String(fallback_beat.label),
			])
		push_warning(
			"TurnTimelineCompiler: fallback placement for event type=%s seq=%d action_kind=%s beat=%s" % [
				_event_type_name(int(be.type)),
				int(be.seq),
				String(action_kind),
				String(fallback_beat.label),
			]
		)

	return _sort_beats(out)


func _debug_log_reaction(message: String) -> void:
	pass
	#print("[VIEW REACTION] %s" % message)


func _debug_event_list_summary(events: Array) -> String:
	if events == null or events.is_empty():
		return "[]"

	var parts: Array[String] = []
	var max_n := mini(events.size(), 6)
	for i in range(max_n):
		var event := events[i] as BattleEvent
		if event == null:
			parts.append("<null>")
			continue
		parts.append("%s#%d" % [_event_type_name(int(event.type)), int(event.seq)])
	if events.size() > max_n:
		parts.append("... +%d more" % int(events.size() - max_n))
	return "[" + ", ".join(parts) + "]"


func _is_known_reaction_event_type(event: BattleEvent) -> bool:
	if event == null:
		return false
	match int(event.type):
		BattleEvent.Type.SUMMONED, \
		BattleEvent.Type.STATUS, \
		BattleEvent.Type.DRAW_CARDS, \
		BattleEvent.Type.DAMAGE_APPLIED, \
		BattleEvent.Type.REMOVED, \
		BattleEvent.Type.STRIKE, \
		BattleEvent.Type.CLEAVE:
			return true
	return false


func _make_removal_presentation_order(actor_id: int, event: BattleEvent):
	var order = RemovalPresentationOrder.new()
	order.kind = PresentationOrder.Kind.REMOVAL
	order.actor_id = actor_id
	order.target_id = int(event.data.get(Keys.TARGET_ID, 0))
	order.group_index = int(event.data.get(Keys.GROUP_INDEX, event.group_index))
	order.after_order_ids = event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	order.removal_type = int(event.data.get(Keys.REMOVAL_TYPE, int(Removal.Type.DEATH)))
	order.visual_sec = 0.20 if int(order.removal_type) == int(Removal.Type.FADE) else 0.24
	return order


func _is_death_removal_event(event: BattleEvent) -> bool:
	if event == null or int(event.type) != int(BattleEvent.Type.REMOVED):
		return false
	if event.data == null:
		return true
	return int(event.data.get(Keys.REMOVAL_TYPE, int(Removal.Type.DEATH))) == int(Removal.Type.DEATH)


func _choose_fallback_beat_for_event(beats: Array[TurnBeat], event: BattleEvent) -> TurnBeat:
	if event == null or beats.is_empty():
		return null

	var event_seq := int(event.seq)
	var next_beat: TurnBeat = null
	var next_min_seq := 2147483647
	var prev_beat: TurnBeat = null
	var prev_max_seq := -2147483648

	for beat in beats:
		if beat == null:
			continue
		var span := _beat_event_seq_span(beat)
		if span.is_empty():
			continue

		var min_seq := int(span[0])
		var max_seq := int(span[1])

		if event_seq <= min_seq and min_seq < next_min_seq:
			next_min_seq = min_seq
			next_beat = beat

		if max_seq <= event_seq and max_seq > prev_max_seq:
			prev_max_seq = max_seq
			prev_beat = beat

	if next_beat != null:
		return next_beat
	if prev_beat != null:
		return prev_beat
	return beats[0]


func _beat_event_seq_span(beat: TurnBeat) -> Array[int]:
	if beat == null or beat.events.is_empty():
		return []

	var min_seq := 2147483647
	var max_seq := -2147483648

	for event in beat.events:
		var be := event as BattleEvent
		if be == null:
			continue
		var seq := int(be.seq)
		min_seq = mini(min_seq, seq)
		max_seq = maxi(max_seq, seq)

	if min_seq == 2147483647:
		return []

	return [min_seq, max_seq]


func _is_structural_ignored_event(event: BattleEvent) -> bool:
	if event == null:
		return true

	match int(event.type):
		BattleEvent.Type.SCOPE_BEGIN, \
		BattleEvent.Type.SCOPE_END, \
		BattleEvent.Type.TURN_GROUP_BEGIN, \
		BattleEvent.Type.TURN_GROUP_END, \
		BattleEvent.Type.ACTOR_BEGIN, \
		BattleEvent.Type.ACTOR_END, \
		BattleEvent.Type.STRIKE, \
		BattleEvent.Type.CLEAVE:
			return true

	return false


func _event_type_name(event_type: int) -> String:
	if event_type >= 0 and event_type < BattleEvent.Type.keys().size():
		return BattleEvent.Type.keys()[event_type]
	return str(event_type)
