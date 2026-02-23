# card_executor.gd
class_name CardExecutor extends RefCounted

var card_catalog: CardCatalog

func play_card(api: BattleAPI, req: CardPlayRequest) -> bool:
	if api == null or req == null or req.card == null:
		return false

	var card := req.card
	card.ensure_uid()

	var resolved := CardTargeting.resolve(api, card, req) # must accept CardData instance

	var ctx := CardActionContextSim.new()
	ctx.api = api
	ctx.card_data = card
	ctx.source_id = req.source_id
	ctx.resolved = resolved
	ctx.params = req.params

	# Spend mana (SIM)
	if api.has_method("spend_mana_for_card"):
		if !bool(api.call("spend_mana_for_card", req.source_id, card)):
			return false

	# Emit “card played” hook once
	if api.has_method("on_card_played"):
		api.call("on_card_played", ctx)

	var any := false
	for action: CardAction in card.actions:
		if action == null:
			continue
		if action.activate_sim(ctx):
			any = true

	return any
