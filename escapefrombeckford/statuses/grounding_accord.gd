class_name GroundingAccordStatus extends Status

const ID := &"grounding_accord"
const ABSORB := preload("res://statuses/absorb.tres")
const STATE_ROUND := &"grounding_accord_round"
const STATE_CONVOCATIONS_THIS_ROUND := &"grounding_accord_convocations_this_round"
const STATE_TRIGGERED_THIS_ROUND := &"grounding_accord_triggered_this_round"

func get_id() -> StringName:
	return ID

func listens_for_player_turn_begin() -> bool:
	return true

func listens_for_card_played() -> bool:
	return true

func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if int(player_id) != int(ctx.api.get_player_id()):
		return
	_reset_round_state(ctx)

func on_card_played(ctx: SimStatusContext, source_id: int, card: CardData) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or card == null:
		return
	if int(source_id) != int(ctx.api.get_player_id()):
		return
	if int(card.card_type) != int(CardData.CardType.CONVOCATION):
		return

	ctx.ensure_ai_state()
	_sync_round_state(ctx)
	var convocation_count := int(ctx.owner.ai_state.get(STATE_CONVOCATIONS_THIS_ROUND, 0)) + 1
	ctx.owner.ai_state[STATE_CONVOCATIONS_THIS_ROUND] = convocation_count

	if convocation_count != 2:
		return
	if bool(ctx.owner.ai_state.get(STATE_TRIGGERED_THIS_ROUND, false)):
		return
	if ABSORB == null:
		return

	ctx.owner.ai_state[STATE_TRIGGERED_THIS_ROUND] = true

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = ABSORB.get_id()
	status_ctx.stacks = 1
	status_ctx.reason = "grounding_accord_second_convocation"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "Grounding Accord: when you play your second Convocation each round, gain Absorb."

func _sync_round_state(ctx: SimStatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.state == null:
		return
	ctx.ensure_ai_state()
	var current_round := int(ctx.api.state.turn.round_number)
	var stored_round := int(ctx.owner.ai_state.get(STATE_ROUND, -1))
	if stored_round == current_round:
		return
	ctx.owner.ai_state[STATE_ROUND] = current_round
	ctx.owner.ai_state[STATE_CONVOCATIONS_THIS_ROUND] = 0
	ctx.owner.ai_state[STATE_TRIGGERED_THIS_ROUND] = false

func _reset_round_state(ctx: SimStatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.state == null:
		return
	ctx.ensure_ai_state()
	ctx.owner.ai_state[STATE_ROUND] = int(ctx.api.state.turn.round_number)
	ctx.owner.ai_state[STATE_CONVOCATIONS_THIS_ROUND] = 0
	ctx.owner.ai_state[STATE_TRIGGERED_THIS_ROUND] = false
