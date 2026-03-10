# discard_action.gd
class_name DiscardAction extends CardAction

@export var base_discard: int = 1

func activate(ctx: CardActionContext) -> bool:
	var discard_effect := DiscardEffect.new()
	discard_effect.amount = base_discard
	discard_effect.source = ctx.player
	discard_effect.execute(ctx.battle_scene.api)
	return true

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var n := maxi(int(base_discard), 0)
	if n == 0:
		return true

	# Require uid so VIEW can associate this request with the card play if desired.
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()

	var req := DiscardRequest.new()
	req.source_id = int(ctx.source_id)
	req.amount = n
	req.reason = "card_action:discard"
	req.card_uid = String(ctx.card_data.uid) if ctx.card_data != null else ""

	(ctx.api as SimBattleAPI).request_player_discard(req)
	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [base_discard]
