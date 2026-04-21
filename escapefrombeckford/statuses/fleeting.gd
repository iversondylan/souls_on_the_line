# fleeting.gd

class_name FleetingStatus extends Status

const ID := &"fleeting"
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func get_tooltip(_stacks: int = 0) -> String:
	return "Fleeting: dies at the start of your turn."


func listens_for_player_turn_begin() -> bool:
	return true


func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or !ctx.is_alive() or ctx.owner == null:
		return
	if int(ctx.owner.team) != int(SimBattleAPI.FRIENDLY):
		return
	if int(ctx.owner_id) == int(player_id):
		return
	if int(ctx.owner.mortality) == int(CombatantState.Mortality.MORTAL):
		return

	ctx.request_removal(Removal.Type.DEATH, "fleeting_player_turn_start")
