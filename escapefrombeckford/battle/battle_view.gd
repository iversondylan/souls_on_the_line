# battle_view.gd

class_name BattleView extends Node2D

@onready var combatant_view_scene: PackedScene = preload("uid://bxhcb3bs75de6")

@onready var friendly_group: GroupView = $Group0
@onready var enemy_group: GroupView = $Group1
@onready var target_arrow: BattlefieldTargetArrow = $TargetArrow

var sim_host: SimHost
var battle_ui: BattleUI

var event_player: BattleEventPlayer
var event_director: BattleEventDirector
var transport_session: BattleTransportSession
var scheduler: BeatScheduler
var clock: BattleClock
var cue_scheduler: CueScheduler
var status_catalog: StatusCatalog = null

var _playing := false
var _playback_gen: int = 0
var playback_speed_mode: int = 1
var _projectiles_by_attacker: Dictionary = {}
var _summon_preview_ghost: Node2D = null
var combatants_by_cid: Dictionary = {}

var tempo: float = 135

var tween_bg: Tween
var _active_focus_order: FocusOrder = null

@export var metronome_sound: Sound
@export var offset_s: float = 0.38
@export var click_sound: Sound


func _ready() -> void:
	cue_scheduler = CueScheduler.new()
	scheduler = BeatScheduler.new()
	event_player = BattleEventPlayer.new()
	event_director = BattleEventDirector.new()
	event_director.bind(self)


func bind_log(log: BattleEventLog) -> void:
	event_player.bind_log(log)


func bind_transport_session(session: BattleTransportSession) -> void:
	transport_session = session
	clock = session


func start_playback() -> void:
	if _playing:
		return
	if clock == null:
		push_warning("BattleView.start_playback(): missing battle clock/transport session.")
		return

	_playing = true
	_playback_gen += 1

	if clock != null:
		clock.start()

	_playback_loop(_playback_gen)


func stop_playback() -> void:
	_playing = false
	_playback_gen += 1
	if clock != null:
		clock.stop()


func pause_playback() -> void:
	if clock != null:
		clock.pause()


func resume_playback() -> void:
	if clock != null:
		clock.resume()

func _playback_loop(gen: int) -> void:
	var schedule_t := clock.now_sec()

	while _playing and gen == _playback_gen and event_player != null:
		while _playing and gen == _playback_gen and !event_player.has_next():
			var log := event_player.get_log()
			if log == null:
				_playing = false
				return
			await log.appended

		if !_playing or gen != _playback_gen:
			return

		var player_id := 0
		if sim_host != null and sim_host.get_main_api() != null:
			player_id = int(sim_host.get_main_api().get_player_id())

		var now := clock.now_sec()

		if event_player.peek_is_npc_actor_turn(player_id):
			var actor_turn := await event_player.await_complete_actor_turn_chunk()
			if actor_turn.is_empty():
				continue

			var unit_q := 1.0 # quarter-note grid only
			var late_tolerance_sec := 0.05

			var t_start := schedule_t
			if t_start < now - late_tolerance_sec:
				t_start = clock.next_grid_time(now, unit_q)

			if t_start > now:
				await clock.wait_until(t_start)

			if !_playing or gen != _playback_gen:
				return

			var compiler := TurnTimelineCompiler.new()
			var timeline := compiler.compile_actor_turn(actor_turn)
			#print(_debug_timeline_line(timeline, actor_turn))

			var plan_builder := TurnTimelineToDirectorPlan.new()
			var plan := plan_builder.build_plan(
				timeline,
				t_start,
				transport_session.tempo_bpm if transport_session != null else tempo
			)
			#print(_debug_director_plan_line(plan, actor_turn, clock.now_sec(), schedule_t))

			await cue_scheduler.play_plan(clock, event_director, plan, gen)
			schedule_t = plan.get_end_sec()
			continue

		var chunk := event_player.next_raw_chunk(player_id)
		if chunk.is_empty():
			continue

		var actor_begin_id := _chunk_actor_id(chunk)
		var is_player_actor := (actor_begin_id != 0 and actor_begin_id == player_id)
		var is_player_turn := is_player_actor

		var mode := scheduler.mode_for_beat(chunk, is_player_turn, is_player_actor)
		var wait_q := scheduler.quarters_for_beat(chunk)
		var wait_sec := wait_q * clock.seconds_per_quarter()

		var t_start2 := now
		var t_next := now

		match mode:
			BeatScheduler.Mode.FREE:
				t_start2 = now
				t_next = now
				# leave schedule_t unchanged

			BeatScheduler.Mode.RELATIVE:
				t_start2 = maxf(schedule_t, now)
				t_next = t_start2 + wait_sec
				schedule_t = t_next

			BeatScheduler.Mode.GRID:
				var unit_q2 := _unit_quarters_for_speed_mode()
				t_start2 = clock.next_grid_time(maxf(schedule_t, now), unit_q2)
				t_next = t_start2 + wait_sec
				schedule_t = t_next

		if t_start2 > now:
			await clock.wait_until(t_start2)

		if !_playing or gen != _playback_gen:
			return

		var pkg := BeatPackage.new()
		pkg.beat = chunk
		pkg.gen = gen
		pkg.wait_quarters = wait_q
		pkg.t_start_sec = t_start2
		pkg.t_next_sec = t_next
		pkg.duration_sec = maxf(0.0, t_next - t_start2)

		#print(_debug_beat_package_line(pkg, mode, actor_begin_id, is_player_actor, clock.now_sec(), schedule_t))

		event_director.play_raw_chunk(pkg)

func _debug_beat_package_line(
	pkg: BeatPackage,
	mode: int,
	actor_begin_id: int,
	is_player_actor: bool,
	now_sec: float,
	current_schedule_t: float
) -> String:
	if pkg == null:
		return "[BEAT] <null>"

	var mode_name := "FREE"
	match mode:
		BeatScheduler.Mode.FREE:
			mode_name = "FREE"
		BeatScheduler.Mode.RELATIVE:
			mode_name = "RELATIVE"
		BeatScheduler.Mode.GRID:
			mode_name = "GRID"

	var kind := _debug_chunk_summary(pkg.beat)
	var start_slip := now_sec - pkg.t_start_sec

	return "[BEAT] mode=%s actor=%d player=%s start=%.3f next=%.3f dur=%.3f wait_q=%.2f now=%.3f slip=%.3f sched=%.3f events=%s" % [
		mode_name,
		actor_begin_id,
		str(is_player_actor),
		pkg.t_start_sec,
		pkg.t_next_sec,
		pkg.duration_sec,
		pkg.wait_quarters,
		now_sec,
		start_slip,
		current_schedule_t,
		kind,
	]

func _choose_npc_plan_start(now: float, schedule_t: float, unit_q: float) -> float:
	var late_tolerance_sec := 0.05
	
	# If we're only a tiny bit late relative to the intended musical anchor,
	# keep the current grid boundary instead of skipping a whole unit.
	if now <= schedule_t + late_tolerance_sec:
		return schedule_t
	
	return clock.next_grid_time(now, unit_q)

func _debug_event_short(e: BattleEvent) -> String:
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

	return "%s(sk=%s sid=%s a=%s src=%s tgt=%s g=%s)" % [
		type_name,
		int(e.scope_kind),
		int(e.scope_id),
		actor_id,
		source_id,
		target_id,
		group_index,
	]


func _debug_chunk_summary(chunk: Array[BattleEvent]) -> String:
	if chunk == null or chunk.is_empty():
		return "[]"

	var parts: Array[String] = []
	var max_n := mini(chunk.size(), 8)

	for i in range(max_n):
		parts.append(_debug_event_short(chunk[i]))

	if chunk.size() > max_n:
		parts.append("... +" + str(chunk.size() - max_n) + " more")

	return " | ".join(parts)


func _debug_payload_summary(payload: Array) -> String:
	if payload == null or payload.is_empty():
		return "[]"

	var parts: Array[String] = []
	var max_n := mini(payload.size(), 6)

	for i in range(max_n):
		var be := payload[i] as BattleEvent
		parts.append(_debug_event_short(be))

	if payload.size() > max_n:
		parts.append("... +" + str(payload.size() - max_n) + " more")

	return " | ".join(parts)

func _unit_quarters_for_speed_mode() -> float:
	match playback_speed_mode:
		1:
			return 4.0
		2:
			return 2.0
		4:
			return 1.0
		_:
			return 4.0


func _event_actor_id(e: BattleEvent) -> int:
	if e == null or e.data == null:
		return 0
	if e.data.has(Keys.ACTOR_ID):
		return int(e.data[Keys.ACTOR_ID])
	if e.data.has(Keys.SOURCE_ID):
		return int(e.data[Keys.SOURCE_ID])
	return 0


func _chunk_actor_id(chunk: Array[BattleEvent]) -> int:
	for e in chunk:
		if e == null:
			continue

		if int(e.type) == BattleEvent.Type.SCOPE_BEGIN and int(e.scope_kind) == int(Scope.Kind.ACTOR_TURN):
			if e.data != null and e.data.has(Keys.ACTOR_ID):
				return int(e.data[Keys.ACTOR_ID])

		if int(e.type) == BattleEvent.Type.ACTOR_BEGIN:
			return _event_actor_id(e)

	return 0


func get_or_create_combatant_view(cid: int, group_index: int, insert_index: int, animate := false, is_player := false) -> CombatantView:
	if cid <= 0:
		return null
	if combatants_by_cid.has(cid):
		return combatants_by_cid[cid]

	var combatant := combatant_view_scene.instantiate() as CombatantView
	if combatant == null:
		push_error("BattleView: combatant_view_scene must instance a CombatantView")
		return null

	if is_player:
		combatant.type = CombatantView.Type.PLAYER
	else:
		combatant.type = CombatantView.Type.ALLY if group_index == 0 else CombatantView.Type.ENEMY

	var group: GroupView = friendly_group if group_index == 0 else enemy_group
	group.add_child(combatant)

	combatant.cid = cid
	combatant.group_index = group_index
	combatant.bind_status_catalog(status_catalog)

	var n_children := group.get_child_count()
	if insert_index < 0:
		insert_index = n_children - 1
	insert_index = clampi(insert_index, 0, n_children - 1)
	group.move_child(combatant, insert_index)

	combatants_by_cid[cid] = combatant

	var ctx := GroupLayoutOrder.new()
	ctx.group_index = group_index
	ctx.new_combatant = combatant
	ctx.animate_to_position = animate
	group.register_combatant(ctx)

	if _active_focus_order != null:
		var inherited_focus := _duplicate_focus_order(_active_focus_order)
		if inherited_focus != null:
			var is_involved := int(cid) == int(inherited_focus.attacker_id) or inherited_focus.target_ids.has(int(cid))
			if is_involved:
				print("[VIEW REACTION] focus_inherit cid=%d attacker=%d targets=%s" % [
					int(cid),
					int(inherited_focus.attacker_id),
					str(inherited_focus.target_ids),
				])
				combatant.on_focus(inherited_focus)

	return combatant


func set_group_order(ctx: GroupLayoutOrder) -> void:
	var group: GroupView = friendly_group if ctx.group_index == 0 else enemy_group
	group.set_order(ctx)


func get_combatant(cid: int) -> CombatantView:
	return combatants_by_cid.get(cid, null)


func get_combatants() -> Array[CombatantView]:
	var combatants: Array[CombatantView] = []
	for key in combatants_by_cid:
		combatants.push_back(combatants_by_cid[key] as CombatantView)
	return combatants


func apply_focus(order: FocusOrder) -> void:
	#print("battle_view.gd apply_focus() time: ", clock.now_sec(), " duration: ", order.duration)
	_active_focus_order = _duplicate_focus_order(order)
	_apply_focus_background(order)
	_apply_focus_combatants(order)


func clear_focus(duration: float) -> void:
	#print("battle_view.gd clear_focus() time: ", clock.now_sec(), " duration: ", duration)
	_active_focus_order = null
	for combatant: CombatantView in get_combatants():
		combatant.clear_focus(duration)

	var bg: Array[Node] = get_tree().get_nodes_in_group("background")
	if tween_bg:
		tween_bg.kill()
	var reduced_duration := duration * 0.75
	if bg:
		tween_bg = self.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for item in bg:
		if "modulate" in item:
			tween_bg.tween_property(item, "modulate", Color(1, 1, 1, 1.0), reduced_duration)


func _apply_focus_background(order: FocusOrder) -> void:
	var bg = get_tree().get_nodes_in_group("background")
	if tween_bg:
		tween_bg.kill()
	if bg:
		tween_bg = self.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var reduced_duration := order.duration * 0.75
	for item in bg:
		if "modulate" in item:
			tween_bg.tween_property(item, "modulate", Color(order.dim_bg, order.dim_bg, order.dim_bg, 1.0), reduced_duration)


func _apply_focus_combatants(order: FocusOrder) -> void:
	for combatant: CombatantView in get_combatants():
		combatant.on_focus(order)


func _duplicate_focus_order(order: FocusOrder) -> FocusOrder:
	if order == null:
		return null

	var copy := FocusOrder.new()
	copy.duration = float(order.duration)
	copy.attacker_id = int(order.attacker_id)
	copy.target_ids = order.target_ids.duplicate()
	copy.dim_uninvolved = float(order.dim_uninvolved)
	copy.dim_bg = float(order.dim_bg)
	copy.scale_involved = float(order.scale_involved)
	copy.scale_uninvolved = float(order.scale_uninvolved)
	copy.drift_involved = float(order.drift_involved)
	copy.drift_uninvolved = float(order.drift_uninvolved)
	return copy

func put_projectile(key: int, projectile: Node2D) -> void:
	_projectiles_by_attacker[int(key)] = projectile


func take_projectile(key: int) -> Node2D:
	var k := int(key)
	if !_projectiles_by_attacker.has(k):
		return null
	var p: Node2D = _projectiles_by_attacker[k]
	_projectiles_by_attacker.erase(k)
	return p


func make_projectile_key(attacker_id: int, strike_index: int) -> int:
	return int(attacker_id) * 1000 + int(strike_index)


func get_mean_target_position_global(target_ids: Array[int], fallback: Vector2) -> Vector2:
	if target_ids.is_empty():
		return fallback
	var sum := Vector2.ZERO
	var n := 0
	for tid in target_ids:
		var tv := get_combatant(int(tid))
		if tv != null:
			sum += tv.global_position
			n += 1
	if n <= 0:
		return fallback
	return sum / float(n)


func get_summon_slot_position(group_index: int, slot_index: int) -> Vector2:
	var group: GroupView = friendly_group if group_index == 0 else enemy_group
	var nodes := group.get_children()
	var layout_count := 0
	for c in nodes:
		if c is CombatantView:
			layout_count += 1

	var slot := float(clampf(float(slot_index) + 0.5, 0.5, layout_count + 0.5))
	var x := group._get_x_for_slot(slot, layout_count)
	return group.global_position + Vector2(x, 0)


func get_all_combatant_views() -> Array[CombatantView]:
	var out: Array[CombatantView] = []
	for k in combatants_by_cid.keys():
		var v: CombatantView = combatants_by_cid[k]
		if v != null and is_instance_valid(v):
			out.append(v)
	return out


func get_combatant_views_for_group(group_index: int) -> Array[CombatantView]:
	var out: Array[CombatantView] = []
	for v in get_all_combatant_views():
		if v != null and is_instance_valid(v) and int(v.group_index) == int(group_index):
			out.append(v)
	return out


func show_summon_preview_ghost(ghost: Node2D, insert_index: int, group_index: int = 0) -> void:
	clear_summon_preview_ghost()

	if ghost == null or !is_instance_valid(ghost):
		return

	_summon_preview_ghost = ghost
	add_child(_summon_preview_ghost)

	var p := get_summon_slot_position(int(group_index), int(insert_index))
	_summon_preview_ghost.global_position = p


func get_summon_slot_position_for_layout_count(group_index: int, insert_index: int, layout_count: int) -> Vector2:
	var group: GroupView = friendly_group if group_index == 0 else enemy_group

	var slot := float(clampf(float(insert_index) + 0.5, 0.5, float(layout_count) + 0.5))
	var x := group._get_x_for_slot(slot, layout_count)
	return group.global_position + Vector2(x, 0)


func clear_summon_preview_ghost() -> void:
	if _summon_preview_ghost != null and is_instance_valid(_summon_preview_ghost):
		_summon_preview_ghost.queue_free()
	_summon_preview_ghost = null

func _debug_action_presentation_summary(a: DirectorAction) -> String:
	if a == null or a.presentation == null:
		return "presentation=<null>"

	var attack := a.presentation as AttackPresentationInfo
	if attack == null:
		return "presentation=%s" % [a.presentation.get_class()]

	return "atk=%s mode=%s strikes=%s hits=%s lethal=%s targets=%s" % [
		attack.attacker_id,
		attack.attack_mode,
		attack.strike_count,
		attack.total_hit_count,
		attack.has_lethal_hit,
		attack.get_all_target_ids(),
	]


func _debug_timeline_line(timeline: TurnTimeline, actor_turn: Array[BattleEvent]) -> String:
	if timeline == null:
		return "[TIMELINE] <null>"

	return "[TIMELINE] actor=%d group=%d kind=%s beats=%d src_events=%d summary=%s" % [
		int(timeline.actor_id),
		int(timeline.group_index),
		String(timeline.action_kind),
		timeline.beats.size(),
		actor_turn.size(),
		_debug_turn_beats_summary(timeline.beats),
	]


func _debug_director_plan_line(plan: DirectorPlan, actor_turn: Array[BattleEvent], now_sec: float, prior_schedule_t: float) -> String:
	if plan == null:
		return "[CUEPLAN] <null>"

	var actor_id := _chunk_actor_id(actor_turn)
	var last_q := plan.get_last_beat_q()
	var end_sec := plan.get_end_sec()
	var total_dur := end_sec - plan.t_start_sec
	var start_slip := now_sec - plan.t_start_sec

	return "[CUEPLAN] actor=%d cues=%d start=%.3f end=%.3f dur=%.3f last_q=%.2f gap_q=%.2f now=%.3f slip=%.3f prev_sched=%.3f cues=%s" % [
		actor_id,
		plan.cues.size(),
		plan.t_start_sec,
		end_sec,
		total_dur,
		last_q,
		plan.handoff_gap_q,
		now_sec,
		start_slip,
		prior_schedule_t,
		_debug_cue_summary(plan.cues),
	]


func _debug_turn_beats_summary(beats: Array[TurnBeat]) -> String:
	if beats == null or beats.is_empty():
		return "[]"

	var parts: Array[String] = []
	var max_n := mini(beats.size(), 8)

	for i in range(max_n):
		var b := beats[i]
		if b == null:
			parts.append("<null>")
			continue
		parts.append("{q=%.2f label=%s orders=%d events=%d %s}" % [
			float(b.beat_q),
			String(b.label),
			b.orders.size(),
			b.events.size(),
			_debug_order_summary(b.orders),
		])

	if beats.size() > max_n:
		parts.append("... +" + str(beats.size() - max_n) + " more")

	return " | ".join(parts)


func _debug_cue_summary(cues: Array[DirectorCue]) -> String:
	if cues == null or cues.is_empty():
		return "[]"

	var parts: Array[String] = []
	var max_n := mini(cues.size(), 8)

	for i in range(max_n):
		var c := cues[i]
		if c == null:
			parts.append("<null>")
			continue
		parts.append("{q=%.2f idx=%d label=%s orders=%d events=%d %s %s}" % [
			float(c.beat_q),
			int(c.index),
			String(c.label),
			c.orders.size(),
			c.events.size(),
			_debug_order_summary(c.orders),
			_debug_event_summary(c.events),
		])

	if cues.size() > max_n:
		parts.append("... +" + str(cues.size() - max_n) + " more")

	return " | ".join(parts)

func _debug_event_summary(events: Array[BattleEvent]) -> String:
	if events == null or events.is_empty():
		return "events=[]"

	var parts: Array[String] = []
	var max_n := mini(events.size(), 6)

	for i in range(max_n):
		parts.append(_debug_event_short(events[i]))

	if events.size() > max_n:
		parts.append("... +" + str(events.size() - max_n) + " more")

	return "events=[" + " | ".join(parts) + "]"

func _debug_order_summary(orders: Array[PresentationOrder]) -> String:
	if orders == null or orders.is_empty():
		return "orders=[]"

	var parts: Array[String] = []
	var max_n := mini(orders.size(), 6)

	for i in range(max_n):
		parts.append(_debug_order_short(orders[i]))

	if orders.size() > max_n:
		parts.append("... +" + str(orders.size() - max_n) + " more")

	return "orders=[" + " | ".join(parts) + "]"


func _debug_order_short(order: PresentationOrder) -> String:
	if order == null:
		return "<null-order>"

	var kind_name := str(int(order.kind))
	if int(order.kind) >= 0 and int(order.kind) < PresentationOrder.Kind.keys().size():
		kind_name = PresentationOrder.Kind.keys()[int(order.kind)]

	var bits: Array[String] = []
	bits.append(kind_name)
	bits.append("a=%d" % int(order.actor_id))

	if order.target_ids != null and !order.target_ids.is_empty():
		bits.append("tgts=%s" % str(order.target_ids))

	if float(order.visual_sec) > 0.0:
		bits.append("vis=%.2f" % float(order.visual_sec))

	match int(order.kind):
		PresentationOrder.Kind.MELEE_WINDUP:
			var o := order as MeleeWindupPresentationOrder
			if o != null:
				bits.append("strikes=%d" % int(o.strike_count))
				bits.append("hits=%d" % int(o.total_hit_count))

		PresentationOrder.Kind.MELEE_STRIKE:
			var o2 := order as MeleeStrikePresentationOrder
			if o2 != null:
				bits.append("i=%d/%d" % [int(o2.strike_index), int(o2.strikes_total)])
				bits.append("hits=%d" % int(o2.total_hit_count))
				bits.append("lethal=%s" % str(bool(o2.has_lethal)))

		PresentationOrder.Kind.RANGED_WINDUP:
			var o3 := order as RangedWindupPresentationOrder
			if o3 != null:
				bits.append("strikes=%d" % int(o3.strike_count))
				bits.append("hits=%d" % int(o3.total_hit_count))

		PresentationOrder.Kind.RANGED_FIRE:
			var o4 := order as RangedFirePresentationOrder
			if o4 != null:
				bits.append("i=%d/%d" % [int(o4.strike_index), int(o4.strikes_total)])
				bits.append("hits=%d" % int(o4.total_hit_count))
				bits.append("lethal=%s" % str(bool(o4.has_lethal)))
				if o4.projectile_scene_path != "":
					bits.append("proj=%s" % o4.projectile_scene_path.get_file())

		PresentationOrder.Kind.RANGED_CLEAVE:
			var o4c := order as RangedFirePresentationOrder
			if o4c != null:
				bits.append("i=%d/%d" % [int(o4c.strike_index), int(o4c.strikes_total)])
				bits.append("hits=%d" % int(o4c.total_hit_count))
				bits.append("lethal=%s" % str(bool(o4c.has_lethal)))
				if o4c.projectile_scene_path != "":
					bits.append("proj=%s" % o4c.projectile_scene_path.get_file())

		PresentationOrder.Kind.IMPACT:
			var o5 := order as ImpactPresentationOrder
			if o5 != null:
				bits.append("t=%d" % int(o5.target_id))
				bits.append("i=%d" % int(o5.strike_index))
				bits.append("amt=%d" % int(o5.amount))
				bits.append("hp=%d" % int(o5.after_health))
				bits.append("lethal=%s" % str(bool(o5.was_lethal)))

		PresentationOrder.Kind.SUMMON_WINDUP:
			var o6 := order as SummonWindupPresentationOrder
			if o6 != null:
				bits.append("summoned=%d" % int(o6.summoned_id))
				bits.append("g=%d" % int(o6.group_index))
				bits.append("idx=%d" % int(o6.insert_index))

		PresentationOrder.Kind.SUMMON_POP:
			var o7 := order as SummonPopPresentationOrder
			if o7 != null:
				bits.append("summoned=%d" % int(o7.summoned_id))
				bits.append("g=%d" % int(o7.group_index))
				bits.append("idx=%d" % int(o7.insert_index))

		PresentationOrder.Kind.STATUS_POP:
			var o8 := order as StatusPopPresentationOrder
			if o8 != null:
				bits.append("src=%d" % int(o8.source_id))
				bits.append("t=%d" % int(o8.target_id))
				bits.append("status=%s" % String(o8.status_id))
				bits.append("mode=%s" % String(o8.presentation_mode))
				bits.append("op=%d" % int(o8.op))
				bits.append("int=%d" % int(o8.intensity))
				bits.append("dur=%d" % int(o8.turns_duration))

		PresentationOrder.Kind.DEATH:
			var o9 := order as DeathPresentationOrder
			if o9 != null:
				bits.append("t=%d" % int(o9.target_id))
				bits.append("g=%d" % int(o9.group_index))

		PresentationOrder.Kind.FADE:
			var o10 := order as FadePresentationOrder
			if o10 != null:
				bits.append("t=%d" % int(o10.target_id))
				bits.append("g=%d" % int(o10.group_index))
		PresentationOrder.Kind.GROUP_LAYOUT:
			var og := order as GroupLayoutPresentationOrder
			if og != null:
				bits.append("g=%d" % int(og.group_index))
				bits.append("order=%s" % str(og.order_ids))
				bits.append("anim=%s" % str(bool(og.animate)))

	return " ".join(bits)
