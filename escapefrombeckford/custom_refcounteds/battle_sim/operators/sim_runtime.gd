# sim_runtime.gd

class_name SimRuntime extends RefCounted

var sim: Sim
var host: SimHost

var arcana_resolver: ArcanaResolver
var card_executor: CardExecutor

func _init(_sim: Sim = null, _host: SimHost = null) -> void:
	sim = _sim
	host = _host


func bind(_sim: Sim, _host: SimHost) -> void:
	sim = _sim
	host = _host

func start_group_turn(group_index: int, start_at_player := false, friendly_post_enemy := false) -> void:
	if host == null:
		return
	host.start_group_turn(group_index, start_at_player, friendly_post_enemy)

func request_player_end() -> void:
	if sim == null or sim.api == null:
		return

	var writer := sim.api.writer
	if writer != null:
		writer.emit_end_turn_pressed(sim.api.get_player_id())

func add_combatant_from_data(data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	if sim == null or sim.api == null:
		return 0
	return sim.api.spawn_from_data(data, group_index, insert_index, is_player)

func handle_group_turn_started(group_index: int) -> void:
	if sim == null or sim.api == null:
		return
	if host == null or host.turn_engine == null:
		return

	var writer := sim.api.writer
	if writer != null:
		writer.set_turn_context(host.turn_engine._turn_token, group_index, 0)
		writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		writer.emit_group_turn_begin(group_index)

	sim.api.on_group_turn_begin(group_index)


func handle_group_turn_ended(group_index: int) -> void:
	if sim == null or sim.api == null:
		return

	sim.api.on_group_turn_end(group_index)

	var writer := sim.api.writer
	if writer != null:
		writer.emit_group_turn_end(group_index)
		writer.scope_end()

	_schedule_next_group_turn(group_index)

func _schedule_next_group_turn(group_index: int) -> void:
	if host == null or host.turn_engine == null:
		return

	if group_index == 0:
		var finished_post := bool(host.turn_engine.ended_friendly_post_enemy)
		if !finished_post:
			host.start_group_turn(1, false)
		else:
			host.start_group_turn(0, false, false)
		return

	host.start_group_turn(0, false, true)

func handle_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	if sim == null or sim.api == null:
		return
	if host == null or host.turn_engine == null:
		return

	var writer := sim.api.writer
	if writer == null:
		return

	writer.set_turn_context(
		host.turn_engine._turn_token,
		host.turn_engine.active_group_index,
		int(active_id)
	)
	writer.emit_turn_status(
		int(active_id),
		pending_ids,
		int(host.turn_engine.active_group_index)
	)


func handle_actor_requested(cid: int) -> void:
	if host == null or sim == null:
		return
	if sim.api == null:
		return

	var api := sim.api
	var writer := api.writer
	var turn_engine := host.turn_engine

	if writer != null and turn_engine != null:
		writer.set_turn_context(turn_engine._turn_token, turn_engine.active_group_index, cid)
		writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % cid, cid)
		writer.emit_actor_begin(cid)

	SimStatusLifecycleRunner.on_actor_turn_begin(api, cid)

	if host.is_player(cid):
		if writer != null:
			writer.emit_player_input_reached(int(cid))
		host.player_input_reached.emit()
		return

	if sim.resolver != null:
		sim.resolver.resolve_npc_turn(sim, cid)

	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end()

	SimStatusLifecycleRunner.on_actor_turn_end(api, cid)

	if turn_engine != null:
		turn_engine.notify_actor_done(cid)


func handle_player_begin_requested(token: int) -> void:
	if host == null or sim == null or sim.api == null:
		return
	if host.turn_engine == null or host.turn_engine_host_sim == null:
		return

	var player_id := host.turn_engine_host_sim.get_player_id()

	if player_id > 0:
		SimStatusLifecycleRunner.on_actor_turn_begin(sim.api, player_id)

	if host.sim_host_has_begin_player_turn():
		host._call_sim_begin_player_turn()

	host.turn_engine.notify_player_begin_done(token)


func handle_player_end_requested(token: int) -> void:
	if host == null or sim == null or sim.api == null:
		return
	if host.turn_engine == null or host.turn_engine_host_sim == null:
		return

	if host.sim_host_has_end_player_turn():
		host._call_sim_end_player_turn()

	var player_id := host.turn_engine_host_sim.get_player_id()
	host.turn_engine.request_end_of_turn_arcana(func():
		host.turn_engine.notify_player_end_done(token)

		SimStatusLifecycleRunner.on_actor_turn_end(sim.api, player_id)
		if sim.checkpoint_processor != null:
			sim.checkpoint_processor.flush(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, sim, true)

		_notify_actor_done(player_id)
	)


func handle_arcana_proc_requested(proc: int, token: int) -> void:
	if host == null or sim == null or sim.api == null:
		return

	var writer := sim.api.writer
	if writer != null:
		writer.scope_begin(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
		writer.emit_arcana_proc(proc)

	if arcana_resolver == null:
		if host.arcana_catalog == null:
			push_warning("SimRuntime: no arcana_catalog; cannot run arcana")
		else:
			arcana_resolver = ArcanaResolver.new(host, host.arcana_catalog)

	if sim.resolver != null and arcana_resolver != null:
		sim.resolver.resolve_arcana_proc(sim, proc, arcana_resolver)

	if writer != null:
		writer.scope_end() # arcana

	if host.turn_engine != null:
		host.turn_engine.notify_arcana_proc_done(token)


func apply_player_card(req: CardPlayRequest) -> bool:
	if sim == null or sim.api == null:
		return false
	if sim.resolver == null:
		return false

	if card_executor == null:
		card_executor = CardExecutor.new()

	return sim.resolver.resolve_player_card(sim, req, card_executor)


func reset_runtime_state() -> void:
	arcana_resolver = null
	card_executor = null


func _notify_actor_done(cid: int) -> void:
	if host == null or sim == null or sim.api == null:
		return

	var writer := sim.api.writer
	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	if host.turn_engine != null:
		host.turn_engine.notify_actor_done(cid)
