# sim_runtime.gd

class_name SimRuntime extends RefCounted

# Runtime orchestration for a single Sim.
#
# Responsibilities:
# - own TurnEngineCore and TurnEngineHostSim for this Sim
# - bridge TurnEngineCore callbacks into SIM-side lifecycle work
# - emit scoped BattleEventLog runtime events
# - define checkpoint boundaries for the turn flow
# - drive round-to-round scheduling
# - own runtime-only helpers like ArcanaResolver/CardExecutor
#
# Structural ownership still lives in SimHost:
# - SimHost owns main/preview sims
# - SimRuntime owns runtime execution for one Sim

var sim: Sim
var host: SimHost

var arcana_resolver: ArcanaResolver

var turn_engine: TurnEngineCore
var turn_engine_host_sim: TurnEngineHostSim


# ============================================================================
# Binding / lifecycle
# ============================================================================

func _init(_sim: Sim = null, _host: SimHost = null) -> void:
	sim = _sim
	host = _host


func bind(_sim: Sim, _host: SimHost) -> void:
	sim = _sim
	host = _host


func reset_runtime_state() -> void:
	arcana_resolver = null
	turn_engine = null
	turn_engine_host_sim = null


func _ensure_runtime_initialized() -> void:
	if host == null:
		return

	if turn_engine_host_sim == null:
		turn_engine_host_sim = TurnEngineHostSim.new(host)

	if turn_engine != null:
		return

	turn_engine = TurnEngineCore.new(turn_engine_host_sim)
	turn_engine.group_turn_ended.connect(_on_group_turn_ended)
	turn_engine.arcana_proc_requested.connect(_on_arcana_proc_requested)
	turn_engine.actor_requested.connect(_on_actor_requested)
	turn_engine.player_begin_requested.connect(_on_player_begin_requested)
	turn_engine.player_end_requested.connect(_on_player_end_requested)
	turn_engine.pending_view_changed.connect(_on_pending_view_changed)


# ============================================================================
# Small helpers
# ============================================================================

func _api() -> SimBattleAPI:
	return sim.api if sim != null else null


func _writer() -> BattleEventWriter:
	var api := _api()
	return api.writer if api != null else null


func _engine() -> TurnEngineCore:
	return turn_engine


func _player_id() -> int:
	if turn_engine_host_sim == null:
		return 0
	return turn_engine_host_sim.get_player_id()


func _can_run() -> bool:
	return sim != null and sim.api != null and host != null


func has_runtime_initialized() -> bool:
	return turn_engine != null


func is_player(combat_id: int) -> bool:
	if turn_engine_host_sim == null:
		return false
	return turn_engine_host_sim.is_player(combat_id)


func _ensure_arcana_resolver() -> ArcanaResolver:
	if arcana_resolver != null:
		return arcana_resolver

	if host == null or host.arcana_catalog == null:
		push_warning("SimRuntime: no arcana_catalog; cannot run arcana")
		return null

	arcana_resolver = ArcanaResolver.new(host, host.arcana_catalog)
	return arcana_resolver

# ============================================================================
# Checkpoint boundaries
# ============================================================================

func _apply_checkpoint_boundary(kind: int, allow_hooks := true) -> void:
	if sim == null or sim.checkpoint_processor == null:
		return

	var cp := sim.checkpoint_processor
	cp.flush_planning(kind, sim, allow_hooks)

	if cp.consume_dirty_turn_order():
		var engine := _engine()
		if engine != null:
			engine.request_queue_rebuild_and_publish()


# ============================================================================
# Public runtime-facing API
# ============================================================================

func start_group_turn(group_index: int, start_at_player := false, pre_player_friendly := false) -> void:
	if !_can_run():
		return
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	if start_at_player:
		engine.reset_for_new_battle()

	handle_group_turn_started(group_index)
	engine.start_group_turn(group_index, start_at_player, pre_player_friendly)


func request_player_end() -> void:
	var api := _api()
	if api == null:
		return

	var writer := api.writer
	if writer != null:
		writer.emit_end_turn_pressed(api.get_player_id())


func notify_player_discard_animation_finished() -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.request_player_end()


func add_combatant_from_data(data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	var api := _api()
	if api == null:
		return 0

	return api.spawn_from_data(data, group_index, insert_index, is_player)


func apply_player_card(req: CardPlayRequest) -> bool:
	if sim == null or sim.api == null or sim.resolver == null:
		return false

	var ok := sim.resolver.resolve_player_card(sim, req)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_CARD, true)
	return ok

func request_urgent_planning_flush() -> void:
	print("sim_runtime.gd request_urgent_planning_flush()")
	if sim == null or sim.checkpoint_processor == null:
		return
	sim.checkpoint_processor.flush_planning(CheckpointProcessor.Kind.URGENT_STATUS_LEGALITY, sim)#request_followup_flush()

# ============================================================================
# API hooks (assigned from host)
# ============================================================================

func on_summoned(summoned_id: int, group_index: int) -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.notify_summon_added(int(summoned_id), int(group_index))


func on_unit_removed(cid: int, _group_index: int, _reason: String) -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.notify_actor_removed(int(cid))


# ============================================================================
# TurnEngineCore signal handlers
# ============================================================================

func _on_group_turn_ended(group_index: int) -> void:
	handle_group_turn_ended(group_index)


func _on_arcana_proc_requested(proc: int, token: int) -> void:
	handle_arcana_proc_requested(proc, token)


func _on_actor_requested(cid: int) -> void:
	handle_actor_requested(cid)


func _on_player_begin_requested(token: int) -> void:
	handle_player_begin_requested(token)


func _on_player_end_requested(token: int) -> void:
	handle_player_end_requested(token)


func _on_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	handle_pending_view_changed(active_id, pending_ids)


# ============================================================================
# Turn / queue callbacks
# ============================================================================

func handle_group_turn_started(group_index: int) -> void:
	#print("sim_runtime.gd handle_group_turn_started() group_index: ", group_index)
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer != null:
		writer.set_turn_context(engine._turn_token, group_index, 0)
		writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		writer.emit_group_turn_begin(group_index)
		
	api.refresh_mana_for_group_turn(group_index)
	
	SimStatusSystem.on_group_turn_begin(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_BEGIN, true)

	ActionLifecycleSystem.on_group_turn_begin(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_BEGIN, true)


func handle_group_turn_ended(group_index: int) -> void:
	var api := _api()
	if api == null:
		return

	SimStatusSystem.on_group_turn_end(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_END, true)

	ActionLifecycleSystem.on_group_turn_end(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_END, true)

	var writer := api.writer
	if writer != null:
		writer.emit_group_turn_end(group_index)
		writer.scope_end() # group_turn

	_schedule_next_group_turn(group_index)


func handle_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer == null:
		return

	writer.set_turn_context(
		engine._turn_token,
		engine.active_group_index,
		int(active_id)
	)
	writer.emit_turn_status(
		int(active_id),
		pending_ids,
		int(engine.active_group_index),
		int(api.get_player_id())
	)


func handle_actor_requested(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or host == null:
		return
	if api.state == null or api.state.has_terminal_outcome():
		return
	var writer := api.writer
	if writer != null:
		writer.set_turn_context(engine._turn_token, engine.active_group_index, cid)
		writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % cid, cid)
		writer.emit_actor_begin(cid)

	SimStatusSystem.on_actor_turn_begin(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	if is_player(cid):
		if writer != null:
			writer.emit_player_input_reached(int(cid))
		host.player_input_reached.emit()
		return

	if sim != null and sim.resolver != null:
		sim.resolver.resolve_npc_turn(api, cid)

	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	SimStatusSystem.on_actor_turn_end(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	engine.notify_actor_done(cid)


func handle_player_begin_requested(token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or turn_engine_host_sim == null:
		return

	var player_id := _player_id()
	if player_id > 0:
		SimStatusSystem.on_actor_turn_begin(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	engine.notify_player_begin_done(token)


func handle_player_end_requested(token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or turn_engine_host_sim == null:
		return

	var player_id := _player_id()

	engine.request_end_of_turn_arcana(func():
		engine.notify_player_end_done(token)

		SimStatusSystem.on_actor_turn_end(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

		_notify_actor_done(player_id)
	)


func handle_arcana_proc_requested(proc: int, token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer != null:
		writer.scope_begin(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
		writer.emit_arcana_proc(proc)

	var resolver := _ensure_arcana_resolver()
	if sim != null and sim.resolver != null and resolver != null:
		sim.resolver.resolve_arcana_proc(sim, proc, resolver)

	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ARCANA, true)

	if writer != null:
		writer.scope_end() # arcana

	engine.notify_arcana_proc_done(token)


# ============================================================================
# Internal flow helpers
# ============================================================================

func _schedule_next_group_turn(group_index: int) -> void:
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	
	var engine := _engine()
	if engine == null:
		return

	if group_index == 0:
		var finished_pre_player_friendly := bool(engine.ended_pre_player_friendly)

		if !finished_pre_player_friendly:
			start_group_turn(1, false)
		else:
			start_group_turn(0, false, false)
		return

	start_group_turn(0, false, true)


func _notify_actor_done(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	engine.notify_actor_done(cid)

func debug_kill_all_enemies() -> void:
	var api := _api()
	if api == null:
		return

	api.debug_kill_all_enemies()
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_CARD, true)


# ============================================================================
# Card Execution
# ============================================================================

func begin_card_execution(ctx: CardContext) -> bool:
	if ctx == null or ctx.finished:
		return false
	if ctx.card_data == null:
		return false

	ctx.action_states.clear()
	ctx.next_action_index = 0
	ctx.current_action_index = -1
	ctx.canceled = false
	ctx.finished = false
	ctx.card_scope_id = 0
	ctx.card_scope_opened = false
	ctx.card_play_committed = false
	ctx.interaction_payloads.clear()

	var actions: Array = ctx.card_data.actions
	for i in range(actions.size()):
		var action := actions[i] as CardAction
		if action == null:
			continue

		var st := CardActionExecutionState.new()
		st.action_index = i
		st.action = action
		st.interaction_mode = action.get_interaction_mode(ctx)
		st.state = CardActionExecutionState.State.PENDING
		ctx.action_states.append(st)

	return continue_card_execution(ctx)

#func begin_card_execution(ctx: CardContext) -> bool:
	#if ctx == null:
		#return false
#
	#initialize_card_context(ctx)
	#return continue_card_execution(ctx)

func continue_card_execution(ctx: CardContext) -> bool:
	if ctx == null or ctx.finished:
		return false
	if ctx.canceled:
		_finalize_card_execution(ctx)
		return false

	while ctx.next_action_index < ctx.action_states.size():
		var st: CardActionExecutionState = ctx.action_states[ctx.next_action_index]
		if st == null or st.action == null:
			ctx.next_action_index += 1
			continue

		ctx.current_action_index = st.action_index

		match int(st.state):
			CardActionExecutionState.State.EXECUTED, \
			CardActionExecutionState.State.SKIPPED:
				ctx.next_action_index += 1
				continue

			CardActionExecutionState.State.WAITING_INTERACTION:
				return true

			CardActionExecutionState.State.COVERED, \
			CardActionExecutionState.State.PENDING:
				if int(st.state) == int(CardActionExecutionState.State.PENDING) \
				and int(st.interaction_mode) != int(CardAction.InteractionMode.NONE):
					st.state = CardActionExecutionState.State.WAITING_INTERACTION
					if !st.action.activate_interaction(ctx):
						st.state = CardActionExecutionState.State.CANCELED
						ctx.canceled = true
						_finalize_card_execution(ctx)
						return false
					return true

				if !_commit_card_play_if_needed(ctx):
					ctx.canceled = true
					_finalize_card_execution(ctx)
					return false

				if !execute_card_action(ctx, st.action_index):
					st.state = CardActionExecutionState.State.CANCELED
					ctx.canceled = true
					_finalize_card_execution(ctx)
					return false

				st.state = CardActionExecutionState.State.EXECUTED
				ctx.next_action_index += 1
				continue

			CardActionExecutionState.State.CANCELED:
				ctx.canceled = true
				_finalize_card_execution(ctx)
				return false

	ctx.finished = true
	_finalize_card_execution(ctx)
	return true

func execute_card_action(ctx: CardContext, action_index: int) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null or st.action == null:
		return false

	ctx.current_action_index = action_index
	return st.action.activate_sim(ctx)

func cover_waiting_action_and_continue(
	ctx: CardContext,
	action_index: int,
	payload: Dictionary = {}
) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null or st.action == null:
		return false
	if int(st.state) != int(CardActionExecutionState.State.WAITING_INTERACTION):
		return false

	if !payload.is_empty():
		ctx.interaction_payloads[action_index] = payload.duplicate(true)

	st.state = CardActionExecutionState.State.COVERED
	ctx.current_action_index = action_index

	# Execute the just-covered action now.
	if !_commit_card_play_if_needed(ctx):
		st.state = CardActionExecutionState.State.CANCELED
		ctx.canceled = true
		_finalize_card_execution(ctx)
		return false

	if !execute_card_action(ctx, action_index):
		st.state = CardActionExecutionState.State.CANCELED
		ctx.canceled = true
		_finalize_card_execution(ctx)
		return false

	st.state = CardActionExecutionState.State.EXECUTED
	ctx.next_action_index = action_index + 1

	return continue_card_execution(ctx)

func cancel_waiting_action(ctx: CardContext, action_index: int) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null:
		return false

	st.state = CardActionExecutionState.State.CANCELED
	ctx.canceled = true
	ctx.finished = true
	_finalize_card_execution(ctx, false)
	return false


func mark_action_skipped(ctx: CardContext, action_index: int) -> void:
	if ctx == null:
		return
	if action_index < 0 or action_index >= ctx.action_states.size():
		return

	var state: CardActionExecutionState = ctx.action_states[action_index]
	if state == null:
		return

	state.state = CardActionExecutionState.State.SKIPPED


func append_affected_id(ctx: CardContext, cid: int) -> void:
	if ctx == null or cid <= 0:
		return
	if !_packed_has_int(ctx.affected_ids, cid):
		ctx.affected_ids.append(cid)


func append_summoned_id(ctx: CardContext, cid: int) -> void:
	if ctx == null or cid <= 0:
		return
	if !_packed_has_int(ctx.summoned_ids, cid):
		ctx.summoned_ids.append(cid)
	if !_packed_has_int(ctx.affected_ids, cid):
		ctx.affected_ids.append(cid)

func get_action_interaction_payload(ctx: CardContext, action_index: int) -> Dictionary:
	if ctx == null:
		return {}
	if !ctx.interaction_payloads.has(action_index):
		return {}
	var d = ctx.interaction_payloads[action_index]
	return d.duplicate(true) if d is Dictionary else {}

# ============================================================================
# Card Execution Helpers
# ============================================================================

func _ensure_card_scope_open(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.card_scope_opened:
		return true

	var label := "card"
	if ctx.card_data != null:
		label = "uid=%s %s" % [String(ctx.card_data.uid), String(ctx.card_data.name)]

	ctx.card_scope_id = ctx.api.writer.scope_begin(
		Scope.Kind.CARD,
		label,
		int(ctx.source_id),
		{}
	)
	ctx.card_scope_opened = (ctx.card_scope_id > 0)
	return ctx.card_scope_opened

func _commit_card_play_if_needed(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.source_card == null or ctx.card_data == null:
		return false

	if ctx.card_play_committed:
		return true

	if !_ensure_card_scope_open(ctx):
		return false

	if !ctx.emitted_card_played:
		ctx.api.writer.emit_card_played_ctx(ctx)
		ctx.emitted_card_played = true

	if !ctx.mana_spent:
		var cost := int(ctx.card_data.get_total_cost())
		if !ctx.api.spend_mana_for_card(int(ctx.source_id), ctx.card_data):
			return false
		ctx.mana_spent = true

	ctx.card_play_committed = true
	return true

func _close_card_scope(ctx: CardContext) -> void:
	if ctx == null or ctx.api == null:
		return
	if !ctx.card_scope_opened:
		return

	ctx.api.writer.scope_end()
	ctx.card_scope_opened = false
	ctx.card_scope_id = 0

func _maybe_commit_card_play(ctx: CardContext) -> bool:
	if ctx == null:
		return false

	if !ctx.mana_spent:
		if !_spend_card_mana(ctx):
			return false
		ctx.mana_spent = true

	if !ctx.emitted_card_played:
		_emit_card_played(ctx)
		ctx.emitted_card_played = true

	return true


func _spend_card_mana(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.card_data == null:
		return false
	return ctx.api.spend_mana_for_card(ctx.source_id, ctx.card_data)


func _emit_card_played(ctx: CardContext) -> void:
	if ctx == null or ctx.api == null:
		return
	ctx.api.emit_card_played_ctx(ctx)


func _finalize_card_execution(ctx: CardContext, committed := true) -> void:
	if ctx == null:
		return

	_close_card_scope(ctx)
	if ctx.source_card != null:
		ctx.source_card.end_activation(committed)
	ctx.current_action_index = -1
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_CARD)


func _packed_has_int(arr: PackedInt32Array, value: int) -> bool:
	for x in arr:
		if int(x) == int(value):
			return true
	return false


func _ctx_card_name(ctx: CardContext) -> String:
	if ctx == null or ctx.card_data == null:
		return "<no card>"
	return String(ctx.card_data.name)
