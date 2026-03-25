# discard_action.gd
class_name DiscardAction extends CardAction

@export var base_discard: int = 1

#func activate(ctx: CardActionContext) -> bool:
	#var discard_effect := DiscardEffect.new()
	#discard_effect.amount = base_discard
	#discard_effect.source = ctx.player
	#discard_effect.execute(ctx.battle_scene.api)
	#return true

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var n := maxi(int(base_discard), 0)
	if n == 0:
		return true

	# Require uid so VIEW can associate this request with the card play if desired.
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()

	var req := DiscardRequest.new()
	var scope_id := 0
	if ctx.card_scope_handle != null:
		scope_id = int(ctx.card_scope_handle.scope_id)
	req.request_id = scope_id * 100 + int(ctx.current_action_index) + 1
	req.source_id = int(ctx.source_id)
	req.amount = n
	req.reason = "card_action:discard"
	req.card_uid = String(ctx.card_data.uid) if ctx.card_data != null else ""
	req.card_ctx = ctx
	req.action_index = int(ctx.current_action_index)
	ctx.waiting_async_request_id = int(req.request_id)

	if !(ctx.api as SimBattleAPI).request_player_discard(req):
		ctx.waiting_async_request_id = 0
		return false

	return true

func waits_for_async_resolution_after_activate_sim(_ctx: CardContext) -> bool:
	return maxi(int(base_discard), 0) > 0

func description_arity() -> int:
	return 1

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [base_discard]
