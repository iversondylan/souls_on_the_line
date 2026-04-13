extends SceneTree

class MockStatusRuntime extends SimRuntime:
	var call_count: int = 0
	var last_ctx: StatusContext = null

	func run_status_action(ctx: StatusContext) -> void:
		call_count += 1
		last_ctx = ctx

var _seq: int = 1
var _compiler := TurnTimelineCompiler.new()


func _initialize() -> void:
	var failures: Array[String] = []

	_test_two_melee_no_retarget(failures)
	_test_two_ranged_no_retarget(failures)
	_test_melee_retarget_extension(failures)
	_test_ranged_delayed_reactions_stay_on_grid(failures)
	_test_move_then_heal_packages(failures)
	_test_status_sequence_groups_targets_once(failures)
	_test_multi_target_status_package_single_slot(failures)
	_test_summon_then_status_compact(failures)
	_test_summon_then_status_separate(failures)
	_test_move_attack_status_mixed_turn(failures)
	_test_attack_then_realize_pending_statuses(failures)

	if failures.is_empty():
		print("TURN TIMELINE PACKAGE VERIFY OK")
		quit()
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _test_two_melee_no_retarget(failures: Array[String]) -> void:
	var events := _build_basic_attack_turn(Attack.Mode.MELEE, [[2], [2]], [false, false])
	var timeline := _compile_and_assert_lossless("two_melee_no_retarget", events, failures)
	_assert_beats("two_melee_no_retarget", timeline, [0.0, 1.0, 2.0, 2.5, 3.0], failures)


func _test_two_ranged_no_retarget(failures: Array[String]) -> void:
	var events := _build_basic_attack_turn(Attack.Mode.RANGED, [[2], [2]], [false, false])
	var timeline := _compile_and_assert_lossless("two_ranged_no_retarget", events, failures)
	_assert_beats("two_ranged_no_retarget", timeline, [0.0, 1.0, 1.5, 2.0, 2.5, 3.0], failures)


func _test_melee_retarget_extension(failures: Array[String]) -> void:
	var events := _build_basic_attack_turn(Attack.Mode.MELEE, [[2], [3]], [true, false])
	var timeline := _compile_and_assert_lossless("melee_retarget_extension", events, failures)
	_assert_beats("melee_retarget_extension", timeline, [0.0, 1.0, 2.0, 3.0, 4.0], failures)


func _test_ranged_delayed_reactions_stay_on_grid(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var attack_scope := 200
	var strike_scopes := [201, 202, 203]
	var reaction_scopes := [301, 302]
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id, _package_meta(actor_id, 0, &"attack")))

	events.append(_scope_begin(strike_scopes[0], attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_strike_event(actor_id, [2], Attack.Mode.RANGED, 0, 3))
	events.append(_damage_event(actor_id, 2, 10, 0, true))
	events.append(_removed_event(2))
	events.append(_scope_begin(reaction_scopes[0], strike_scopes[0], Scope.Kind.SUMMON_ACTION, actor_id))
	events.append(_summoned_event(actor_id, 5, 1, 0))
	events.append(_scope_end(reaction_scopes[0], strike_scopes[0], Scope.Kind.SUMMON_ACTION, actor_id))
	events.append(_scope_end(strike_scopes[0], attack_scope, Scope.Kind.STRIKE, actor_id))

	events.append(_scope_begin(strike_scopes[1], attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_strike_event(actor_id, [3], Attack.Mode.RANGED, 1, 3))
	events.append(_damage_event(actor_id, 3, 10, 0, true))
	events.append(_removed_event(3))
	events.append(_scope_begin(reaction_scopes[1], strike_scopes[1], Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_status_event(actor_id, 4, &"marked"))
	events.append(_scope_end(reaction_scopes[1], strike_scopes[1], Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(strike_scopes[1], attack_scope, Scope.Kind.STRIKE, actor_id))

	events.append(_scope_begin(strike_scopes[2], attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_strike_event(actor_id, [4], Attack.Mode.RANGED, 2, 3))
	events.append(_damage_event(actor_id, 4, 8, 2, false))
	events.append(_scope_end(strike_scopes[2], attack_scope, Scope.Kind.STRIKE, actor_id))

	events.append(_scope_end(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("ranged_delayed_reactions_on_grid", events, failures)
	var reaction_beats := _beats_with_tag(timeline, &"reaction")
	_assert_float_array("ranged_delayed_reactions_on_grid reaction beats", reaction_beats, [3.0, 5.0], failures)
	for beat_q in reaction_beats:
		if !is_equal_approx(beat_q, round(beat_q)):
			failures.append("ranged_delayed_reactions_on_grid: reaction beat %.2f was not on-grid" % beat_q)


func _test_move_then_heal_packages(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var move_scope := 200
	var heal_scope := 201
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(move_scope, actor_scope, Scope.Kind.MOVE, actor_id, _package_meta(actor_id, 0, &"move", false, {Keys.TARGET_ID: 2})))
	events.append(_moved_event(actor_id, 2))
	events.append(_scope_end(move_scope, actor_scope, Scope.Kind.MOVE, actor_id))
	events.append(_scope_begin(heal_scope, actor_scope, Scope.Kind.HEAL_ACTION, actor_id, _package_meta(actor_id, 1, &"heal", false, {Keys.TARGET_ID: 3})))
	events.append(_heal_event(actor_id, 3, 6))
	events.append(_scope_end(heal_scope, actor_scope, Scope.Kind.HEAL_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("move_then_heal_packages", events, failures)
	_assert_beats("move_then_heal_packages", timeline, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0], failures)


func _test_status_sequence_groups_targets_once(failures: Array[String]) -> void:
	var sequence := NPCStatusSequence.new()
	var ctx := NPCAIContext.new()
	var runtime := MockStatusRuntime.new()
	ctx.runtime = runtime
	ctx.cid = 9
	ctx.params = {
		Keys.STATUS_ID: &"weakened",
		Keys.TARGET_IDS: PackedInt32Array([2, 3]),
		Keys.STATUS_INTENSITY: 1,
		Keys.STATUS_DURATION: 1,
	}

	sequence.execute(ctx)

	if int(runtime.call_count) != 1:
		failures.append("status_sequence_groups_targets_once: expected 1 run_status_action call, got %d" % int(runtime.call_count))
		return
	if runtime.last_ctx == null:
		failures.append("status_sequence_groups_targets_once: missing grouped status context")
		return
	_assert_packed_ints(
		"status_sequence_groups_targets_once target_ids",
		runtime.last_ctx.target_ids,
		PackedInt32Array([2, 3]),
		failures
	)


func _test_multi_target_status_package_single_slot(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var status_scope := 200
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(
		status_scope,
		actor_scope,
		Scope.Kind.STATUS_ACTION,
		actor_id,
		_package_meta(actor_id, 0, &"status", false, {Keys.TARGET_IDS: PackedInt32Array([2, 3])})
	))
	events.append(_status_event(actor_id, 2, &"weakened", PackedInt32Array([2, 3])))
	events.append(_status_event(actor_id, 3, &"weakened", PackedInt32Array([2, 3])))
	events.append(_scope_end(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("multi_target_status_package_single_slot", events, failures)
	_assert_beats("multi_target_status_package_single_slot", timeline, [0.0, 1.0, 2.0, 3.0], failures)
	_assert_event_on_beat("multi_target_status_package_single_slot status on beat 2", timeline, 2.0, BattleEvent.Type.STATUS, failures, 2)


func _test_summon_then_status_compact(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var summon_scope := 200
	var status_scope := 201
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(summon_scope, actor_scope, Scope.Kind.SUMMON_ACTION, actor_id, _package_meta(actor_id, 0, &"summon")))
	events.append(_summoned_event(actor_id, 5, 1, 0))
	events.append(_scope_end(summon_scope, actor_scope, Scope.Kind.SUMMON_ACTION, actor_id))
	events.append(_scope_begin(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id, _package_meta(actor_id, 1, &"status", true, {Keys.TARGET_ID: 5})))
	events.append(_status_event(actor_id, 5, &"small"))
	events.append(_scope_end(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("summon_then_status_compact", events, failures)
	_assert_beats("summon_then_status_compact", timeline, [0.0, 1.0, 2.0, 3.0], failures)
	var beat := _find_beat(timeline, 2.0)
	_assert_event_types("summon_then_status_compact beat 2", beat, [BattleEvent.Type.SUMMONED, BattleEvent.Type.STATUS], failures)


func _test_summon_then_status_separate(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var summon_scope := 200
	var status_scope := 201
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(summon_scope, actor_scope, Scope.Kind.SUMMON_ACTION, actor_id, _package_meta(actor_id, 0, &"summon")))
	events.append(_summoned_event(actor_id, 5, 1, 0))
	events.append(_scope_end(summon_scope, actor_scope, Scope.Kind.SUMMON_ACTION, actor_id))
	events.append(_scope_begin(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id, _package_meta(actor_id, 1, &"status", false, {Keys.TARGET_ID: 5})))
	events.append(_status_event(actor_id, 5, &"small"))
	events.append(_scope_end(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("summon_then_status_separate", events, failures)
	_assert_beats("summon_then_status_separate", timeline, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0], failures)
	var summon_beat := _find_beat(timeline, 2.0)
	var status_beat := _find_beat(timeline, 4.0)
	_assert_event_types("summon_then_status_separate beat 2", summon_beat, [BattleEvent.Type.SUMMONED], failures)
	_assert_event_types("summon_then_status_separate beat 4", status_beat, [BattleEvent.Type.STATUS], failures)


func _test_move_attack_status_mixed_turn(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var move_scope := 200
	var attack_scope := 201
	var strike_scope := 211
	var status_scope := 202
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(move_scope, actor_scope, Scope.Kind.MOVE, actor_id, _package_meta(actor_id, 0, &"move", false, {Keys.TARGET_ID: 2})))
	events.append(_moved_event(actor_id, 2))
	events.append(_scope_end(move_scope, actor_scope, Scope.Kind.MOVE, actor_id))

	events.append(_scope_begin(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id, _package_meta(actor_id, 1, &"attack")))
	events.append(_scope_begin(strike_scope, attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_strike_event(actor_id, [3], Attack.Mode.MELEE, 0, 1))
	events.append(_damage_event(actor_id, 3, 8, 2, false))
	events.append(_scope_end(strike_scope, attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_scope_end(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id))

	events.append(_scope_begin(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id, _package_meta(actor_id, 2, &"status", false, {Keys.TARGET_ID: 3})))
	events.append(_status_event(actor_id, 3, &"weakened"))
	events.append(_scope_end(status_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("move_attack_status_mixed_turn", events, failures)
	_assert_beats("move_attack_status_mixed_turn", timeline, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], failures)
	_assert_tag_count("move_attack_status_mixed_turn focus count", timeline, &"focus", 1, failures)
	_assert_tag_count("move_attack_status_mixed_turn clear count", timeline, &"clear_focus", 1, failures)
	_assert_event_on_beat("move_attack_status_mixed_turn move on beat 2", timeline, 2.0, BattleEvent.Type.MOVED, failures)
	_assert_group_layout_order("move_attack_status_mixed_turn layout on beat 2", timeline, 2.0, 1, [1, 2], failures)
	var attack_impact := _find_beat(timeline, 4.0)
	if attack_impact == null or !attack_impact.tags.has(&"impact"):
		failures.append("move_attack_status_mixed_turn: expected attack impact at beat 4.0")
	_assert_event_on_beat("move_attack_status_mixed_turn attack damage on beat 4", timeline, 4.0, BattleEvent.Type.DAMAGE_APPLIED, failures)


func _test_attack_then_realize_pending_statuses(failures: Array[String]) -> void:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var attack_scope := 200
	var strike_scope := 201
	var realize_scope := 202
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id, _package_meta(actor_id, 0, &"attack")))
	events.append(_scope_begin(strike_scope, attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_strike_event(actor_id, [2], Attack.Mode.MELEE, 0, 1))
	events.append(_damage_event(actor_id, 2, 7, 1, false))
	events.append(_scope_end(strike_scope, attack_scope, Scope.Kind.STRIKE, actor_id))
	events.append(_scope_end(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id))
	events.append(_scope_begin(realize_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id, _package_meta(actor_id, 1, &"realize_pending_statuses", false, {Keys.TARGET_ID: 2})))
	events.append(_status_changed_event(actor_id, 2, &"small"))
	events.append(_scope_end(realize_scope, actor_scope, Scope.Kind.STATUS_ACTION, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))

	var timeline := _compile_and_assert_lossless("attack_then_realize_pending_statuses", events, failures)
	_assert_beats("attack_then_realize_pending_statuses", timeline, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0], failures)


func _build_basic_attack_turn(
	attack_mode: int,
	target_groups: Array,
	lethal_flags: Array[bool]
) -> Array[BattleEvent]:
	_seq = 1
	var actor_id := 1
	var actor_scope := 100
	var attack_scope := 200
	var events: Array[BattleEvent] = []

	events.append(_scope_begin(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	events.append(_scope_begin(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id, _package_meta(actor_id, 0, &"attack")))

	for i in range(target_groups.size()):
		var strike_scope_id := 210 + i
		var targets: Array = target_groups[i]
		var target_id := int(targets[0]) if !targets.is_empty() else 0
		var lethal := bool(lethal_flags[i]) if i < lethal_flags.size() else false
		events.append(_scope_begin(strike_scope_id, attack_scope, Scope.Kind.STRIKE, actor_id))
		events.append(_strike_event(actor_id, targets, attack_mode, i, target_groups.size()))
		events.append(_damage_event(actor_id, target_id, 10, 0 if lethal else 4, lethal))
		if lethal:
			events.append(_removed_event(target_id))
		events.append(_scope_end(strike_scope_id, attack_scope, Scope.Kind.STRIKE, actor_id))

	events.append(_scope_end(attack_scope, actor_scope, Scope.Kind.ATTACK, actor_id))
	events.append(_scope_end(actor_scope, 0, Scope.Kind.ACTOR_TURN, actor_id))
	return events


func _compile_and_assert_lossless(name: String, events: Array[BattleEvent], failures: Array[String]) -> TurnTimeline:
	var timeline := _compiler.compile_actor_turn(events)
	var assigned_counts := {}
	for beat in timeline.beats:
		if beat == null:
			continue
		for event in beat.events:
			var seq := int(event.seq)
			assigned_counts[seq] = int(assigned_counts.get(seq, 0)) + 1

	for event in events:
		if event == null or _is_structural_ignored(event):
			continue
		var count := int(assigned_counts.get(int(event.seq), 0))
		if count != 1:
			failures.append("%s: expected event seq=%d type=%s to be assigned exactly once, got %d" % [
				name,
				int(event.seq),
				BattleEvent.Type.keys()[int(event.type)],
				count,
			])
	return timeline


func _assert_beats(name: String, timeline: TurnTimeline, expected: Array[float], failures: Array[String]) -> void:
	var actual: Array[float] = []
	for beat in timeline.beats:
		if beat != null:
			actual.append(float(beat.beat_q))
	_assert_float_array("%s beat_q" % name, actual, expected, failures)


func _assert_float_array(label: String, actual: Array[float], expected: Array[float], failures: Array[String]) -> void:
	if actual.size() != expected.size():
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
		return
	for i in range(actual.size()):
		if !is_equal_approx(actual[i], expected[i]):
			failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
			return


func _assert_tag_count(label: String, timeline: TurnTimeline, tag: StringName, expected_count: int, failures: Array[String]) -> void:
	var count := 0
	for beat in timeline.beats:
		if beat != null and beat.tags.has(tag):
			count += 1
	if count != expected_count:
		failures.append("%s: expected %d, got %d" % [label, expected_count, count])


func _assert_event_types(label: String, beat: TurnBeat, expected_types: Array[int], failures: Array[String]) -> void:
	if beat == null:
		failures.append("%s: beat missing" % label)
		return
	var actual := {}
	for event in beat.events:
		if event != null:
			actual[int(event.type)] = true
	for event_type in expected_types:
		if !actual.has(int(event_type)):
			failures.append("%s: missing event type %s" % [label, BattleEvent.Type.keys()[int(event_type)]])


func _assert_event_on_beat(
	label: String,
	timeline: TurnTimeline,
	beat_q: float,
	event_type: int,
	failures: Array[String],
	expected_count: int = 1
) -> void:
	var beat := _find_beat(timeline, beat_q)
	if beat == null:
		failures.append("%s: beat %.2f missing" % [label, beat_q])
		return
	var count := 0
	for event in beat.events:
		if event != null and int(event.type) == int(event_type):
			count += 1
	if count != expected_count:
		failures.append("%s: expected %d event(s) of type %s at beat %.2f, got %d" % [
			label,
			expected_count,
			BattleEvent.Type.keys()[int(event_type)],
			beat_q,
			count,
		])


func _beats_with_tag(timeline: TurnTimeline, tag: StringName) -> Array[float]:
	var out: Array[float] = []
	for beat in timeline.beats:
		if beat != null and beat.tags.has(tag):
			out.append(float(beat.beat_q))
	return out


func _find_beat(timeline: TurnTimeline, beat_q: float) -> TurnBeat:
	for beat in timeline.beats:
		if beat != null and is_equal_approx(float(beat.beat_q), beat_q):
			return beat
	return null


func _assert_packed_ints(label: String, actual: PackedInt32Array, expected: PackedInt32Array, failures: Array[String]) -> void:
	if actual.size() != expected.size():
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
		return
	for i in range(actual.size()):
		if int(actual[i]) != int(expected[i]):
			failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
			return


func _assert_group_layout_order(
	label: String,
	timeline: TurnTimeline,
	beat_q: float,
	group_index: int,
	expected_order: Array[int],
	failures: Array[String]
) -> void:
	var beat := _find_beat(timeline, beat_q)
	if beat == null:
		failures.append("%s: beat %.2f missing" % [label, beat_q])
		return
	for order in beat.orders:
		var layout := order as GroupLayoutPresentationOrder
		if layout == null:
			continue
		if int(layout.group_index) != int(group_index):
			continue
		var actual_order: Array[int] = []
		for cid in layout.order_ids:
			actual_order.append(int(cid))
		if str(actual_order) != str(expected_order):
			failures.append("%s: expected order %s, got %s" % [label, str(expected_order), str(actual_order)])
		return
	failures.append("%s: missing group layout order" % label)


func _scope_begin(scope_id: int, parent_scope_id: int, scope_kind: int, actor_id: int, extra: Dictionary = {}) -> BattleEvent:
	var data := {
		Keys.SCOPE_ID: scope_id,
		Keys.PARENT_SCOPE_ID: parent_scope_id,
		Keys.SCOPE_KIND: scope_kind,
		Keys.ACTOR_ID: actor_id,
		Keys.GROUP_INDEX: 1,
	}
	for key in extra.keys():
		data[key] = extra[key]
	var event := BattleEvent.new(BattleEvent.Type.SCOPE_BEGIN)
	event.seq = _next_seq()
	event.scope_id = scope_id
	event.parent_scope_id = parent_scope_id
	event.scope_kind = scope_kind
	event.group_index = 1
	event.data = data
	return event


func _scope_end(scope_id: int, parent_scope_id: int, scope_kind: int, actor_id: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.SCOPE_END)
	event.seq = _next_seq()
	event.scope_id = scope_id
	event.parent_scope_id = parent_scope_id
	event.scope_kind = scope_kind
	event.group_index = 1
	event.data = {
		Keys.SCOPE_ID: scope_id,
		Keys.PARENT_SCOPE_ID: parent_scope_id,
		Keys.SCOPE_KIND: scope_kind,
		Keys.ACTOR_ID: actor_id,
	}
	return event


func _strike_event(actor_id: int, target_ids: Array, attack_mode: int, strike_index: int, strikes_total: int) -> BattleEvent:
	var event_type := BattleEvent.Type.STRIKE
	var event := BattleEvent.new(event_type)
	event.seq = _next_seq()
	event.group_index = 1
	event.defines_beat = true
	event.data = {
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: attack_mode,
		Keys.STRIKE_INDEX: strike_index,
		Keys.STRIKES: strikes_total,
		Keys.PROJECTILE_SCENE: "uid://bxmhi3urqmpfh",
	}
	return event


func _damage_event(actor_id: int, target_id: int, amount: int, after_health: int, lethal: bool) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.DAMAGE_APPLIED)
	event.seq = _next_seq()
	event.group_index = 1
	event.data = {
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_ID: target_id,
		Keys.FINAL_AMOUNT: amount,
		Keys.BEFORE_HEALTH: after_health + amount,
		Keys.AFTER_HEALTH: after_health,
		Keys.WAS_LETHAL: lethal,
	}
	return event


func _removed_event(target_id: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.REMOVED)
	event.seq = _next_seq()
	event.group_index = 1
	event.defines_beat = true
	event.data = {
		Keys.TARGET_ID: target_id,
		Keys.GROUP_INDEX: 1,
		Keys.REMOVAL_TYPE: int(Removal.Type.DEATH),
	}
	return event


func _moved_event(actor_id: int, target_id: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.MOVED)
	event.seq = _next_seq()
	event.group_index = 1
	event.data = {
		Keys.ACTOR_ID: actor_id,
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_ID: target_id,
		Keys.GROUP_INDEX: 1,
		Keys.AFTER_ORDER_IDS: PackedInt32Array([actor_id, target_id]),
	}
	return event


func _heal_event(actor_id: int, target_id: int, amount: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.HEAL_APPLIED)
	event.seq = _next_seq()
	event.group_index = 1
	event.data = {
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_ID: target_id,
		Keys.HEALED_AMOUNT: amount,
		Keys.BEFORE_HEALTH: 1,
		Keys.AFTER_HEALTH: 1 + amount,
	}
	return event


func _summoned_event(actor_id: int, summoned_id: int, group_index: int, insert_index: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.SUMMONED)
	event.seq = _next_seq()
	event.group_index = group_index
	event.defines_beat = true
	event.data = {
		Keys.ACTOR_ID: actor_id,
		Keys.SOURCE_ID: actor_id,
		Keys.SUMMONED_ID: summoned_id,
		Keys.GROUP_INDEX: group_index,
		Keys.INSERT_INDEX: insert_index,
		Keys.AFTER_ORDER_IDS: PackedInt32Array([summoned_id]),
		Keys.SUMMON_SPEC: {},
	}
	return event


func _status_event(actor_id: int, target_id: int, status_id: StringName, target_ids: PackedInt32Array = PackedInt32Array()) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.STATUS)
	event.seq = _next_seq()
	event.group_index = 1
	var event_target_ids := target_ids if !target_ids.is_empty() else PackedInt32Array([target_id])
	event.data = {
		Keys.ACTOR_ID: actor_id,
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_ID: target_id,
		Keys.TARGET_IDS: event_target_ids,
		Keys.STATUS_ID: status_id,
		Keys.OP: int(Status.OP.APPLY),
		Keys.INTENSITY: 1,
		Keys.DURATION: 0,
		Keys.AFTER_INTENSITY: 1,
		Keys.AFTER_DURATION: 0,
	}
	return event


func _status_changed_event(actor_id: int, target_id: int, status_id: StringName) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Type.STATUS_CHANGED)
	event.seq = _next_seq()
	event.group_index = 1
	event.data = {
		Keys.ACTOR_ID: actor_id,
		Keys.SOURCE_ID: actor_id,
		Keys.TARGET_ID: target_id,
		Keys.STATUS_ID: status_id,
		Keys.OP: int(Status.OP.CHANGE),
		Keys.BEFORE_INTENSITY: 1,
		Keys.AFTER_INTENSITY: 2,
		Keys.BEFORE_DURATION: 0,
		Keys.AFTER_DURATION: 0,
	}
	return event


func _package_meta(
	actor_id: int,
	package_index: int,
	sequence_kind: StringName,
	compact_to_previous: bool = false,
	extra: Dictionary = {}
) -> Dictionary:
	var data := {
		Keys.ACTOR_ID: actor_id,
		Keys.EFFECT_PACKAGE_INDEX: package_index,
		Keys.EFFECT_SEQUENCE_KIND: sequence_kind,
		Keys.COMPACT_TO_PREVIOUS: compact_to_previous,
	}
	for key in extra.keys():
		data[key] = extra[key]
	return data


func _is_structural_ignored(event: BattleEvent) -> bool:
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


func _next_seq() -> int:
	var cur := _seq
	_seq += 1
	return cur
