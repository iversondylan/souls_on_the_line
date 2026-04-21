# card_data.gd
class_name CardData extends Resource

enum CardType {
	CONVOCATION = 0,
	SOULBOUND = 1,
	ENCHANTMENT = 2,
	EFFUSION = 3,
	SOULWILD = 4,
}

enum TargetType {
	SELF,
	BATTLEFIELD,
	ALLY_OR_SELF,
	ALLY, # Serialized value 3 in .tres files (e.g. Crystal Barrier target_type = 3)
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
@export var id: StringName = &""
@export var uid: String = ""				# stable per instance
@export var version: int = 1
@export var base_proto_path: String = ""	# optional: template origin

@export_group("Card Attributes")
@export var card_type: CardType
@export var target_type: TargetType
@export var rarity: Rarity
@export var name: String
@export var deplete: bool
@export var starter_card: bool = false
@export var summon_release_overload: int = 2
@export_multiline var description: String
@export var cost: int
@export var overload: int = 0
@export var texture: Texture2D
@export var actions: Array[CardAction] = []

func ensure_uid() -> void:
	if uid != "":
		return
	uid = "%d_%d_%d" % [Time.get_unix_time_from_system(), randi(), int(hash(name))]

func ensure_id() -> void:
	if id != &"":
		return
	var source_path := String(base_proto_path if !base_proto_path.is_empty() else resource_path)
	if !source_path.is_empty():
		var fallback := source_path.get_file().get_basename()
		fallback = fallback.trim_suffix("_card")
		fallback = fallback.trim_suffix("_data")
		if !fallback.is_empty():
			id = StringName(fallback)
			return
	if !name.is_empty():
		id = StringName(name.to_snake_case())


func make_runtime_instance() -> CardData:
	var instance := duplicate(true) as CardData
	if instance == null:
		return null

	var proto_path := String(base_proto_path if !base_proto_path.is_empty() else resource_path)
	if instance._needs_proto_rehydrate():
		var proto := load(proto_path) as CardData
		if proto != null:
			var hydrated := proto.duplicate(true) as CardData
			if hydrated != null:
				_copy_runtime_overrides(instance, hydrated)
				instance = hydrated

	if instance.base_proto_path.is_empty():
		instance.base_proto_path = proto_path
	instance.ensure_id()
	instance.ensure_uid()
	return instance


func _needs_proto_rehydrate() -> bool:
	return actions.is_empty() or name.is_empty()


static func _copy_runtime_overrides(from: CardData, to: CardData) -> void:
	if from == null or to == null:
		return
	to.uid = from.uid
	to.id = from.id
	to.version = from.version
	to.base_proto_path = String(from.base_proto_path if !from.base_proto_path.is_empty() else to.base_proto_path)
	to.card_type = from.card_type
	to.target_type = from.target_type
	to.rarity = from.rarity
	if !from.name.is_empty():
		to.name = from.name
	to.deplete = from.deplete
	to.starter_card = from.starter_card
	to.summon_release_overload = from.summon_release_overload
	if !from.description.is_empty():
		to.description = from.description
	to.cost = from.cost
	to.overload = from.overload
	if from.texture != null:
		to.texture = from.texture
	if !from.actions.is_empty():
		to.actions = from.actions.duplicate()

func serialize_snapshot() -> CardSnapshot:
	return CardSnapshot.from_card(self)

static func deserialize_snapshot(snapshot: CardSnapshot) -> CardData:
	if snapshot == null:
		return null
	return snapshot.instantiate_card()

func is_single_targeted() -> bool:
	return target_type == TargetType.SINGLE_ENEMY or target_type == TargetType.ALLY_OR_SELF or target_type == TargetType.ALLY or target_type == TargetType.BATTLEFIELD

func get_total_cost() -> int:
	return maxi(int(cost) + int(overload), 0)


func is_soulbound_slot_card() -> bool:
	if int(card_type) != int(CardType.SOULBOUND) or bool(deplete):
		return false
	return _has_summon_with_mortality(CombatantState.Mortality.BOUND)


func is_wild_soul_card() -> bool:
	return int(card_type) == int(CardType.SOULWILD)


func should_exhaust_on_play() -> bool:
	return bool(deplete)


func _has_summon_with_mortality(mortality_value: int) -> bool:
	for action in actions:
		var summon_action := action as SummonAction
		if summon_action == null:
			continue
		if int(summon_action.mortality) == int(mortality_value):
			return true
	return false
