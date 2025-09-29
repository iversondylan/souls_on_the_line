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
	
	for battle: BattleData in battles:
		total_weights_by_tier[tier] += battle.weight
		battle.accumulated_weight = total_weights_by_tier[tier]

func get_random_battle_for_tier(tier: int) -> BattleData:
	var roll: float = randf_range(0.0, total_weights_by_tier[tier])
	var battles: Array[BattleData] = _get_all_battles_for_tier(tier)
	
	for battle: BattleData in battles:
		if battle.accumulated_weight > roll:
			return battle
	return null

func init_weights() -> void:
	for i in 3:
		_make_weight_for_tier(i)
