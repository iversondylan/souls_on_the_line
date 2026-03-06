# battle_pool.gd

class_name BattlePool extends Resource


@export var pool: Array[BattleData]

var total_weights_by_tier: Array[float] = [0.0, 0.0, 0.0]


func init_weights(rng: RNG) -> void:
	for i in 3:
		_make_weight_for_tier(i)
	
	#if rng != null:
		#print("[BattlePool] init_weights done (rng seed=%d rolls=%d)" % [rng.seed, rng.rolls])

func get_random_battle_for_tier(rng: RNG, tier: int) -> BattleData:
	var battles: Array[BattleData] = _get_all_battles_for_tier(tier)
	if battles.is_empty():
		push_warning("[BattlePool] no battles for tier=%d" % tier)
		return null

	var maxw := float(total_weights_by_tier[tier])
	if maxw <= 0.0:
		push_warning("[BattlePool] total weight <= 0 for tier=%d" % tier)
		return battles[0]

	var roll: float = (rng.debug_range_f(0.0, maxw, "battle_pool.roll.tier=%d" % tier) if rng != null else randf_range(0.0, maxw))

	for battle: BattleData in battles:
		if battle.accumulated_weight > roll:
			#print("[BattlePool] tier=%d roll=%s -> %s" % [tier, str(roll), battle.encounter_name])
			return battle

	#print("[BattlePool] tier=%d roll=%s -> fallback %s" % [tier, str(roll), battles[-1].encounter_name])
	return battles[-1]

func _get_all_battles_for_tier(tier: int) -> Array[BattleData]:
	#print("battle_pool.gd _get_all_battles_for_tier() tier: ", tier)
	return pool.filter(
		func(battle: BattleData):
			#print("filtering %s = %s" % [battle.encounter_name, battle.battle_tier == tier])
			return battle.battle_tier == tier
	)

func _make_weight_for_tier(tier: int) -> void:
	var battles: Array[BattleData] = _get_all_battles_for_tier(tier)
	total_weights_by_tier[tier] = 0.0
	
	for battle: BattleData in battles:
		total_weights_by_tier[tier] += battle.weight
		battle.accumulated_weight = total_weights_by_tier[tier]

#func get_random_battle_for_tier(tier: int) -> BattleData:
	##print("battle_pool.gd get_random_battle_for_tier() tier: ", tier)
	#var roll: float = randf_range(0.0, total_weights_by_tier[tier])
	#var battles: Array[BattleData] = _get_all_battles_for_tier(tier)
	#
	#for battle: BattleData in battles:
		#if battle.accumulated_weight > roll:
			#return battle
	#return null
#
#func init_weights() -> void:
	#for i in 3:
		#_make_weight_for_tier(i)
