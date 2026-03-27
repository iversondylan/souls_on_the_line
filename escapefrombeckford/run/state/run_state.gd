# run_state.gd

class_name RunState extends Resource

signal gold_changed

enum LocationKind {
	MAP,
	ROOM_PENDING_BATTLE,
	ROOM_PENDING_TREASURE,
	ROOM_PENDING_REST,
	ROOM_PENDING_SHOP,
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
@export var player_data: PlayerData
@export var player_run_state: PlayerRunState = PlayerRunState.new()
@export var cleared_room_coords: Array[Vector2i] = []
@export var location_kind: int = LocationKind.MAP
@export var pending_room_coord: Vector2i = Vector2i(-1, -1)
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
