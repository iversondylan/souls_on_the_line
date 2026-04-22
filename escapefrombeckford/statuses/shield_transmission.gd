class_name ShieldTransmissionStatus extends Status

const ID := &"shield_transmission"

func get_id() -> StringName:
	return ID

func listens_for_card_played() -> bool:
	return true

func on_card_played(ctx: SimStatusContext, source_id: int, card: CardData) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or card == null:
		return
	if int(source_id) != int(ctx.api.get_player_id()):
		return
	if int(card.card_type) != int(CardData.CardType.CONVOCATION):
		return
	if !ctx.owner.is_alive():
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = BulwarkStatus.ID
	status_ctx.stacks = 25
	status_ctx.reason = "shield_transmission"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "Shield Transmission: whenever you play a Convocation, gain 25% reduced damage until your next turn."
