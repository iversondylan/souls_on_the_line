# turn_engine_host.gd

class_name TurnEngineHost extends RefCounted

func get_group_order_ids(group_index: int) -> PackedInt32Array:
	return PackedInt32Array()

func get_group_index_of(combat_id: int) -> int:
	return -1

func is_alive(combat_id: int) -> bool:
	return false

func is_player(combat_id: int) -> bool:
	return false

func get_player_id() -> int:
	return 0
