# battle_pool.gd

class_name BattlePool extends Resource


@export var pool: Array[BattleData]

func init_weights(_rng: RNG) -> void:
	pass


func get_random_battle_for_tier(rng: RNG, tier: int, excluded_resource_paths: PackedStringArray = PackedStringArray()) -> BattleData:
	var resolved_tier := _get_fallback_tier(tier, excluded_resource_paths)
	if resolved_tier < 0:
		return null

	var battles: Array[BattleData] = _get_all_battles_for_tier(resolved_tier, excluded_resource_paths)
	if battles.is_empty():
		return null

	var total_weight := 0.0
	for battle: BattleData in battles:
		total_weight += float(battle.weight)

	if total_weight <= 0.0:
		push_warning("[BattlePool] total weight <= 0 for tier=%d" % resolved_tier)
		return battles[0]

	var roll: float = (rng.debug_range_f(0.0, total_weight, "battle_pool.roll.tier=%d" % resolved_tier) if rng != null else randf_range(0.0, total_weight))
	var accumulated_weight := 0.0

	for battle: BattleData in battles:
		accumulated_weight += float(battle.weight)
		if accumulated_weight > roll:
			return battle

	return battles[-1]

func _get_fallback_tier(tier: int, excluded_resource_paths: PackedStringArray = PackedStringArray()) -> int:
	var candidate_tiers := _get_available_tiers()
	candidate_tiers.sort()

	for candidate_tier in candidate_tiers:
		if int(candidate_tier) < int(tier):
			continue
		if !_get_all_battles_for_tier(int(candidate_tier), excluded_resource_paths).is_empty():
			return int(candidate_tier)

	return -1

func _get_available_tiers() -> Array[int]:
	var out: Array[int] = []
	var seen := {}

	for battle: BattleData in pool:
		if battle == null:
			continue
		var battle_tier := int(battle.battle_tier)
		if seen.has(battle_tier):
			continue
		seen[battle_tier] = true
		out.append(battle_tier)

	return out

func _get_all_battles_for_tier(tier: int, excluded_resource_paths: PackedStringArray = PackedStringArray()) -> Array[BattleData]:
	return pool.filter(
		func(battle: BattleData):
			if battle == null:
				return false
			return battle.battle_tier == tier and !excluded_resource_paths.has(String(battle.resource_path))
	)
