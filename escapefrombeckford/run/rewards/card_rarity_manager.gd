class_name CardRarityManager
extends RefCounted

enum Source {
	NORMAL_COMBAT,
	ELITE_COMBAT,
	BOSS_REWARD,
	SHOP,
}

const PITY_MIN_OFFSET := 0.0
const PITY_MAX_OFFSET := 40.0
const PITY_COMMON_STEP := 2.0

const _TABLES := {
	Source.NORMAL_COMBAT: {
		CardData.Rarity.RARE: 3.0,
		CardData.Rarity.UNCOMMON: 37.0,
		CardData.Rarity.COMMON: 60.0,
	},
	Source.ELITE_COMBAT: {
		CardData.Rarity.RARE: 10.0,
		CardData.Rarity.UNCOMMON: 40.0,
		CardData.Rarity.COMMON: 50.0,
	},
	Source.BOSS_REWARD: {
		CardData.Rarity.RARE: 100.0,
		CardData.Rarity.UNCOMMON: 0.0,
		CardData.Rarity.COMMON: 0.0,
	},
	Source.SHOP: {
		CardData.Rarity.RARE: 9.0,
		CardData.Rarity.UNCOMMON: 37.0,
		CardData.Rarity.COMMON: 54.0,
	},
}


static func source_for_battle_tier(tier: int) -> int:
	match int(tier):
		2:
			return Source.ELITE_COMBAT
		3:
			return Source.BOSS_REWARD
		_:
			return Source.NORMAL_COMBAT


static func effective_weights(source: int, offset_percent: float) -> Dictionary:
	var base: Dictionary = _TABLES.get(int(source), _TABLES[Source.NORMAL_COMBAT])
	var rare := float(base.get(CardData.Rarity.RARE, 0.0))
	var uncommon := float(base.get(CardData.Rarity.UNCOMMON, 0.0))
	var common := float(base.get(CardData.Rarity.COMMON, 0.0))
	if int(source) == int(Source.BOSS_REWARD):
		return {
			CardData.Rarity.RARE: rare,
			CardData.Rarity.UNCOMMON: uncommon,
			CardData.Rarity.COMMON: common,
		}
	var offset := clampf(float(offset_percent), PITY_MIN_OFFSET, PITY_MAX_OFFSET)

	if offset > 0.0:
		rare += offset
		var from_common := minf(offset, common)
		common -= from_common
		var remainder := offset - from_common
		if remainder > 0.0:
			uncommon = maxf(0.0, uncommon - remainder)
	elif offset < 0.0:
		var reduction := -offset
		var from_rare := minf(reduction, rare)
		rare -= from_rare
		var remainder := reduction - from_rare
		if remainder > 0.0:
			var from_uncommon := minf(remainder, uncommon)
			uncommon -= from_uncommon
		common = maxf(0.0, 100.0 - rare - uncommon)

	return {
		CardData.Rarity.RARE: maxf(rare, 0.0),
		CardData.Rarity.UNCOMMON: maxf(uncommon, 0.0),
		CardData.Rarity.COMMON: maxf(common, 0.0),
	}


static func roll_rarity(rng: RNG, source: int, offset_percent: float, label: String = "card_rarity_roll") -> int:
	var weights := effective_weights(source, offset_percent)
	var common := float(weights.get(CardData.Rarity.COMMON, 0.0))
	var uncommon := float(weights.get(CardData.Rarity.UNCOMMON, 0.0))
	var rare := float(weights.get(CardData.Rarity.RARE, 0.0))
	var total := common + uncommon + rare
	if total <= 0.0:
		return CardData.Rarity.COMMON

	var roll := rng.debug_range_f(0.0, total, label) if rng != null else randf_range(0.0, total)
	if roll < common:
		return CardData.Rarity.COMMON
	if roll < common + uncommon:
		return CardData.Rarity.UNCOMMON
	return CardData.Rarity.RARE


static func next_pity_offset(current_offset: float, rolled_rarity: int) -> float:
	match int(rolled_rarity):
		int(CardData.Rarity.RARE):
			return PITY_MIN_OFFSET
		int(CardData.Rarity.COMMON):
			return clampf(float(current_offset) + PITY_COMMON_STEP, PITY_MIN_OFFSET, PITY_MAX_OFFSET)
		_:
			return clampf(float(current_offset), PITY_MIN_OFFSET, PITY_MAX_OFFSET)


static func select_card_for_rarity(
	rng: RNG,
	available_cards: Array[CardData],
	target_rarity: int,
	label: String = "card_pick"
) -> CardData:
	if available_cards.is_empty():
		return null

	var matching_indices: Array[int] = []
	for idx in range(available_cards.size()):
		var candidate := available_cards[idx]
		if candidate != null and int(candidate.rarity) == int(target_rarity):
			matching_indices.append(idx)

	if matching_indices.is_empty():
		for idx in range(available_cards.size()):
			if available_cards[idx] != null:
				matching_indices.append(idx)

	if matching_indices.is_empty():
		return null

	var selected_index := 0
	if rng != null:
		selected_index = rng.debug_range_i(0, matching_indices.size() - 1, label)
	else:
		selected_index = randi_range(0, matching_indices.size() - 1)
	var selected_slot := int(matching_indices[selected_index])
	return available_cards[selected_slot]
