class_name BattleGroupFriendly extends BattleGroup

var player: Player

func _ready() -> void:
	#turn_taker = $FriendlyTurnTerminal
	#Events.combatant_died.connect(_combatant_died)
	#Events.combatant_actions_completed.connect(_on_combatant_actions_completed)
	Events.friendly_turn_started.connect(_on_friendly_turn_started)
	#Events.enemy_turn_started.connect(_on_enemy_turn_started)
	#Events.turn_taker_turn_completed.connect(_on_turn_taker_turn_complete) #MUST RESTORE THIS!!!!!!
	#Events.npc_action_completed.connect(_on_npc_action_completed)
	#update_combatant_rank_variable()

func reboot_turn_taker(next_turn_taker: TurnTaker) -> void:
	if BattleController.current_state != BattleController.BattleState.FRIENDLY_TURN:
		return
	turn_taker = next_turn_taker
	turn_taker.enter()

func ally_traverse_player(ally: SummonedAlly) -> void:
	var ally_index: int = ally.get_index()
	var player_index: int = player.get_index()
	if ally_index > player_index:
		move_child(ally, 0)
		acting_fighters.erase(ally)
	elif ally_index < player_index:
		move_child(ally, player_index)
		acting_fighters.insert(1, ally)
	#update_combatant_rank_variable()
	make_turn_table()
	update_combatant_position()
		

func get_n_summoned_allies() -> int:
	var n_allies: int = 0
	for child in get_children():
		if child is SummonedAlly:
			n_allies += 1
	return n_allies

func _on_friendly_turn_started() -> void:
	start_turn()
