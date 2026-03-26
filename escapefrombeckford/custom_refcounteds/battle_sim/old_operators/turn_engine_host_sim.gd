# turn_flow_query_host.gd
class_name TurnFlowQueryHost extends RefCounted

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
# Query surface used by TurnEngineCore
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
