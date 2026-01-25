# turn_order_path.gd
class_name TurnOrderPath
extends RefCounted

var player_pos: Vector2
var middle_pos: Vector2

# Lists of positions in traversal order
var behind_friendlies: Array[Vector2] = []
var enemies_front_to_back: Array[Vector2] = []
var in_front_friendlies: Array[Vector2] = []


func is_valid() -> bool:
	# Must at least have player + middle.
	return player_pos != Vector2.ZERO or middle_pos != Vector2.ZERO

func print_path() -> void:
	print("---- TurnOrderPath ----")
	print("player_pos: ", player_pos, "   middle_pos: ", middle_pos)

	print("behind_friendlies (", behind_friendlies.size(), "):")
	for i in range(behind_friendlies.size()):
		print("  [", i, "] ", behind_friendlies[i])

	print("enemies_front_to_back (", enemies_front_to_back.size(), "):")
	for i in range(enemies_front_to_back.size()):
		print("  [", i, "] ", enemies_front_to_back[i])

	print("in_front_friendlies (", in_front_friendlies.size(), "):")
	for i in range(in_front_friendlies.size()):
		print("  [", i, "] ", in_front_friendlies[i])

	print("-----------------------")
