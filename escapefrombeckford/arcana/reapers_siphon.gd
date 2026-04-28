# reapers_siphon.gd

class_name ReapersSiphonArcanum extends Arcanum

const ID := &"reapers_siphon"
const STARTING_STACKS := 3


func get_id() -> StringName:
	return ID


func seed_battle_entry(entry: ArcanumEntry) -> void:
	if entry == null:
		return
	entry.stacks = STARTING_STACKS


func listens_for_any_death() -> bool:
	return true


func on_any_death(ctx: SimArcanumContext, removal_ctx: RemovalContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or removal_ctx == null:
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.group_index) != int(SimBattleAPI.FRIENDLY):
		return

	var next_stacks := int(ctx.get_stacks())
	if next_stacks < 0:
		next_stacks = STARTING_STACKS
	next_stacks -= 1

	if next_stacks > 0:
		ctx.set_stacks(next_stacks)
		return

	ctx.set_stacks(STARTING_STACKS)

	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0 or ctx.api.runtime == null:
		return

	var draw_ctx := DrawContext.new()
	draw_ctx.source_id = player_id
	draw_ctx.amount = 1
	draw_ctx.reason = "reapers_siphon"
	ctx.api.runtime.run_draw_action(draw_ctx)
