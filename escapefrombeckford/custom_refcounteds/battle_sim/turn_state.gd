# turn_state.gd
class_name TurnState extends RefCounted

var active_group: int = 0  # 0 friendly, 1 enemy
var round: int = 1

# Queue for the current group turn, in execution order.
# Usually rebuilt at group-turn start, then popped/advanced.
var queue: PackedInt32Array = PackedInt32Array()
var active_id: int = 0

# bookkeeping: combat_id -> number of actions taken this group turn
var actions_this_group_turn: Dictionary = {} # int -> int
# If anything should ever modify the turn "budget", it should not be tracked
# by this variable: but something like "bonus_actions"

func reset_group_turn() -> void:
	queue = PackedInt32Array()
	active_id = 0
	actions_this_group_turn.clear()

func get_actions_taken(id: int) -> int:
	return int(actions_this_group_turn.get(id, 0))

func mark_action_taken(id: int, n: int = 1) -> void:
	if id <= 0:
		return
	n = maxi(int(n), 0)
	if n == 0:
		return
	actions_this_group_turn[id] = get_actions_taken(id) + n

func has_acted(id: int) -> bool:
	return get_actions_taken(id) > 0

# Optional: useful for “can act again?” rules
func can_act(id: int, max_actions: int = 1) -> bool:
	return get_actions_taken(id) < max_actions

func clone() -> TurnState:
	var t := TurnState.new()
	t.active_group = active_group
	t.round = round
	t.queue = queue.duplicate()
	t.active_id = active_id
	t.actions_this_group_turn = actions_this_group_turn.duplicate(true)
	return t
