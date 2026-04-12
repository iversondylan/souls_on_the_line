class_name BattleData extends Resource

@export var encounter_name: String
@export_range(0, 2) var battle_tier: int
@export_range(0.0, 10.0) var weight: float = 1
@export var gold_reward_min: int
@export var gold_reward_max: int
@export var enemies: Array[CombatantData]
@export var encounter_definition: Resource

var accumulated_weight: float = 0.0

func roll_gold_reward() -> int:
	return randi_range(gold_reward_min, gold_reward_max)


func roll_gold_reward_with_rng(rng: RNG) -> int:
	if rng == null:
		return roll_gold_reward()
	return rng.debug_range_i(gold_reward_min, gold_reward_max, "battle_gold_reward")
