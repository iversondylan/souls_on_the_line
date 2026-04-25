# draw_action.gd
class_name DrawAction extends CardAction

@export var base_draw: int = 1
@export var conditional_key: StringName = &""
@export var invert_condition: bool = false

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null:
		return false
	if !_should_draw(ctx):
		return true
	var draw_ctx := DrawContext.new()
	draw_ctx.amount = int(base_draw)
	draw_ctx.source_id = int(ctx.api.get_player_id())
	draw_ctx.reason = "CardAction"
	ctx.runtime.run_draw_action(draw_ctx)
	return true

func get_description_value(_ctx: CardActionContext) -> String:
	return str(int(base_draw))

#func get_modular_description(_ctx: CardActionContext) -> String:
	#var base_text: String = "Draw %s."
	#return base_text % base_draw

func _should_draw(ctx: CardContext) -> bool:
	if StringName(conditional_key) == &"":
		return true
	if ctx == null:
		return false
	var condition_met := bool(ctx.params.get(conditional_key, false))
	return !condition_met if bool(invert_condition) else condition_met
