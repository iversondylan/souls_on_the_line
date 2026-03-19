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
	if sim == null or sim.checkpoint_processor == null:
		return
	sim.checkpoint_processor.request_followup_flush()

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
		int(engine.active_group_index)
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
