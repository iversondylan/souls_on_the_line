# battle_group_friendly.gd
class_name BattleGroupFriendly extends BattleGroup

var player: Player

func _ready() -> void:
	Events.first_friendly_turn_started.connect(_on_first_friendly_turn_started)
	Events.friendly_turn_started.connect(_on_friendly_turn_started)

func start_first_friendly_turn() -> void:
	if get_child_count() == 0:
		print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		return
	acting_fighters.clear()
	var reached_player: bool = false
	for fighter: Fighter in get_children():
		if fighter is Player and !reached_player:
			reached_player = true
		if reached_player:
			acting_fighters.append(fighter)
	_next_turn_taker()

func ally_traverse_player(ally: SummonedAlly) -> void:
	var ally_index: int = ally.get_index()
	var player_index: int = player.get_index()
	if ally_index > player_index:
		move_child(ally, 0)
		acting_fighters.erase(ally)
	elif ally_index < player_index:
		move_child(ally, player_index)
		acting_fighters.insert(1, ally)
	update_combatant_position()
		

func get_n_summoned_allies() -> int:
	var n_allies: int = 0
	for child in get_children():
		if child is SummonedAlly:
			n_allies += 1
	return n_allies

func _on_friendly_turn_started() -> void:
	for fighter: Fighter in get_combatants():
		fighter.turn_reset()
	start_turn()

func _on_first_friendly_turn_started() -> void:
	start_first_friendly_turn()
