# card_executor.gd
class_name CardExecutor extends RefCounted

static func play_card(api: SimBattleAPI, req: CardPlayRequest) -> bool:
	print("card_executor.gd play_card() called but is deprecated")
	return false
	#if api == null or req == null or req.card == null:
		#return false
#
	#var card := req.card
	#card.ensure_uid()
#
	#var resolved := CardTargeting.resolve(api, card, req)
#
	#var ctx := CardActionContextSim.new()
	#ctx.api = api
	#ctx.card_data = card
	#ctx.source_id = req.source_id
	#ctx.insert_index = req.insert_index
	#ctx.resolved = resolved
	#ctx.params = req.params
	#
	#api.on_card_played(ctx)
	#
	#if !api.spend_mana_for_card(req.source_id, card):
		#return false
	#
	#var any := false
	#for action: CardAction in card.actions:
		#if action == null:
			#continue
		#if action.activate_sim(ctx):
			#any = true
#
	#api.on_card_finished(ctx)
	#return any
