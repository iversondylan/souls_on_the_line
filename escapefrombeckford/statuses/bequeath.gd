class_name BequeathStatus extends Status

const ID := &"bequeath"


func get_id() -> StringName:
	return ID


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Bequeath: on death, draw %s card%s." % [intensity, "" if int(intensity) == 1 else "s"]


func on_death(ctx: SimStatusContext, dead_id: int, _killer_id: int, _reason: String) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.runtime == null:
		return
	if int(dead_id) != int(ctx.owner_id):
		return

	var amount := maxi(int(ctx.get_intensity()), 0)
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
