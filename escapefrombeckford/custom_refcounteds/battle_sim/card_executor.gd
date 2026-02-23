# card_executor.gd
class_name CardExecutor extends RefCounted

var card_catalog: CardCatalog

func play_card(api: BattleAPI, req: CardPlayRequest) -> bool:
	if api == null or card_catalog == null:
		return false

	var card := card_catalog.get_card(req.card_id)
	if card == null:
		push_warning("CardExecutor: unknown card_id=%s" % req.card_id)
		return false

	# Optional: validate source alive, mana, etc (API-driven!)
	# if api.has_method("can_play_card_sim"): ...

	var resolved := CardTargeting.resolve(api, card, req)

	# Validate targeting requirements
	if card.is_single_targeted() and resolved.fighter_ids.is_empty() and card.target_type != CardData.TargetType.BATTLEFIELD:
		return false

	var ctx := CardActionContextSim.new()
	ctx.api = api
	ctx.card_data = card
	ctx.source_id = req.source_id
	ctx.resolved = resolved
	ctx.params = req.params
	ctx.rng_seed = req.play_seed

	# Spend mana via API (SIM needs a verb)
	if api.has_method("spend_mana_for_card"):
		if !bool(api.call("spend_mana_for_card", req.source_id, card)):
			return false

	# Execute actions
	var any := false
	for action: CardAction in card.actions:
		if action == null:
			continue
		if action.activate_sim(ctx):
			any = true

	# Deplete/exhaust policy (SIM needs card state? you said no deck/hand simulation)
	# If you truly don't model piles in SIM, just skip these.
	# If you *do* model "card exhausted this fight" as part of state, handle here.

	return any
