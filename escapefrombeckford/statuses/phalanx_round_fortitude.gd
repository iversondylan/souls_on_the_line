class_name PhalanxRoundFortitudeStatus extends Status

const ID := &"phalanx_round_fortitude"
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")

func get_id() -> StringName:
	return ID

func listens_for_player_turn_begin() -> bool:
	return true

func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or FULL_FORTITUDE == null:
		return
	if int(player_id) != int(ctx.api.get_player_id()):
		return
	if ctx.owner == null or !ctx.owner.is_alive():
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = FULL_FORTITUDE.get_id()
	status_ctx.stacks = 2
	status_ctx.reason = "spirit_keeper"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "Spirit Keeper: at the end of each round, gain +2 full max health."
