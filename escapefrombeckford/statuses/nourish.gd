class_name NourishStatus extends Status

const ID := &"nourish"
const MOST_DAMAGED_ALLY_TARGET_MODEL := preload("res://npc_ai/status/most_damaged_ally_status_target_model.gd")

func get_id() -> StringName:
	return ID

func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or removal_ctx == null:
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var amount := maxi(int(ctx.get_stacks()), 0)
	if amount <= 0:
		return

	var target_id: int = MOST_DAMAGED_ALLY_TARGET_MODEL.find_target_id_for_actor(ctx.api, int(ctx.owner_id), false, true)
	if target_id <= 0:
		return

	var heal_ctx := HealContext.new(int(ctx.owner_id), target_id, amount, 0.0, 0.0)
	ctx.api.heal(heal_ctx)

func get_tooltip(stacks: int = 0) -> String:
	return "Nourish: On death, heal your most damaged ally for %s." % stacks
