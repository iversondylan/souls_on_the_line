class_name StatusMutationResult
extends RefCounted


var changed: bool = false
var status_id: StringName = &""
var op: int = 0

var before_pending: bool = false
var after_pending: bool = false
var before_token_id: int = 0
var after_token_id: int = 0

var before_intensity: int = 0
var before_duration: int = 0
var after_intensity: int = 0
var after_duration: int = 0
var delta_intensity: int = 0
var delta_duration: int = 0


func apply_to_status_context(ctx: StatusContext) -> void:
	if ctx == null:
		return
	ctx.op = int(op)
	ctx.before_pending = bool(before_pending)
	ctx.after_pending = bool(after_pending)
	ctx.before_token_id = int(before_token_id)
	ctx.after_token_id = int(after_token_id)
	ctx.before_intensity = int(before_intensity)
	ctx.before_duration = int(before_duration)
	ctx.after_intensity = int(after_intensity)
	ctx.after_duration = int(after_duration)
	ctx.delta_intensity = int(delta_intensity)
	ctx.delta_duration = int(delta_duration)
