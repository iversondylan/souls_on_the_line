extends CardAction

const MARKED_STATUS := preload("res://statuses/marked.tres")

@export var duration: int = 2

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var marked_status := MARKED_STATUS.duplicate()
	marked_status.duration = duration

	status_effect.status = marked_status
	status_effect.execute()

	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [duration]
