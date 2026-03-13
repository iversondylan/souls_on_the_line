# battle_view.gd

class_name BattleView extends Node2D

@onready var combatant_view_scene: PackedScene = preload("res://battle_view/combatant_view.tscn")

@onready var friendly_group: GroupView = $Group0
@onready var enemy_group: GroupView = $Group1
@onready var target_arrow: BattlefieldTargetArrow = $TargetArrow

var sim_host: SimHost
var battle_ui: BattleUI

var event_player: BattleEventPlayer
var event_director: BattleEventDirector
var transport: BattleTransport
var planner: SchedulePlanner
var scheduler: BeatScheduler
var clock: BattleClock

var status_catalog: StatusCatalog = null

var _playing := false
var _playback_gen: int = 0
var playback_speed_mode: int = 1
var _projectiles_by_attacker: Dictionary = {}
var _summon_preview_ghost: Node2D = null
var combatants_by_cid: Dictionary = {}

var tempo: float = 110

var tween_bg: Tween

@export var metronome_sound: Sound
@export var click_sound: Sound


func _ready() -> void:
	transport = BattleTransport.new()
	transport.tempo_bpm = tempo

	scheduler = BeatScheduler.new()
	planner = SchedulePlanner.new()
	event_player = BattleEventPlayer.new()
	event_director = BattleEventDirector.new()
	event_director.bind(self)
	#print("MusicPlayer = ", MusicPlayer)
	#print("metronome_player = ", MusicPlayer.metronome_player)
	var p: AudioStreamPlayer = MusicPlayer.metronome_player
	p.stream = metronome_sound.stream #Invalid access to property or key 'stream' on a base object of type 'Nil'.
	p.bus = "Music"
	p.volume_db = metronome_sound.volume_db
	p.pitch_scale = metronome_sound.pitch

	clock = MetronomeClock.new(p, 120.0, 0.0, get_tree())


func bind_log(log: BattleEventLog) -> void:
	event_player.bind_log(log)


func start_playback() -> void:
	if _playing:
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

func _playback_loop(gen: int) -> void:
	var schedule_t := clock.now_sec()
	var loop_iter := 0

	while _playing and gen == _playback_gen and event_player != null:
		loop_iter += 1
		print("\n========== PLAYBACK LOOP ITER ", loop_iter, " ==========")
		print("loop start now=", clock.now_sec(), " schedule_t=", schedule_t, " gen=", gen, " playing=", _playing)

		while _playing and gen == _playback_gen and !event_player.has_next():
			var log := event_player.get_log()
			if log == null:
				print("playback_loop: log is null, stopping playback")
				_playing = false
				return

			var empty_wait_start := Time.get_ticks_msec()
			print("playback_loop: no next event, awaiting log.appended ...")
			await log.appended
			var empty_wait_end := Time.get_ticks_msec()
			print(
				"playback_loop: log.appended resumed after ",
				(empty_wait_end - empty_wait_start) / 1000.0,
				" sec; now=",
				clock.now_sec()
			)

		if !_playing or gen != _playback_gen:
			print("playback_loop: aborted after empty-wait gate; playing=", _playing, " gen=", gen, " playback_gen=", _playback_gen)
			return

		var player_id := 0
		if sim_host != null and sim_host.get_main_api() != null:
			player_id = int(sim_host.get_main_api().get_player_id())

		var now := clock.now_sec()
		var peek_e := event_player.peek()

		print("player_id=", player_id, " now=", now, " schedule_t=", schedule_t)
		if peek_e == null:
			print("peek: null")
		else:
			print("peek: ", _debug_event_short(peek_e))

		#var is_npc_actor_turn := event_player.peek_is_npc_actor_turn(player_id)
		#print("peek_is_npc_actor_turn=", is_npc_actor_turn)
		if event_player.peek_is_npc_actor_turn(player_id):
			var actor_turn := await event_player.await_complete_actor_turn_chunk()
			if actor_turn.is_empty():
				continue

			var unit_q := _unit_quarters_for_speed_mode()
			var late_tolerance_sec := 0.05

			var t_start := schedule_t
			if t_start < now - late_tolerance_sec:
				t_start = clock.next_grid_time(now, unit_q)

			print("NPC planning inputs: unit_q=", unit_q,
				" start_now=", now,
				" schedule_t=", schedule_t,
				" chosen_t_start=", t_start,
				" pre-plan wait=", maxf(0.0, t_start - now))

			if t_start > now:
				var raw_wait_start := Time.get_ticks_msec()
				print("awaiting clock.wait_until(t_start) ...")
				await clock.wait_until(t_start)
				var raw_wait_actual := float(Time.get_ticks_msec() - raw_wait_start) / 1000.0
				print("pre-plan wait resumed; expected=", maxf(0.0, t_start - now),
					" actual=", raw_wait_actual,
					" now=", clock.now_sec())

			if !_playing or gen != _playback_gen:
				return

			var plan := planner.make_npc_turn_plan(
				clock,
				actor_turn,
				playback_speed_mode,
				t_start
			)

			var plan_wait_start := Time.get_ticks_msec()
			print("awaiting _play_schedule_plan(...) ...")
			await _play_schedule_plan(plan, gen)
			var plan_wait_actual := float(Time.get_ticks_msec() - plan_wait_start) / 1000.0
			print("_play_schedule_plan resumed; expected total plan dur=", plan.t_end - plan.t_start,
				" actual awaited=", plan_wait_actual,
				" now=", clock.now_sec())

			schedule_t = plan.t_end
			print("NPC path complete; new schedule_t=", schedule_t)
			continue
		#if is_npc_actor_turn:
			#print("--- NPC ACTOR TURN PATH ---")
#
			#var collect_start_ms := Time.get_ticks_msec()
			#print("awaiting complete actor-turn chunk ...")
			#var actor_turn := await event_player.await_complete_actor_turn_chunk()
			#var collect_end_ms := Time.get_ticks_msec()
#
			#print(
				#"actor-turn chunk collected in ",
				#(collect_end_ms - collect_start_ms) / 1000.0,
				#" sec"
			#)
			#print("actor-turn chunk size=", actor_turn.size())
			#print("actor-turn chunk summary=", _debug_chunk_summary(actor_turn))
#
			#if actor_turn.is_empty():
				#print("actor-turn chunk empty; continuing")
				#continue
#
			#var unit_q := _unit_quarters_for_speed_mode()
			#var t_start := _choose_npc_plan_start(now, schedule_t, unit_q)
			#var planned_wait_sec := maxf(0.0, t_start - now)
#
			#print(
				#"NPC planning inputs: unit_q=",
				#unit_q,
				#" start_now=",
				#now,
				#" schedule_t=",
				#schedule_t,
				#" chosen_t_start=",
				#t_start,
				#" pre-plan wait=",
				#planned_wait_sec
			#)
#
			#if t_start > now:
				#var prewait_start_ms := Time.get_ticks_msec()
				#print("awaiting clock.wait_until(t_start) ...")
				#await clock.wait_until(t_start)
				#var prewait_end_ms := Time.get_ticks_msec()
				#print(
					#"pre-plan wait resumed; expected=",
					#planned_wait_sec,
					#" actual=",
					#(prewait_end_ms - prewait_start_ms) / 1000.0,
					#" now=",
					#clock.now_sec()
				#)
#
			#if !_playing or gen != _playback_gen:
				#print("playback_loop: aborted after NPC prewait")
				#return
#
			#var plan := planner.make_npc_turn_plan(
				#clock,
				#actor_turn,
				#playback_speed_mode,
				#t_start
			#)
#
			#if plan == null:
				#print("planner returned null plan")
				#continue
#
			#print(
				#"plan made: t_start=",
				#plan.t_start,
				#" t_end=",
				#plan.t_end,
				#" total_dur=",
				#plan.t_end - plan.t_start,
				#" measures=",
				#plan.measures,
				#" n_actions=",
				#plan.actions.size()
			#)
#
			#for i in range(plan.actions.size()):
				#var a: DirectorAction = plan.actions[i]
				#if a == null:
					#print("	action[", i, "] = null")
					#continue
#
				#var payload_summary := _debug_payload_summary(a.payload)
				#print(
					#"	action[", i, "] label=",
					#a.label,
					#" phase=",
					#a.phase,
					#" kind=",
					#a.action_kind,
					#" t_rel=",
					#a.t_rel_sec,
					#" dur=",
					#a.duration_sec,
					#" payload=",
					#payload_summary
				#)
#
			#var plan_wait_start_ms := Time.get_ticks_msec()
			#print("awaiting _play_schedule_plan(...) ...")
			#await _play_schedule_plan(plan, gen)
			#var plan_wait_end_ms := Time.get_ticks_msec()
#
			#print(
				#"_play_schedule_plan resumed; expected total plan dur=",
				#plan.t_end - plan.t_start,
				#" actual awaited=",
				#(plan_wait_end_ms - plan_wait_start_ms) / 1000.0,
				#" now=",
				#clock.now_sec()
			#)
#
			#schedule_t = plan.t_end
			#print("NPC path complete; new schedule_t=", schedule_t)
			#continue

		print("--- RAW PATH ---")
		var raw_collect_start_ms := Time.get_ticks_msec()
		var chunk := event_player.next_raw_chunk(player_id)
		var raw_collect_end_ms := Time.get_ticks_msec()

		print(
			"raw chunk collected in ",
			(raw_collect_end_ms - raw_collect_start_ms) / 1000.0,
			" sec"
		)
		print("raw chunk size=", chunk.size())
		print("raw chunk summary=", _debug_chunk_summary(chunk))

		if chunk.is_empty():
			print("raw chunk empty; continuing")
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

		print(
			"raw scheduling: actor_begin_id=",
			actor_begin_id,
			" is_player_actor=",
			is_player_actor,
			" is_player_turn=",
			is_player_turn,
			" mode=",
			mode,
			" wait_q=",
			wait_q,
			" wait_sec=",
			wait_sec,
			" t_start2=",
			t_start2,
			" t_next=",
			t_next,
			" new schedule_t=",
			schedule_t
		)

		now = clock.now_sec()
		if t_start2 > now:
			var raw_wait_expected := t_start2 - now
			var raw_wait_start_ms := Time.get_ticks_msec()
			print("awaiting raw clock.wait_until(t_start2) ...")
			await clock.wait_until(t_start2)
			var raw_wait_end_ms := Time.get_ticks_msec()
			print(
				"raw wait resumed; expected=",
				raw_wait_expected,
				" actual=",
				(raw_wait_end_ms - raw_wait_start_ms) / 1000.0,
				" now=",
				clock.now_sec()
			)

		if !_playing or gen != _playback_gen:
			print("playback_loop: aborted after raw wait")
			return

		var pkg := BeatPackage.new()
		pkg.beat = chunk
		pkg.gen = gen
		pkg.wait_quarters = wait_q
		pkg.t_start_sec = t_start2
		pkg.t_next_sec = t_next
		pkg.duration_sec = maxf(0.0, t_next - t_start2)

		print(
			"dispatching raw chunk: pkg.duration_sec=",
			pkg.duration_sec,
			" pkg.wait_quarters=",
			pkg.wait_quarters,
			" pkg.t_start_sec=",
			pkg.t_start_sec,
			" pkg.t_next_sec=",
			pkg.t_next_sec
		)

		var raw_dispatch_start_ms := Time.get_ticks_msec()
		event_director.play_raw_chunk(pkg)
		var raw_dispatch_end_ms := Time.get_ticks_msec()

		print(
			"raw chunk dispatched in ",
			(raw_dispatch_end_ms - raw_dispatch_start_ms) / 1000.0,
			" sec; loop now=",
			clock.now_sec()
		)

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

#func _playback_loop(gen: int) -> void:
	#var schedule_t := clock.now_sec()
#
	#while _playing and gen == _playback_gen and event_player != null:
		#while _playing and gen == _playback_gen and !event_player.has_next():
			#var log := event_player.get_log()
			#if log == null:
				#_playing = false
				#return
			#await log.appended
#
		#if !_playing or gen != _playback_gen:
			#return
#
		#var player_id := 0
		#if sim_host != null and sim_host.get_main_api() != null:
			#player_id = int(sim_host.get_main_api().get_player_id())
#
		#var now := clock.now_sec()
#
		#if event_player.peek_is_npc_actor_turn(player_id):
			#var actor_turn := await event_player.await_complete_actor_turn_chunk()
			#if actor_turn.is_empty():
				#continue
#
			#var unit_q := _unit_quarters_for_speed_mode()
			#var t_start := clock.next_grid_time(maxf(schedule_t, now), unit_q)
#
			#if t_start > now:
				#await clock.wait_until(t_start)
#
			#if !_playing or gen != _playback_gen:
				#return
#
			#var plan := planner.make_npc_turn_plan(
				#clock,
				#actor_turn,
				#playback_speed_mode,
				#t_start
			#)
#
			#await _play_schedule_plan(plan, gen)
			#schedule_t = plan.t_end
			#continue
#
		#var chunk := event_player.next_raw_chunk(player_id)
		#if chunk.is_empty():
			#continue
#
		#var actor_begin_id := _chunk_actor_id(chunk)
		#var is_player_actor := (actor_begin_id != 0 and actor_begin_id == player_id)
		#var is_player_turn := is_player_actor
#
		#var mode := scheduler.mode_for_beat(chunk, is_player_turn, is_player_actor)
		#var wait_q := scheduler.quarters_for_beat(chunk)
		#var wait_sec := wait_q * clock.seconds_per_quarter()
#
		#var t_start2 := now
		#var t_next := now
#
		#match mode:
			#BeatScheduler.Mode.FREE:
				#t_start2 = now
				#t_next = now
				#schedule_t = now
#
			#BeatScheduler.Mode.RELATIVE:
				#t_start2 = maxf(schedule_t, now)
				#t_next = t_start2 + wait_sec
				#schedule_t = t_next
#
			#BeatScheduler.Mode.GRID:
				#var unit_q2 := _unit_quarters_for_speed_mode()
				#t_start2 = clock.next_grid_time(maxf(schedule_t, now), unit_q2)
				#t_next = t_start2 + wait_sec
				#schedule_t = t_next
#
		#now = clock.now_sec()
		#if t_start2 > now:
			#await clock.wait_until(t_start2)
#
		#if !_playing or gen != _playback_gen:
			#return
#
		#var pkg := BeatPackage.new()
		#pkg.beat = chunk
		#pkg.gen = gen
		#pkg.wait_quarters = wait_q
		#pkg.t_start_sec = t_start2
		#pkg.t_next_sec = t_next
		#pkg.duration_sec = maxf(0.0, t_next - t_start2)
#
		#event_director.play_raw_chunk(pkg)


func _play_schedule_plan(plan: SchedulePlan, gen: int) -> void:
	if plan == null:
		return

	var plan_start := plan.t_start

	for a in plan.actions:
		if !_playing or gen != _playback_gen:
			return
		
		var fire_t := plan_start + a.t_rel_sec
		var now := clock.now_sec()
		if fire_t > now:
			await clock.wait_until(fire_t)

		if !_playing or gen != _playback_gen:
			return
		print("PLAN action ", a.label, " fire_t=", fire_t, " now=", clock.now_sec(), " dur=", a.duration_sec)
		event_director.on_director_action(a, gen)

	var now2 := clock.now_sec()
	if plan.t_end > now2:
		await clock.wait_until(plan.t_end)


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
	_apply_focus_background(order)
	_apply_focus_combatants(order)


func clear_focus(duration: float) -> void:
	for combatant: CombatantView in get_combatants():
		combatant.clear_focus(duration)

	var bg: Array[Node] = get_tree().get_nodes_in_group("background")
	if tween_bg:
		tween_bg.kill()
	if bg:
		tween_bg = self.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for item in bg:
		if "modulate" in item:
			tween_bg.tween_property(item, "modulate", Color(1, 1, 1, 1.0), duration)


func _apply_focus_background(order: FocusOrder) -> void:
	var bg = get_tree().get_nodes_in_group("background")
	if tween_bg:
		tween_bg.kill()
	if bg:
		tween_bg = self.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for item in bg:
		if "modulate" in item:
			tween_bg.tween_property(item, "modulate", Color(order.dim_bg, order.dim_bg, order.dim_bg, 1.0), order.duration)


func _apply_focus_combatants(order: FocusOrder) -> void:
	for combatant: CombatantView in get_combatants():
		combatant.on_focus(order)


func put_projectile(attacker_id: int, projectile: Node2D) -> void:
	_projectiles_by_attacker[int(attacker_id)] = projectile


func take_projectile(attacker_id: int) -> Node2D:
	var k := int(attacker_id)
	if !_projectiles_by_attacker.has(k):
		return null
	var p: Node2D = _projectiles_by_attacker[k]
	_projectiles_by_attacker.erase(k)
	return p


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
