class_name BattleGroupEnemy extends BattleGroup

func _ready() -> void:
	Events.enemy_turn_started.connect(_on_enemy_turn_started)

func _on_enemy_turn_started() -> void:
	start_turn()
