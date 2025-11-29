class_name BattleGroupEnemy extends BattleGroup

func _ready() -> void:
	Events.enemy_turn_started.connect(_on_enemy_turn_started)
	#Events.reset_enemies.connect(turn_reset)

func _on_enemy_turn_started() -> void:
	for fighter: Fighter in get_combatants():
		fighter.turn_reset()
	start_turn()
