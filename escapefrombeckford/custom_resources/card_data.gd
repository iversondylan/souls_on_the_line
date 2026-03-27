# card_data.gd
class_name CardData extends Resource

enum CardType {
	CONVOCATION,
	SUMMON,
	ENCHANTMENT,
	EFFUSION
}

enum TargetType {
	SELF,
	BATTLEFIELD,
	ALLY_OR_SELF,
	ALLY,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	EVERYONE
}

enum Rarity {COMMON, UNCOMMON, RARE}

enum CardStatus {
	PRE_GAME,
	DRAW_PILE,
	HAND,
	DISCARD_PILE,
	SUMMON_RESERVE,
	EXHAUSTED
}

const RARITY_COLORS := {
	CardData.Rarity.COMMON: Color.GRAY,
	CardData.Rarity.UNCOMMON: Color.ROYAL_BLUE,
	CardData.Rarity.RARE: Color.DARK_ORANGE,
}


@export_group("Identity")
@export var uid: String = ""				# stable per instance
@export var version: int = 1
@export var base_proto_path: String = ""	# optional: template origin

@export_group("Card Attributes")
@export var id: int

@export var card_type: CardType
@export var target_type: TargetType
@export var rarity: Rarity
@export var name: String
@export var deplete: bool
@export_multiline var description: String
@export var cost: int
@export var texture: Texture2D
@export var actions: Array[CardAction] = []

func ensure_uid() -> void:
	if uid != "":
		return
	uid = "%d_%d_%d" % [Time.get_unix_time_from_system(), randi(), int(hash(name))]

func serialize_snapshot() -> CardSnapshot:
	return CardSnapshot.from_card(self)

static func deserialize_snapshot(snapshot: CardSnapshot) -> CardData:
	if snapshot == null:
		return null
	return snapshot.instantiate_card()

func is_single_targeted() -> bool:
	return target_type == TargetType.SINGLE_ENEMY or target_type == TargetType.ALLY_OR_SELF or target_type == TargetType.ALLY or target_type == TargetType.BATTLEFIELD

func get_total_cost() -> int:
	return cost
