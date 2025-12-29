class_name NPCSpreeModel extends Resource

@export var state_key: String = "spree"

func get_spree(ctx: NPCAIContext) -> int:
	return int(ctx.state.get(state_key, 0))

func increment(ctx: NPCAIContext) -> void:
	ctx.state[state_key] = get_spree(ctx) + 1

func reset(ctx: NPCAIContext) -> void:
	ctx.state[state_key] = 0
