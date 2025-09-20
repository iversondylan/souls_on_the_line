class_name BattleGroupEnemy extends BattleGroup

func _ready() -> void:
	turn_taker = $EnemyTurnTerminal
	Events.enemy_turn_started.connect(_on_enemy_turn_started)
	update_combatant_rank_variable()

func reboot_turn_taker(next_turn_taker: TurnTaker) -> void:
	if BattleController.current_state != BattleController.BattleState.ENEMY_TURN:
		return
	turn_taker = next_turn_taker
	turn_taker.enter()

func _on_turn_taker_turn_complete(turn_taker_who_finished: TurnTaker) -> void:
	if BattleController.current_state != BattleController.BattleState.ENEMY_TURN:
		return
	next_turn_taker(turn_taker_who_finished)

func _on_enemy_turn_started() -> void:
	start_turn()
