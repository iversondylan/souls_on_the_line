class_name JabberCollectorStatus extends Status

const ID := &"jabber_collector"
const BULWARK := preload("res://statuses/bulwark.tres")
const DATA_CONVOCATIONS := &"convocations_this_round"
const DATA_TRIGGERED := &"triggered_this_round"

func get_id() -> StringName:
	return ID

func listens_for_player_turn_begin() -> bool:
	return true

func listens_for_card_played() -> bool:
	return true

func on_apply(ctx: SimStatusContext, _apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid():
		return
	_reset_round_state(ctx, "jabber_collector_apply")

func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if int(player_id) != int(ctx.api.get_player_id()):
		return
	_reset_round_state(ctx, "jabber_collector_reset")

func on_card_played(ctx: SimStatusContext, source_id: int, card: CardData) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or card == null:
		return
	if int(source_id) != int(ctx.api.get_player_id()):
		return
	if int(card.card_type) != int(CardData.CardType.CONVOCATION):
		return

	var convocation_count := ctx.get_token_data_int(DATA_CONVOCATIONS, 0) + 1
	var triggered := ctx.get_token_data_bool(DATA_TRIGGERED, false)
	ctx.set_token_data_value(DATA_CONVOCATIONS, convocation_count, "jabber_collector_count")
	if convocation_count != 2 or triggered:
		return

	ctx.set_token_data_value(DATA_TRIGGERED, true, "jabber_collector_trigger")
	var target_id := _get_frontmost_ally_id(ctx)
	if target_id <= 0:
		return

	var heal_ctx := HealContext.new(int(ctx.owner_id), target_id, 3, 0.0, 0.0)
	ctx.api.heal(heal_ctx)

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = target_id
	status_ctx.status_id = BULWARK.get_id()
	status_ctx.stacks = 10
	status_ctx.reason = "jabber_collector"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "The first time each round you play your second Convocation, heal your frontmost ally 3 and give it Bulwark 10."

func _reset_round_state(ctx: SimStatusContext, reason: String) -> void:
	if ctx == null:
		return
	ctx.set_token_data_dict(
		{
			DATA_CONVOCATIONS: 0,
			DATA_TRIGGERED: false,
		},
		reason
	)

func _get_frontmost_ally_id(ctx: SimStatusContext) -> int:
	if ctx == null or ctx.api == null:
		return 0
	var player_id := int(ctx.api.get_player_id())
	for cid in ctx.api.get_combatants_in_group(int(ctx.owner.team), false):
		var target_id := int(cid)
		if target_id <= 0 or target_id == player_id:
			continue
		var ally := ctx.api.state.get_unit(target_id) if ctx.api.state != null else null
		if ally == null or !ally.is_alive():
			continue
		return target_id
	return 0
