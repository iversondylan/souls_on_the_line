extends SceneTree

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	_verify_reward_pool_splits()
	_verify_soulbound_pity_state()
	_verify_static_wiring()
	if !_failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
	else:
		print("verify_soulbound_split_rewards: ok")
		quit()


func _verify_reward_pool_splits() -> void:
	var cards := _load_cards([
		"res://cards/convocations/MarkCard/mark_data.tres",
		"res://cards/convocations/Crunch/crunch.tres",
		"res://cards/convocations/FocusFireCard/focus_fire.tres",
		"res://cards/souls/BrickGuardianCard/brick_guardian_card.tres",
		"res://cards/souls/WoodstoveKeeperCard/woodstove_keeper_card.tres",
		"res://cards/souls/WatchfulSphinxCard/watchful_sphinx_card.tres",
		"res://cards/souls/ImpatientDjinn/impatient_djinn.tres",
		"res://cards/souls/AxolotlAsceticCard/axolotl_ascetic_card.tres",
		"res://cards/souls/ManticoreOfTheMeanCard/manticore_of_the_mean_card.tres",
	])

	var rare_pity := -5.0
	var normal_result := _build_choices_for_test(cards, RNG.new(11), CardRarityManager.Source.NORMAL_COMBAT, false, rare_pity)
	var normal_cards: Array[CardData] = []
	normal_cards.assign(normal_result.get("choices", []))
	_expect(normal_cards.size() == 3, "normal pack should fill three choices")
	for card in normal_cards:
		_expect(card != null and int(card.card_type) != int(CardData.CardType.SOULBOUND), "normal pack should exclude SOULBOUND cards")

	rare_pity = -5.0
	var soulbound_result := _build_choices_for_test(cards, RNG.new(12), CardRarityManager.Source.NORMAL_COMBAT, true, rare_pity)
	var soulbound_cards: Array[CardData] = []
	soulbound_cards.assign(soulbound_result.get("choices", []))
	_expect(soulbound_cards.size() == 3, "Soulbound pack should fill three choices")
	for card in soulbound_cards:
		_expect(card != null and card.is_soulbound_slot_card(), "Soulbound pack should only include slot Soulbound cards")

	rare_pity = 40.0
	var boss_result := _build_choices_for_test(cards, RNG.new(13), CardRarityManager.Source.BOSS_REWARD, true, rare_pity)
	var boss_cards: Array[CardData] = []
	boss_cards.assign(boss_result.get("choices", []))
	_expect(boss_cards.size() == 3, "boss Soulbound pack should fill three choices")
	for card in boss_cards:
		_expect(card != null and int(card.rarity) == int(CardData.Rarity.RARE), "boss Soulbound pack should prefer all-rare choices")
	_expect(is_equal_approx(float(boss_result.get("rare_pity", 0.0)), RunState.BASE_RARE_PITY_OFFSET_PERCENT), "boss Soulbound rare rolls should reset shared rare pity")


func _verify_soulbound_pity_state() -> void:
	var state := RunState.new()
	_expect(is_equal_approx(state.soulbound_pity_offset_percent, 40.0), "Soulbound pity should default to 40")
	state.increase_soulbound_pity_after_miss()
	_expect(is_equal_approx(state.soulbound_pity_offset_percent, 70.0), "Soulbound miss should increase pity to 70")
	state.increase_soulbound_pity_after_miss()
	_expect(is_equal_approx(state.soulbound_pity_offset_percent, 100.0), "Soulbound miss should cap pity at 100")
	state.reset_soulbound_pity()
	_expect(is_equal_approx(state.soulbound_pity_offset_percent, 40.0), "Soulbound hit should reset pity to 40")


func _verify_static_wiring() -> void:
	_expect_file_contains(
		"res://run/run.gd",
		[
			"_build_reward_card_choices(card_rng, rarity_source, false)",
			"_build_reward_card_choices(card_rng, rarity_source, true)",
			"_should_generate_soulbound_reward(card_rng, rarity_source)",
			"run_state.reset_soulbound_pity()",
			"run_state.increase_soulbound_pity_after_miss()",
			"int(card_data.card_type) != int(CardData.CardType.SOULBOUND)",
		]
	)
	_expect_file_contains(
		"res://run/rewards/battle_rewards.gd",
		[
			"Add Soulbound Card",
			"SOULBOUND_REWARD_ICON_MODULATE",
			"pending_reward_soulbound_card_claimed",
			"_current_soulbound_card_reward_button",
		]
	)
	_expect_file_contains(
		"res://core/save_service.gd",
		[
			"soulbound_pity_offset_percent",
			"pending_reward_soulbound_card_choice_paths",
			"pending_reward_soulbound_card_claimed",
		]
	)
	_expect_file_contains(
		"res://ui/reward_button.gd",
		[
			"reward_icon_modulate",
			"custom_icon.modulate = reward_icon_modulate",
		]
	)


func _load_cards(paths: Array[String]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for path in paths:
		var card := load(path) as CardData
		_expect(card != null, "Missing test card: %s" % path)
		if card != null:
			cards.append(card)
	return cards


func _build_choices_for_test(
	cards: Array[CardData],
	rng: RNG,
	rarity_source: int,
	soulbound_only: bool,
	rare_pity: float
) -> Dictionary:
	var possible_cards: Array[CardData] = []
	for card in cards:
		if card == null:
			continue
		if soulbound_only:
			if card.is_soulbound_slot_card():
				possible_cards.append(card)
		elif int(card.card_type) != int(CardData.CardType.SOULBOUND):
			possible_cards.append(card)

	var chosen: Array[CardData] = []
	for _i in range(3):
		if possible_cards.is_empty():
			break
		var target_rarity := CardRarityManager.roll_rarity(
			rng,
			int(rarity_source),
			rare_pity,
			"verify_reward_card_rarity_roll"
		)
		rare_pity = CardRarityManager.next_pity_offset(rare_pity, target_rarity)
		var selected := CardRarityManager.select_card_for_rarity(
			rng,
			possible_cards,
			target_rarity,
			"verify_reward_card_pick"
		)
		if selected == null:
			continue
		possible_cards.erase(selected)
		chosen.append(selected)
	return {
		"choices": chosen,
		"rare_pity": rare_pity,
	}


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
