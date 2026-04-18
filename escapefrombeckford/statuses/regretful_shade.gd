class_name RegretfulShadeStatus extends Status

const ID := &"regretful_shade"
const REGRETFUL_SHADE_DATA := preload("res://combatants/critters/RegretfulShade/regretful_shade_data.tres")
const FLEETING := preload("res://statuses/fleeting.tres")
const SMALL := preload("res://statuses/small.tres")
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Regretful Shade: On Death, summon a Small, Fleeting 1/1 Regretful Shade here."


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
	summon_ctx.summon_data = REGRETFUL_SHADE_DATA.duplicate(true)
	summon_ctx.mortality = CombatantState.Mortality.HOLLOW
	summon_ctx.reason = "regretful_shade"
	summon_ctx.origin_card_uid = String(removal_ctx.origin_card_uid)
	summon_ctx.origin_arcanum_id = removal_ctx.origin_arcanum_id
	ctx.api.runtime.run_summon_action(summon_ctx)

	if int(summon_ctx.summoned_id) <= 0:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(summon_ctx.summoned_id)
	status_ctx.status_id = SMALL.get_id()
	ctx.api.apply_status(status_ctx)

	status_ctx = StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(summon_ctx.summoned_id)
	status_ctx.status_id = FLEETING.get_id()
	ctx.api.apply_status(status_ctx)
