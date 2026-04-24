class_name SniperStatus extends Status

const ID := &"sniper"

func get_id() -> StringName:
	return ID

func on_action_params_ready(_ctx: SimStatusContext, npc_ctx: NPCAIContext) -> void:
	if npc_ctx == null or npc_ctx.params == null:
		return
	if int(npc_ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) != int(Attack.Mode.RANGED):
		return

	npc_ctx.params[Keys.TARGET_TYPE] = int(Attack.Targeting.REVERSE)

func get_tooltip(_stacks: int = 0) -> String:
	return "Sniper: ranged attacks target in reverse order."
