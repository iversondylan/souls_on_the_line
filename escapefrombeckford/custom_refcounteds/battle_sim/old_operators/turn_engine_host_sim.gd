# turn_engine_host_sim.gd
class_name TurnEngineHostSim extends RefCounted

var sim: Sim
var sim_host: SimHost

func _init(_sim: Sim = null, _sim_host: SimHost = null) -> void:
	sim = _sim
	sim_host = _sim_host


func bind(_sim: Sim, _sim_host: SimHost) -> void:
	sim = _sim
	sim_host = _sim_host


# -------------------------
# Internal: get BattleState
# -------------------------
func _get_state() -> BattleState:
	if sim == null:
		return null
	return sim.state


# -------------------------
# TurnEngineHost overrides
# -------------------------
func get_player_id() -> int:
	var s := _get_state()
	if s == null:
		return 0
	return int(s.groups[0].player_id)

func is_player(combat_id: int) -> bool:
	return int(combat_id) != 0 and int(combat_id) == get_player_id()

func get_group_order_ids(group_index: int) -> PackedInt32Array:
	var s := _get_state()
	if s == null:
		return PackedInt32Array()
	group_index = clampi(group_index, 0, 1)
	# Return a copy to avoid accidental mutation by callers
	return s.groups[group_index].order.duplicate()

func get_group_index_of(combat_id: int) -> int:
	var s := _get_state()
	if s == null:
		return -1
	var u := s.get_unit(int(combat_id))
	if u == null:
		return -1
	return int(u.team)

func is_alive(combat_id: int) -> bool:
	var s := _get_state()
	if s == null:
		return false
	return bool(s.is_alive(int(combat_id)))


# -------------------------
# Player boundary hooks (SIM)
# -------------------------
func begin_player_turn_async() -> void:
	# Do sim-side “start of player turn” bookkeeping synchronously.
	# This should NOT do hand draw. It should be purely state mutation.
	if sim_host != null:
		if sim_host.has_method("begin_player_turn_sim"):
			sim_host.begin_player_turn_sim()
		elif sim_host.has_method("begin_player_turn_headless"):
			sim_host.begin_player_turn_headless()
		elif sim_host.has_method("begin_player_turn"):
			sim_host.begin_player_turn()

	# Ensure this function is always awaitable (coroutine) even if work was immediate.
	await _coroutine_marker()

func end_player_turn_async() -> void:
	# Optional for now; keep shape consistent.
	if sim_host != null:
		if sim_host.has_method("end_player_turn_sim"):
			sim_host.end_player_turn_sim()
		elif sim_host.has_method("end_player_turn_headless"):
			sim_host.end_player_turn_headless()
		elif sim_host.has_method("end_player_turn"):
			sim_host.end_player_turn()

	await _coroutine_marker()

func _coroutine_marker() -> void:
	# This makes the function a coroutine in Godot 4.x without actually yielding.
	if false:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame
