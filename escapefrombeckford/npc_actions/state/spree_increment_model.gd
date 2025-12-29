class_name SpreeIncrementModel extends NPCStateModel

@export var key := "attack_spree"
@export var amount := 1

func on_perform(ctx: NPCAIContext) -> void:
	ctx.state[key] = ctx.state.get(key, 0) + amount
