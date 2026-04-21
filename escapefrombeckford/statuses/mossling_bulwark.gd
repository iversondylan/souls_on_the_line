class_name MosslingBulwarkStatus extends Status

const ID := &"mossling_bulwark"
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")
const MOST_DAMAGED_ALLY_TARGET_MODEL := preload("res://npc_ai/status/most_damaged_ally_status_target_model.gd")

func get_id() -> StringName:
	return ID

func on_apply(ctx: SimStatusContext, _apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or FULL_FORTITUDE == null:
		return

	var target_id := _find_frontmost_ally(ctx)
	if target_id <= 0:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = target_id
	status_ctx.status_id = FULL_FORTITUDE.get_id()
	status_ctx.stacks = 2
	status_ctx.reason = "mossling_bulwark"
	ctx.api.apply_status(status_ctx)

func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or removal_ctx == null:
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var target_id: int = MOST_DAMAGED_ALLY_TARGET_MODEL.find_target_id_for_actor(ctx.api, int(ctx.owner_id), false, true)
	if target_id <= 0:
		return

	var heal_ctx := HealContext.new(int(ctx.owner_id), target_id, 4, 0.0, 0.0)
	ctx.api.heal(heal_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "Mossling Bulwark: On summon, your frontmost ally gains +2 full max health. On death, heal your most damaged ally 4."

func _find_frontmost_ally(ctx: SimStatusContext) -> int:
	if ctx == null or ctx.api == null or ctx.owner == null:
		return 0

	var player_id := int(ctx.api.get_player_id())
	for cid in ctx.api.get_combatants_in_group(int(ctx.owner.team), false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == int(ctx.owner_id) or ally_id == player_id:
			continue

		var ally: CombatantState = ctx.api.state.get_unit(ally_id)
		if ally == null or !ally.is_alive():
			continue
		return ally_id

	return 0
