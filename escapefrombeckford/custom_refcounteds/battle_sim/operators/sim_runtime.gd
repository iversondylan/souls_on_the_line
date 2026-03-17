# sim_runtime.gd

class_name SimRuntime extends RefCounted

var sim: Sim
var host: SimHost

func _init(_sim: Sim = null, _host: SimHost = null) -> void:
	sim = _sim
	host = _host


func bind(_sim: Sim, _host: SimHost) -> void:
	sim = _sim
	host = _host


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
