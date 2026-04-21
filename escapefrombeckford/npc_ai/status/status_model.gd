# status_model.gd
class_name StatusModel
extends ParamModel

@export var status: Status
@export var stacks: int = 1
# Creates the telegraphed pending lane, not a preview-only or quasi-real status.
@export var pending: bool = false

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !status:
		return ctx

	ctx.params[Keys.STATUS_ID] = StringName(status.get_id())
	ctx.params[Keys.STATUS_STACKS] = stacks
	ctx.params[Keys.STATUS_PENDING] = bool(pending)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !status:
		return ctx
	ctx.params[Keys.STATUS_ID] = StringName(status.get_id())
	ctx.params[Keys.STATUS_STACKS] = int(stacks)
	ctx.params[Keys.STATUS_PENDING] = bool(pending)
	return ctx
