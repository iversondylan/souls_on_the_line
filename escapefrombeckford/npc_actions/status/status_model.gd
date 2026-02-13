# status_model.gd
class_name StatusModel
extends ParamModel

@export var status: Status
@export var intensity: int = 1
@export var duration: int = 1

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !status:
		return ctx

	ctx.params[NPCKeys.STATUS_ID] = StringName(status.get_id())
	ctx.params[NPCKeys.STATUS_INTENSITY] = intensity
	ctx.params[NPCKeys.STATUS_DURATION] = duration
	return ctx
