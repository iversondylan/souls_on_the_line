class_name EntangledVotaryGrowthStatus extends Status

const ID := &"entangled_votary_growth"
const EMPTY_FORTITUDE := preload("res://statuses/empty_fortitude.tres")

func get_id() -> StringName:
	return ID

func listens_for_player_turn_begin() -> bool:
	return true

func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or EMPTY_FORTITUDE == null:
		return
	if int(player_id) != int(ctx.api.get_player_id()):
		return
	if !ctx.owner.is_alive():
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = EMPTY_FORTITUDE.get_id()
	status_ctx.stacks = 2
	status_ctx.reason = "entangled_votary_growth"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "At the end of each round, gain +2 Empty Fortitude."
