class_name AxiomaticStatus extends Status

const ID := &"axiomatic"
const AXIOM_DATA := preload("res://combatants/critters/Axiom/axiom_data.tres")


func get_id() -> StringName:
	return ID


func get_tooltip(_stacks: int = 0) -> String:
	return "Axiomatic: On death before your next turn, summon a 3|3 Wild Axiom here."


func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.runtime == null or ctx.owner == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return
	if int(ctx.owner.team) != int(SimBattleAPI.FRIENDLY):
		return

	var summon_ctx := SummonContext.new()
	summon_ctx.actor_id = int(ctx.owner_id)
	summon_ctx.source_id = int(ctx.owner_id)
	summon_ctx.group_index = int(removal_ctx.group_index)
	summon_ctx.insert_index = maxi(int(removal_ctx.insert_index), 0)
	summon_ctx.summon_data = AXIOM_DATA.duplicate(true)
	summon_ctx.mortality = CombatantState.Mortality.WILD
	summon_ctx.reason = "axiomatic"
	summon_ctx.origin_card_uid = String(removal_ctx.origin_card_uid)
	summon_ctx.origin_arcanum_id = removal_ctx.origin_arcanum_id
	ctx.api.runtime.run_summon_action(summon_ctx)
