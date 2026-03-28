# shop_context.gd
class_name ShopContext extends RefCounted

const MIN_SHOP_COST := 0

var run: Run
var run_state: RunState
var player_data: PlayerData
var arcana_system: ArcanaSystem
var arcana_catalog: ArcanaCatalog
var arcana_reward_pool: ArcanaRewardPool

var card_offers: Array[CardData] = []
var card_offer_costs: Array[int] = []
var claimed_card_offer_indices: Array[int] = []
var arcanum_offers: Array[Arcanum] = []
var arcanum_offer_costs: Array[int] = []
var claimed_arcanum_offer_indices: Array[int] = []

func apply_card_discount_percent(discount_percent: float, min_cost: int = MIN_SHOP_COST) -> void:
	card_offer_costs = _apply_discount_percent(card_offer_costs, discount_percent, min_cost)

func apply_arcanum_discount_percent(discount_percent: float, min_cost: int = MIN_SHOP_COST) -> void:
	arcanum_offer_costs = _apply_discount_percent(arcanum_offer_costs, discount_percent, min_cost)

func apply_all_discount_percent(discount_percent: float, min_cost: int = MIN_SHOP_COST) -> void:
	apply_card_discount_percent(discount_percent, min_cost)
	apply_arcanum_discount_percent(discount_percent, min_cost)

func clamp_all_costs(min_cost: int = MIN_SHOP_COST) -> void:
	card_offer_costs = _clamp_costs(card_offer_costs, min_cost)
	arcanum_offer_costs = _clamp_costs(arcanum_offer_costs, min_cost)

func _apply_discount_percent(costs: Array[int], discount_percent: float, min_cost: int) -> Array[int]:
	var multiplier := maxf(0.0, 1.0 - (discount_percent / 100.0))
	var result: Array[int] = []
	for cost in costs:
		result.append(maxi(min_cost, floori(cost * multiplier)))
	return result

func _clamp_costs(costs: Array[int], min_cost: int) -> Array[int]:
	var result: Array[int] = []
	for cost in costs:
		result.append(maxi(min_cost, cost))
	return result
