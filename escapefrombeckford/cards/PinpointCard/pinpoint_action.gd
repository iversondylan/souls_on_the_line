extends CardAction

#const PINPOINT_STATUS := preload("res://statuses/pinpoint.tres")

@export var duration: int = 2
@export var sound: Sound = preload("res://audio/pinpoint_buzz.tres")

#func activate(ctx: CardActionContext) -> bool:
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	#var status_effect := StatusEffect.new()
	#status_effect.targets = targets
#
	##var pinpoint_status := PINPOINT_STATUS.duplicate()
	##pinpoint_status.expiration_policy = Status.ExpirationPolicy.DURATION
	#status_effect.duration = duration
	#
	#status_effect.sound = sound
	#status_effect.status_id = PinpointStatus.ID
	#status_effect.execute(ctx.battle_scene.api)
#
	#return true

func activate_sim(ctx: CardContext) -> bool:
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
		s.status_id = PinpointStatus.ID
		s.duration = int(duration)
		#s.intensity = 1

		# Optional: s.sound = sound
		ctx.api.apply_status(s)
		any = true

	if any:
		ctx.affected_ids = ctx.resolved.fighter_ids.duplicate()

	return any

func description_arity() -> int:
	return 2

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [floori(PinpointStatus.MULT_VALUE * 100), duration]
