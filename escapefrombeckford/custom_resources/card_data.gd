# card_data.gd
class_name CardData extends Resource

enum CardType {
	ATTACK,
	DEFEND,
	SUMMON,
	POWER,
	BUFF,
	DEBUFF,
	MOVEMENT
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

@export_group("Card Attributes")
@export var id: int
@export var card_type: CardType
@export var target_type: TargetType
@export var rarity: Rarity
@export var name: String
@export var deplete: bool
@export_multiline var description: String
@export var cost_red: int
@export var cost_green: int
@export var cost_blue: int
@export var texture: Texture2D
@export var actions: Array[CardAction] = []
#@export var sound: Sound

var card_status: CardStatus

func is_single_targeted() -> bool:
	return target_type == TargetType.SINGLE_ENEMY or target_type == TargetType.ALLY_OR_SELF or target_type == TargetType.ALLY or target_type == TargetType.BATTLEFIELD
