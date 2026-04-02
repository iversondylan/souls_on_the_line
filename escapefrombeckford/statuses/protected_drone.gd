class_name ProtectedDroneStatus extends Status

const ID := &"protected_drone"
const FIRE_ANT_DATA := preload("res://combatants/critters/FireAnt/fire_ant_data.tres")
const EXPLOSIVE_PARTING := preload("res://statuses/explosive_parting.tres")


func get_id() -> StringName:
	return ID


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Protected Drone: on death, summon a Fire Ant in this slot and give it 3 Explosive Parting."


func on_death(ctx: SimStatusContext, dead_id: int, _killer_id: int, _reason: String) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.runtime == null or ctx.owner == null:
		return
	if int(dead_id) != int(ctx.owner_id):
		return
	if int(ctx.owner.team) != int(SimBattleAPI.FRIENDLY):
		return

	var death_reaction := ctx.get_active_on_death_reaction()
	if death_reaction == null:
		return

	var summon_ctx := SummonContext.new()
	summon_ctx.actor_id = int(ctx.owner_id)
	summon_ctx.source_id = int(ctx.owner_id)
	summon_ctx.group_index = int(death_reaction.group_index)
	summon_ctx.insert_index = maxi(int(death_reaction.insert_index), 0)
	summon_ctx.summon_data = FIRE_ANT_DATA.duplicate(true)
	summon_ctx.mortality = CombatantState.Mortality.DEPLETE
	summon_ctx.reason = "protected_drone"
	summon_ctx.origin_card_uid = String(death_reaction.origin_card_uid)
	summon_ctx.origin_arcanum_id = death_reaction.origin_arcanum_id
	ctx.api.runtime.run_summon_action(summon_ctx)

	if int(summon_ctx.summoned_id) <= 0 or EXPLOSIVE_PARTING == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(summon_ctx.summoned_id)
	status_ctx.status_id = EXPLOSIVE_PARTING.get_id()
	status_ctx.intensity = 3
	ctx.api.apply_status(status_ctx)
