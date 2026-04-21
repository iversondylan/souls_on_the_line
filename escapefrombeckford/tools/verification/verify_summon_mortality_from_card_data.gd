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
	elif !_verify_interaction_mode_uses_card_data_mortality():
		exit_code = 1
		failure = "summon interaction mode mortality verification failed"

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


func _verify_interaction_mode_uses_card_data_mortality() -> bool:
	var host := SimHost.new()
	host.init_from_seeds(123, 456)
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()
	_assert(runtime != null and api != null, "Sim host should provide runtime/api")

	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	_assert(player_id > 0, "Player should spawn")

	for i in range(3):
		var bound_id := runtime.add_combatant_from_data(_make_unit_data("Bound %d" % i, 5), SimBattleAPI.FRIENDLY, -1, false, 5)
		_assert(bound_id > 0, "Bound summon %d should spawn" % i)
		var bound_unit := host.get_main_state().get_unit(bound_id)
		_assert(bound_unit != null, "Bound summon unit should exist")
		bound_unit.mortality = CombatantState.Mortality.BOUND

	var soulbound_card := _get_card_by_name(COLE_STARTER_DECK, "Phalanx")
	_assert(soulbound_card != null, "Phalanx should exist in deck")
	var soulbound_action := _get_first_summon_action(soulbound_card)
	_assert(soulbound_action != null, "Phalanx should include a SummonAction")
	_assert_equal(int(soulbound_action.mortality), int(CombatantState.Mortality.WILD), "Phalanx summon action export mortality should be WILD for regression coverage")

	var soulbound_ctx := CardContext.new()
	soulbound_ctx.api = api
	soulbound_ctx.card_data = soulbound_card
	soulbound_ctx.source_id = player_id
	_assert_equal(
		int(soulbound_action.get_interaction_mode(soulbound_ctx)),
		int(CardAction.InteractionMode.ESCROW),
		"SOULBOUND CardData should trigger summon replace when bound cap is reached"
	)

	var soulwild_action := _get_first_summon_action(GLASS_PECCARY)
	_assert(soulwild_action != null, "Glass Peccary should include a SummonAction")
	var soulwild_ctx := CardContext.new()
	soulwild_ctx.api = api
	soulwild_ctx.card_data = GLASS_PECCARY
	soulwild_ctx.source_id = player_id
	_assert_equal(
		int(soulwild_action.get_interaction_mode(soulwild_ctx)),
		int(CardAction.InteractionMode.NONE),
		"SOULWILD CardData should not trigger summon replace"
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


func _get_card_by_name(deck: CardPile, card_name: String) -> CardData:
	if deck == null:
		return null
	for card in deck.cards:
		var card_data := card as CardData
		if card_data == null:
			continue
		if String(card_data.name) == String(card_name):
			return card_data
	return null


func _make_unit_data(unit_name: String, health: int) -> CombatantData:
	var data := CombatantData.new()
	data.name = unit_name
	data.max_health = health
	data.max_mana = 0
	data.ap = 0
	return data


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
