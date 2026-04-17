class_name CreativeFlowStatus extends Status

const ID := &"creative_flow"


func get_id() -> StringName:
	return ID


func affects_card_cost() -> bool:
	return true


func get_card_cost_discount(ctx: SimStatusContext, card: CardData) -> int:
	if ctx == null or !ctx.is_valid() or !_is_eligible_card(card):
		return 0
	return maxi(int(ctx.get_intensity()), 0)


func consume_on_card_play(_ctx: SimStatusContext, card: CardData) -> bool:
	return _is_eligible_card(card)


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Creative Flow: the next Soul card you play costs %s less." % maxi(intensity, 0)


func _is_eligible_card(card: CardData) -> bool:
	if card == null:
		return false
	return (
		int(card.card_type) == int(CardData.CardType.SOULBOUND)
		or int(card.card_type) == int(CardData.CardType.SOULWILD)
	)
