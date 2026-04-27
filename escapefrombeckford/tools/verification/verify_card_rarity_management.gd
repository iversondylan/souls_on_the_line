extends SceneTree

const EPSILON := 0.001

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	_verify_effective_weights()
	_verify_pity_mutation()
	_verify_card_selection_fallback()
	_verify_static_wiring()
	if !_failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
	else:
		print("verify_card_rarity_management: ok")
		quit()


func _verify_effective_weights() -> void:
	_expect_weights(
		CardRarityManager.Source.NORMAL_COMBAT,
		-5.0,
		0.0,
		35.0,
		65.0,
		"normal -5"
	)
	_expect_weights(
		CardRarityManager.Source.NORMAL_COMBAT,
		10.0,
		13.0,
		37.0,
		50.0,
		"normal +10"
	)
	_expect_weights(
		CardRarityManager.Source.ELITE_COMBAT,
		-5.0,
		5.0,
		40.0,
		55.0,
		"elite -5"
	)
	_expect_weights(
		CardRarityManager.Source.SHOP,
		40.0,
		49.0,
		37.0,
		14.0,
		"shop +40"
	)
	_expect_weights(
		CardRarityManager.Source.BOSS_REWARD,
		-5.0,
		100.0,
		0.0,
		0.0,
		"boss -5"
	)
	_expect(
		CardRarityManager.roll_rarity(RNG.new(1), CardRarityManager.Source.BOSS_REWARD, 0.0, "verify_boss_roll") == CardData.Rarity.RARE,
		"boss rewards should roll rare at 0 offset"
	)


func _verify_pity_mutation() -> void:
	_expect(
		_is_close(CardRarityManager.next_pity_offset(-5.0, CardData.Rarity.COMMON), -4.0),
		"common should add +1 pity"
	)
	_expect(
		_is_close(CardRarityManager.next_pity_offset(10.0, CardData.Rarity.UNCOMMON), 10.0),
		"uncommon should not change pity"
	)
	_expect(
		_is_close(CardRarityManager.next_pity_offset(40.0, CardData.Rarity.COMMON), 40.0),
		"common pity should cap at +40"
	)
	_expect(
		_is_close(CardRarityManager.next_pity_offset(12.0, CardData.Rarity.RARE), -5.0),
		"rare should reset pity to -5"
	)


func _verify_card_selection_fallback() -> void:
	var cards: Array[CardData] = [
		_make_card(&"common_a", CardData.Rarity.COMMON),
		_make_card(&"uncommon_a", CardData.Rarity.UNCOMMON),
		_make_card(&"rare_a", CardData.Rarity.RARE),
	]
	var picked_ids := {}
	var rng := RNG.new(44)
	for _i in range(3):
		var card := CardRarityManager.select_card_for_rarity(
			rng,
			cards,
			CardData.Rarity.RARE,
			"verify_card_pick"
		)
		_expect(card != null, "selection should fall back when requested rarity is exhausted")
		if card == null:
			return
		_expect(!picked_ids.has(card.id), "selection loop should not repeat an erased card")
		picked_ids[card.id] = true
		cards.erase(card)
	_expect(cards.is_empty(), "selection loop should consume all three cards")


func _verify_static_wiring() -> void:
	_expect_file_contains(
		"res://run/run.gd",
		[
			"CardRarityManager.Source.SHOP",
			"CardRarityManager.source_for_battle_tier",
			"CardRarityManager.next_pity_offset",
			"_build_reward_card_choices(card_rng, rarity_source, false)",
			"return 3",
		]
	)
	_expect_file_contains(
		"res://run/state/run_state.gd",
		[
			"BASE_RARE_PITY_OFFSET_PERCENT",
			"rare_pity_offset_percent",
			"reset_rarity_pity",
		]
	)
	_expect_file_contains(
		"res://core/save_service.gd",
		[
			"rare_pity_offset_percent",
			"_decode_rare_pity_offset",
			"old_rare_weight / old_total_weight * 100.0",
		]
	)
	_expect_file_contains("res://encounters/battle_data.gd", ["@export_range(0, 3) var battle_tier"])
	_expect_file_contains("res://encounters/beckford_domain/tier_2_magister_rowan_fellhart.tres", ["battle_tier = 3"])


func _expect_weights(source: int, offset: float, rare: float, uncommon: float, common: float, label: String) -> void:
	var weights := CardRarityManager.effective_weights(source, offset)
	_expect(_is_close(float(weights[CardData.Rarity.RARE]), rare), "%s rare weight mismatch" % label)
	_expect(_is_close(float(weights[CardData.Rarity.UNCOMMON]), uncommon), "%s uncommon weight mismatch" % label)
	_expect(_is_close(float(weights[CardData.Rarity.COMMON]), common), "%s common weight mismatch" % label)


func _make_card(id: StringName, rarity: int) -> CardData:
	var card := CardData.new()
	card.id = id
	card.rarity = int(rarity) as CardData.Rarity
	return card


func _is_close(a: float, b: float) -> bool:
	return absf(a - b) <= EPSILON


func _expect(condition: bool, message: String) -> void:
	if !condition:
		_failures.append(message)


func _expect_file_contains(path: String, snippets: Array) -> void:
	var text := _read_text(path)
	if text.is_empty():
		_failures.append("Missing or empty file: %s" % path)
		return
	for snippet in snippets:
		if !text.contains(String(snippet)):
			_failures.append("%s missing snippet: %s" % [path, String(snippet)])


func _read_text(path: String) -> String:
	if !FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
