extends CardAction

const AMPLIFY_STATUS := preload("res://statuses/amplify.tres")

@export var amplify_duration: int = 2

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var amplify_status := AMPLIFY_STATUS.duplicate()
	amplify_status.stack_type = Status.StackType.DURATION
	amplify_status.duration = amplify_duration
	amplify_status.can_expire = true

	status_effect.status = amplify_status
	status_effect.execute()

	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [duration]
