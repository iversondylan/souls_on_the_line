class_name BattlePool extends Resource

@export var pool: Array[BattleData]

var total_weights_by_tier: Array[float] = [0.0, 0.0, 0.0]

func _get_all_battles_for_tier(tier: int) -> Array[BattleData]:
	return pool.filter(
		func(battle: BattleData):
			return battle.battle_tier == tier
	)

func _make_weight_for_tier(tier: int) -> void:
	var battles: Array[BattleData] = _get_all_battles_for_tier(tier)
	total_weights_by_tier[tier] = 0.0
