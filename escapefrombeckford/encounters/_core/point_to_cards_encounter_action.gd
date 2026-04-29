class_name PointToCardsEncounterAction extends EncounterAction

enum CardQuery {
	OVERLOADED_HAND_CARDS,
}

@export var card_query: CardQuery = CardQuery.OVERLOADED_HAND_CARDS
@export var offset: Vector2 = Vector2(0, -90)
@export var clear_existing: bool = true

func execute(ctx: EncounterRuleContext) -> void:
	if ctx == null or ctx.battle == null:
		return
	match int(card_query):
		CardQuery.OVERLOADED_HAND_CARDS:
			ctx.battle.point_encounter_arrows_to_overloaded_hand_cards(offset, clear_existing)
