# run_state.gd

class_name RunState extends Resource

signal gold_changed

enum LocationKind {
	MAP,
	ROOM_PENDING_BATTLE,
	ROOM_PENDING_TREASURE,
	ROOM_PENDING_REST,
	ROOM_PENDING_SHOP,
	ROOM_PENDING_BATTLE_REWARDS,
	ROOM_PENDING_TREASURE_REWARDS,
}

const BASE_STARTING_GOLD: int = 50
const BASE_CARD_REWARD_CHOICES := 3
const BASE_COMMON_WEIGHT := 6.0
const BASE_UNCOMMON_WEIGHT := 3.7
const BASE_RARE_WEIGHT := 0.3

@export var gold: int = BASE_STARTING_GOLD : set = _set_gold
@export var card_reward_choices: int = BASE_CARD_REWARD_CHOICES
@export_range(0.0, 10.0) var common_weight: float = BASE_COMMON_WEIGHT
@export_range(0.0, 10.0) var uncommon_weight: float = BASE_UNCOMMON_WEIGHT
@export_range(0.0, 10.0) var rare_weight: float = BASE_RARE_WEIGHT

@export var run_seed: int = 0
@export var map_seed: int = 0
@export var run_rng_snapshot: Dictionary = {}
@export var player_profile_id: String = ""
@export var player_run_state: PlayerRunState = PlayerRunState.new()
@export var cleared_room_coords: Array[Vector2i] = []
@export var location_kind: int = LocationKind.MAP
@export var pending_room_coord: Vector2i = Vector2i(-1, -1)
@export var pending_battle_seed: int = 0
@export var pending_room_seed: int = 0
@export var pending_reward_seed: int = 0
@export var pending_treasure_arcanum_id: String = ""
@export var pending_shop_card_offer_paths: PackedStringArray = []
@export var pending_shop_card_offer_costs: Array[int] = []
@export var pending_shop_claimed_card_offer_indices: Array[int] = []
@export var pending_shop_arcanum_offer_ids: PackedStringArray = []
@export var pending_shop_arcanum_offer_costs: Array[int] = []
@export var pending_shop_claimed_arcanum_offer_indices: Array[int] = []
@export var pending_reward_gold_rewards: Array[int] = []
@export var pending_reward_card_choice_paths: PackedStringArray = []
@export var pending_reward_arcanum_ids: PackedStringArray = []
@export var pending_reward_claimed_gold_indices: Array[int] = []
@export var pending_reward_card_claimed: bool = false
@export var pending_reward_claimed_arcanum_indices: Array[int] = []
@export var owned_arcanum_ids: PackedStringArray = []
@export var draftable_cards: CardPile
@export var run_deck: RunDeck

func _set_gold(n_gold: int) -> void:
	gold = n_gold
	gold_changed.emit()

func reset_weights() -> void:
	common_weight = BASE_COMMON_WEIGHT
	uncommon_weight = BASE_UNCOMMON_WEIGHT
	rare_weight = BASE_RARE_WEIGHT
