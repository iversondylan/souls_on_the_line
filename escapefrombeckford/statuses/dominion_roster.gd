class_name DominionRosterStatus extends Status

const ID := &"dominion_roster"
const MIGHT := preload("res://statuses/might.tres")

func get_id() -> StringName:
	return ID

func on_actor_turn_end(ctx: SimStatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or MIGHT == null:
		return
	if int(ctx.owner_id) != int(ctx.api.get_player_id()):
		return
	if ctx.api.has_played_card_type_this_turn(CardData.CardType.SOULBOUND):
		return
	if ctx.api.has_played_card_type_this_turn(CardData.CardType.SOULWILD):
		return

	for mortality in [CombatantState.Mortality.BOUND, CombatantState.Mortality.WILD]:
		for cid in ctx.api.get_combatants_in_group_by_mortality(int(ctx.owner.team), mortality, false):
			var target_id := int(cid)
			if target_id <= 0:
				continue
			var status_ctx := StatusContext.new()
			status_ctx.source_id = int(ctx.owner_id)
			status_ctx.target_id = target_id
			status_ctx.status_id = MIGHT.get_id()
			status_ctx.stacks = 2
			status_ctx.reason = "dominion_roster"
			ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "At end of your turn, if you played no Soulbound or Soulwild cards this turn, your Soulbound and Soulwild allies gain +2 Might."
