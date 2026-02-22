# turn_engine_host_sim.gd
class_name TurnEngineHostSim extends TurnEngineHost

var sim_host: SimHost	# SimHost extends Node

func _init(_sim_host: Node) -> void:
	sim_host = _sim_host


# -------------------------
# Internal: get BattleState
# -------------------------
func _get_state() -> BattleState:
	if sim_host == null:
		return null

	# Preferred: method
	if sim_host.has_method("get_main_state"):
		return sim_host.call("get_main_state")

	# Common: property
	if "main_state" in sim_host:
		return sim_host.main_state

	# Fallback: property name you might use
	if "state" in sim_host:
		return sim_host.state

	return null


# -------------------------
# TurnEngineHost overrides
# -------------------------
func get_player_id() -> int:
	var s := _get_state()
	if s == null:
		return 0
	# Your GroupState has player_id
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
func begin_player_turn_async() -> Variant:
	# Do sim-side “start of player turn” bookkeeping synchronously,
	# then return an awaitable signal so TurnEngineCore can `await`.
	if sim_host != null:
		# If you implement this on SimHost, this is the cleanest call.
		# It should do: reset armor/mana, etc — but NO hand draw.
		if sim_host.has_method("begin_player_turn_sim"):
			sim_host.call("begin_player_turn_sim")
		elif sim_host.has_method("begin_player_turn_headless"):
			sim_host.call("begin_player_turn_headless")
		elif sim_host.has_method("begin_player_turn"):
			# if you name it generically
			sim_host.call("begin_player_turn")

	return _await_next_tick()

func end_player_turn_async() -> Variant:
	# Optional for now; keep it consistent with the core’s expectations.
	if sim_host != null:
		if sim_host.has_method("end_player_turn_sim"):
			sim_host.call("end_player_turn_sim")
		elif sim_host.has_method("end_player_turn_headless"):
			sim_host.call("end_player_turn_headless")
		elif sim_host.has_method("end_player_turn"):
			sim_host.call("end_player_turn")

	return _await_next_tick()
