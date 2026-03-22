# mark_action.gd
extends CardAction

@export var duration: int = 2
@export var sound: Sound = preload("res://audio/mark_zap.tres")


func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var any := false
	var affected: PackedInt32Array = PackedInt32Array()

	for i in range(ctx.target_ids.size()):
		var tid := int(ctx.target_ids[i])
		if tid <= 0:
			continue

		if ctx.api.has_method("is_alive") and !bool(ctx.api.call("is_alive", tid)):
			continue

		var s := StatusContext.new()
		s.source_id = int(ctx.source_id)
		s.target_id = tid
		s.status_id = MarkedStatus.ID
		s.duration = int(duration)
		s.intensity = 1

		ctx.api.apply_status(s)
		any = true
		affected.append(tid)

	if any:
		ctx.affected_ids = affected

	return any



func description_arity() -> int:
	return 1

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [duration]
