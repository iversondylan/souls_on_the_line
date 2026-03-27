# turn_order_snapshot.gd
class_name TurnOrderSnapshot
extends RefCounted

# Each entry is a Dictionary:
# {
#   "pos": Vector2,
#   "id": int,
#   "is_player": bool,
#   "is_summon": bool,
#   "is_enemy": bool,
# }
var friendly: Array[Dictionary] = []
var enemy: Array[Dictionary] = []

# Index of the Player within `friendly` (front->back order). -1 if not found.
var player_index: int = -1


func is_valid() -> bool:
	return player_index >= 0 and not friendly.is_empty()

func get_friendly_count() -> int:
	return friendly.size()

func get_enemy_count() -> int:
	return enemy.size()

func get_player_entry() -> Dictionary:
	if player_index < 0 or player_index >= friendly.size():
		return {}
	return friendly[player_index]

# Convenience slices (front->back ordering)
func get_friendlies_in_front_of_player() -> Array[Dictionary]:
	# "in front" = indices < player_index
	if player_index <= 0:
		return []
	return friendly.slice(0, player_index)

func get_friendlies_behind_player() -> Array[Dictionary]:
	# "behind" = indices > player_index
	if player_index < 0 or player_index >= friendly.size() - 1:
		return []
	return friendly.slice(player_index + 1, friendly.size())

func get_enemy_front_to_back() -> Array[Dictionary]:
	return enemy.duplicate()

func clear() -> void:
	friendly.clear()
	enemy.clear()
	player_index = -1
