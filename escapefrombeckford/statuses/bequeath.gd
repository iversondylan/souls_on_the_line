class_name BequeathStatus extends Status

const ID := &"bequeath"
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func get_tooltip(stacks: int = 0) -> String:
	return "Bequeath: On Death, Draw %s." % stacks


func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.runtime == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var amount := maxi(int(ctx.get_stacks()), 0)
	if amount <= 0:
		return

	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0:
		return

	var disable_until_next_player_turn := true
	var runtime := ctx.api.runtime
	if runtime != null and runtime.turn_engine != null:
		disable_until_next_player_turn = int(runtime.turn_engine.current_actor_id) != int(player_id)

	var draw_ctx := DrawContext.new()
	draw_ctx.source_id = player_id
	draw_ctx.amount = amount
	draw_ctx.reason = "bequeath"
	draw_ctx.disable_until_next_player_turn = disable_until_next_player_turn
	runtime.run_draw_action(draw_ctx)
