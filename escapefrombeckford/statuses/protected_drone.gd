class_name ProtectedDroneStatus extends Status

const ID := &"protected_drone"
const FIRE_ANT_DATA := preload("res://combatants/critters/FireAnt/fire_ant_data.tres")
const EXPLOSIVE_DEPARTURE := preload("res://statuses/explosive_departure.tres")
const SMALL := preload("res://statuses/small.tres")
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Protected Drone: On Death, summon a Fire Ant here. It has On Death: deal 3 damage to all enemies."


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
	summon_ctx.summon_data = FIRE_ANT_DATA.duplicate(true)
	summon_ctx.mortality = CombatantState.Mortality.WILD
	summon_ctx.reason = "protected_drone"
	summon_ctx.origin_card_uid = String(removal_ctx.origin_card_uid)
	summon_ctx.origin_arcanum_id = removal_ctx.origin_arcanum_id
	ctx.api.runtime.run_summon_action(summon_ctx)

	if int(summon_ctx.summoned_id) <= 0 or EXPLOSIVE_DEPARTURE == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(summon_ctx.summoned_id)
	status_ctx.status_id = EXPLOSIVE_DEPARTURE.get_id()
	status_ctx.intensity = 3
	ctx.api.apply_status(status_ctx)
	
	status_ctx = StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(summon_ctx.summoned_id)
	status_ctx.status_id = SMALL.get_id()
	ctx.api.apply_status(status_ctx)
