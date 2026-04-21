extends SceneTree

const COLE_STARTER_DECK := preload("res://character_profiles/Cole/cole_starter_deck.tres")
const GLASS_PECCARY := preload("res://cards/souls/GlassPeccaryCard/glass_peccary_card.tres")

func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_cole_starter_deck_soulbound_cards_resolve_to_bound():
		exit_code = 1
		failure = "cole starter deck summon mortality verification failed"
	elif !_verify_soulwild_card_resolves_to_wild():
		exit_code = 1
		failure = "soulwild summon mortality verification failed"

	if exit_code == 0:
		print("Summon mortality from CardData verification passed.")
	else:
		push_error(failure)

	quit(exit_code)


func _verify_cole_starter_deck_soulbound_cards_resolve_to_bound() -> bool:
	_assert(COLE_STARTER_DECK != null, "Cole starter deck should load")
	var expected_names := {
		"Spectral Clone": true,
		"Phalanx": true,
		"Crone Puppeteer": true,
		"Smoldering Mascot": true,
	}

	for card in COLE_STARTER_DECK.cards:
		var card_data := card as CardData
		if card_data == null:
			continue
		if !expected_names.has(card_data.name):
			continue
		_assert_equal(int(card_data.card_type), int(CardData.CardType.SOULBOUND), "%s should export as SOULBOUND" % card_data.name)
		var summon_action := _get_first_summon_action(card_data)
		_assert(summon_action != null, "%s should include a SummonAction" % card_data.name)
		_assert_equal(
			int(summon_action._resolve_summon_mortality(card_data)),
			int(CombatantState.Mortality.BOUND),
			"%s summon mortality should resolve to BOUND from CardData" % card_data.name
		)
		expected_names.erase(card_data.name)

	_assert(expected_names.is_empty(), "All expected Cole starter deck cards were verified")
	return true


func _verify_soulwild_card_resolves_to_wild() -> bool:
	_assert(GLASS_PECCARY != null, "Glass Peccary card should load")
	_assert_equal(int(GLASS_PECCARY.card_type), int(CardData.CardType.SOULWILD), "Glass Peccary should export as SOULWILD")
	var summon_action := _get_first_summon_action(GLASS_PECCARY)
	_assert(summon_action != null, "Glass Peccary should include a SummonAction")
	_assert_equal(
		int(summon_action._resolve_summon_mortality(GLASS_PECCARY)),
		int(CombatantState.Mortality.WILD),
		"SOULWILD card summon mortality should resolve to WILD from CardData"
	)
	return true


func _get_first_summon_action(card_data: CardData) -> SummonAction:
	if card_data == null:
		return null
	for action in card_data.actions:
		var summon_action := action as SummonAction
		if summon_action != null:
			return summon_action
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	assert(condition, message)


func _assert_equal(actual, expected, label: String) -> void:
	if actual == expected:
		return
	var message := "%s: expected %s, got %s" % [label, str(expected), str(actual)]
	push_error(message)
	assert(false, message)
