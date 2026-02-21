# battle_group_friendly.gd

class_name BattleGroupFriendly extends BattleGroup

const MAX_SOULBOUND := 3

var player: Player

func _ready() -> void:
	pass

func start_first_friendly_turn() -> void:
	print("deprecated start_first_friendly_turn")
	pass
	#if get_child_count() == 0:
		#print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		#return
	#_restored_turn_this_group_turn.clear()
	##acting_fighters.clear()
	#var reached_player: bool = false
	#for fighter: Fighter in get_combatants():
		#if fighter is Player and !reached_player:
			#reached_player = true
		##if reached_player:
			##acting_fighters.append(fighter)
	#_update_pending_turn_glow()
	##_next_turn_taker()

func _traverse_player(ally: Fighter) -> void:
	if !player or !ally:
		return

	var ally_index: int = ally.get_index()
	var player_index: int = player.get_index()

	# If behind player, traverse to the front
	if ally_index > player_index:
		move_child(ally, 0)
	# If in front of player, traverse to behind (right after player)
	elif ally_index < player_index:
		move_child(ally, player_index)


func get_n_summoned_allies() -> int:
	var n_allies: int = 0
	for child in get_combatants():
		if child is SummonedAlly:
			n_allies += 1
	return n_allies

func _on_friendly_turn_started() -> void:
	pass

func _on_first_friendly_turn_started() -> void:
	pass
