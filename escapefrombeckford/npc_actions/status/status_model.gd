# status_model.gd
class_name StatusModel
extends ParamModel

@export var status_scene: Resource
@export var intensity: int = 1
@export var duration: int = 1
#@export var stack_type: Status.StackType = Status.StackType.INTENSITY
#@export var expiration_policy: Status.ExpirationPolicy = Status.ExpirationPolicy.EVENT_OR_NEVER

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !status_scene:
		return ctx
	
	ctx.params[NPCKeys.STATUS_SCENE] = status_scene
	ctx.params[NPCKeys.STATUS_INTENSITY] = intensity
	ctx.params[NPCKeys.STATUS_DURATION] = duration
	#ctx.params[NPCKeys.STATUS_STACK_TYPE] = stack_type
	#ctx.params[NPCKeys.STATUS_EXPIRATION_POLICY] = expiration_policy
	return ctx
