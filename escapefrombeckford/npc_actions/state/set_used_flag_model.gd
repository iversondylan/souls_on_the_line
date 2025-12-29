class_name SetUsedFlagModel extends NPCStateModel

@export var key := "used"

func on_perform(ctx: NPCAIContext) -> void:
	ctx.state[key] = true
