class_name StatusMutationResult
extends RefCounted

var changed: bool = false
var status_id: StringName = &""
var op: int = 0

var before_pending: bool = false
var after_pending: bool = false
var before_token_id: int = 0
var after_token_id: int = 0

var before_stacks: int = 0
var after_stacks: int = 0
var delta_stacks: int = 0

func apply_to_status_context(ctx: StatusContext) -> void:
	if ctx == null:
		return
	ctx.op = int(op) as Status.OP
	ctx.before_pending = bool(before_pending)
	ctx.after_pending = bool(after_pending)
	ctx.before_token_id = int(before_token_id)
	ctx.after_token_id = int(after_token_id)
	ctx.before_stacks = int(before_stacks)
	ctx.after_stacks = int(after_stacks)
	ctx.delta_stacks = int(delta_stacks)
