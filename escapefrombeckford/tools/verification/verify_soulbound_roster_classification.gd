extends SceneTree

const BattleCardBins := preload("res://battle/card_mgmt/battle_card_bins.gd")
const CardData := preload("res://cards/_core/card_data.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const Momentum := preload("res://cards/convocations/Momentum/momentum.tres")
const MosslingBulwark := preload("res://cards/souls/MosslingBulwarkCard/mossling_bulwark_card.tres")
const RunDeck := preload("res://run/state/run_deck.gd")
const SmolderingMascot := preload("res://cards/souls/SmolderingMascotCard/smoldering_mascot_card.tres")

func _init() -> void:
	_verify_non_deplete_soulbound_uses_card_type()
	_verify_run_deck_accepts_mismatched_soulbound_slot_card()
	_verify_soulbound_guarantee_uses_card_type()
	_verify_soulwild_cards_stay_excluded()
	_verify_deplete_soulbound_cards_stay_excluded()
	print("verify_soulbound_roster_classification: ok")
	quit()


func _verify_non_deplete_soulbound_uses_card_type() -> void:
	var card := SmolderingMascot.make_runtime_instance()
	var summon_action := _first_summon_action(card)
	assert(card != null, "Smoldering Mascot fixture should instantiate.")
	assert(summon_action != null, "Smoldering Mascot should have a summon action fixture.")
	assert(
		int(summon_action.mortality) != int(CombatantState.Mortality.BOUND),
		"Smoldering Mascot fixture should use non-bound authored summon mortality."
	)
	assert(
		card.is_soulbound_slot_card(),
		"Non-deplete Soulbound cards should classify by card type, not summon mortality."
	)


func _verify_run_deck_accepts_mismatched_soulbound_slot_card() -> void:
	var run_deck := RunDeck.new()
	assert(
		run_deck.replace_soulbound_slot(0, SmolderingMascot),
		"RunDeck.replace_soulbound_slot() should accept Soulbound cards even if authored summon mortality is not bound."
	)
	var slot_cards := run_deck.get_soulbound_slot_cards()
	assert(slot_cards.size() == 1, "Replacing a fresh soulbound slot should yield one stored slot card.")
	assert(slot_cards[0] != null and slot_cards[0].id == &"smoldering_mascot", "RunDeck should store the replacement soulbound card.")


func _verify_soulbound_guarantee_uses_card_type() -> void:
	var bins := BattleCardBins.new()
	bins.rng = RNG.new(17)

	var normal_card := Momentum.make_runtime_instance()
	var guaranteed_card := SmolderingMascot.make_runtime_instance()
	bins.state.draw_pile.add_back(normal_card)
	bins.state.discard_pile.add_back(guaranteed_card)

	var drawn := bins._draw_cards_with_soulbound_guarantee(1)
	assert(drawn.size() == 1, "Soulbound guarantee should draw one card when one is requested.")
	assert(
		drawn[0] != null and drawn[0].id == guaranteed_card.id,
		"Soulbound guarantee should treat Soulbound card type as an eligible candidate regardless of summon mortality."
	)
	assert(
		bins.state.discard_pile.cards.size() == 1 and bins.state.discard_pile.cards[0] != null and bins.state.discard_pile.cards[0].id == normal_card.id,
		"Soulbound guarantee should return the replaced non-soulbound draw to discard."
	)


func _verify_soulwild_cards_stay_excluded() -> void:
	var card := MosslingBulwark.make_runtime_instance()
	var summon_action := _first_summon_action(card)
	assert(card != null, "Mossling Bulwark fixture should instantiate.")
	assert(summon_action != null, "Mossling Bulwark should have a summon action fixture.")
	summon_action.mortality = CombatantState.Mortality.BOUND
	assert(
		!card.is_soulbound_slot_card(),
		"Soulwild cards should stay excluded from soulbound slots even if authored summon mortality is changed to bound."
	)


func _verify_deplete_soulbound_cards_stay_excluded() -> void:
	var card := SmolderingMascot.make_runtime_instance()
	assert(card != null, "Deplete Soulbound regression fixture should instantiate.")
	card.deplete = true
	assert(
		!card.is_soulbound_slot_card(),
		"Deplete Soulbound cards should stay excluded from soulbound slots."
	)


func _first_summon_action(card: CardData) -> SummonAction:
	if card == null:
		return null
	for action in card.actions:
		var summon_action := action as SummonAction
		if summon_action != null:
			return summon_action
	return null
