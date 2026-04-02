# fleeting.gd

class_name FleetingStatus extends Status

const ID := &"fleeting"


func get_id() -> StringName:
	return ID


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Fleeting: dies at the start of the player's turn."


func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or !ctx.is_alive() or ctx.owner == null:
		return
	if int(ctx.owner.team) != int(SimBattleAPI.FRIENDLY):
		return
	if int(ctx.owner_id) == int(player_id):
		return
	if int(ctx.owner.mortality) == int(CombatantState.Mortality.MORTAL):
		return

	ctx.kill_self("fleeting_player_turn_start")
