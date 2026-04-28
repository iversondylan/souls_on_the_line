class_name FreshwaterSpringStatus extends Status

const ID := &"freshwater_spring"
const CREATIVE_POTENCY := preload("res://statuses/creative_potency.tres")

func get_id() -> StringName:
	return ID

func get_tooltip(stacks: int = 0) -> String:
	return "Freshwater Spring: On death, your next summon enters with +%s|+%s." % [stacks, stacks]

func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var stacks := maxi(int(ctx.get_stacks()), 0)
	if stacks <= 0:
		return

	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = player_id
	status_ctx.status_id = CREATIVE_POTENCY.get_id()
	status_ctx.stacks = stacks
	status_ctx.reason = "freshwater_spring"
	ctx.api.apply_status(status_ctx)
