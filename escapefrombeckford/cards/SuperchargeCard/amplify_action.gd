# amplify_action.gd
extends CardAction

@export var amplify_duration: int = 2
@export var amplify_sound: Sound = preload("res://audio/supercharge_application.tres")

#func activate(ctx: CardActionContext) -> bool:
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	#var effect := StatusEffect.new()
	#effect.targets = targets
	#effect.sound = amplify_sound
#
	## ID-based request
	#effect.status_id = AmplifyStatus.ID
	#effect.duration = amplify_duration
	## (optional) effect.intensity = 1
#
	## (optional) source is nice for logs / procs
	#effect.source = ctx.player if ctx and ctx.player else null
#
	#effect.execute(ctx.battle_scene.api)
	#return true

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null or ctx.api == null or ctx.resolved == null:
		return false

	var any := false
	for i in range(ctx.resolved.fighter_ids.size()):
		var tid := int(ctx.resolved.fighter_ids[i])
		if tid <= 0:
			continue
		if ctx.api.has_method("is_alive") and !bool(ctx.api.call("is_alive", tid)):
			continue

		var s := StatusContext.new()
		s.source_id = int(ctx.source_id)
		s.target_id = tid
		s.status_id = AmplifyStatus.ID
		s.duration = int(amplify_duration)
		s.intensity = 1

		# Optional: carry sound/tag info if your SIM event logger supports it
		# s.sound = amplify_sound
		# s.tags = [...]

		ctx.api.apply_status(s)
		any = true

	if any:
		ctx.affected_ids = ctx.resolved.fighter_ids.duplicate()

	return any

func description_arity() -> int:
	return 2

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [floori(AmplifyStatus.MULT_VALUE * 100), amplify_duration]
