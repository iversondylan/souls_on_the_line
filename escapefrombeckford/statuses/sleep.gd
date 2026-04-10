# sleep.gd

class_name SleepStatus extends Status

const ID := &"sleep"

func get_id() -> StringName:
	return ID

func should_skip_npc_action(ctx: SimStatusContext) -> bool:
	if ctx == null or !ctx.is_valid() or !ctx.is_alive():
		return false
	if ctx.api == null:
		return false
	if int(ctx.owner_id) == int(ctx.api.get_player_id()):
		return false
	return int(ctx.get_duration()) > 0

func get_tooltip(_intensity: int = 0, duration: int = 0) -> String:
	if duration == 1:
		return "Sleep: skips this NPC's next action. No effect on the player."
	return "Sleep: skips this NPC's actions for %s turns. No effect on the player." % duration
