# turn_state.gd

class_name TurnState extends RefCounted

var active_group: int = 0  # 0 friendly, 1 enemy
var round: int = 1

# queue for the current group turn, in execution order
var queue: PackedInt32Array = PackedInt32Array()
var active_id: int = 0

# bookkeeping
var acted_this_group_turn: Dictionary = {} # combat_id -> true
