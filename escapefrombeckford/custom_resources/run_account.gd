class_name RunAccount extends Resource

signal gold_changed

const BASE_STARTING_GOLD : int = 50
const BASE_CARD_REWARD_CHOICES := 3
const BASE_COMMON_WEIGHT := 6.0
const BASE_UNCOMMON_WEIGHT := 3.7
const BASE_RARE_WEIGHT := 0.3

@export var gold: int = BASE_STARTING_GOLD : set = _set_gold
@export var card_reward_choices: int = BASE_CARD_REWARD_CHOICES
@export_range(0.0, 10.0) var common_weight: float = BASE_COMMON_WEIGHT
@export_range(0.0, 10.0) var uncommon_weight: float = BASE_UNCOMMON_WEIGHT
@export_range(0.0, 10.0) var rare_weight: float = BASE_RARE_WEIGHT

var draftable_cards: CardPile
var deck: Deck

func _set_gold(n_gold: int) -> void:
	gold = n_gold
	gold_changed.emit()

func reset_weights() -> void:
	common_weight = BASE_COMMON_WEIGHT
	uncommon_weight = BASE_UNCOMMON_WEIGHT
	rare_weight = BASE_RARE_WEIGHT
