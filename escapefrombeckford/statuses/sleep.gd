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
	return int(ctx.get_stacks()) > 0

func get_tooltip(stacks: int = 0) -> String:
	if stacks == 1:
		return "Sleep: this NPC skips its next action. No effect on the player."
	return "Sleep: this NPC skips actions for %s turns. No effect on the player." % stacks
