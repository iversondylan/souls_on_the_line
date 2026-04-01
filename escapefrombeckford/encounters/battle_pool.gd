# battle_pool.gd

class_name BattlePool extends Resource


@export var pool: Array[BattleData]

func init_weights(_rng: RNG) -> void:
	pass


func get_random_battle_for_tier(rng: RNG, tier: int, excluded_resource_paths: PackedStringArray = PackedStringArray()) -> BattleData:
	var battles: Array[BattleData] = _get_all_battles_for_tier(tier, excluded_resource_paths)
	if battles.is_empty():
		return null

	var total_weight := 0.0
	for battle: BattleData in battles:
		total_weight += float(battle.weight)

	if total_weight <= 0.0:
		push_warning("[BattlePool] total weight <= 0 for tier=%d" % tier)
		return battles[0]

	var roll: float = (rng.debug_range_f(0.0, total_weight, "battle_pool.roll.tier=%d" % tier) if rng != null else randf_range(0.0, total_weight))
	var accumulated_weight := 0.0

	for battle: BattleData in battles:
		accumulated_weight += float(battle.weight)
		if accumulated_weight > roll:
			return battle

	return battles[-1]

func _get_all_battles_for_tier(tier: int, excluded_resource_paths: PackedStringArray = PackedStringArray()) -> Array[BattleData]:
	return pool.filter(
		func(battle: BattleData):
			if battle == null:
				return false
			return battle.battle_tier == tier and !excluded_resource_paths.has(String(battle.resource_path))
	)
