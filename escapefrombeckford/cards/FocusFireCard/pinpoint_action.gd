extends CardAction

const PINPOINT_STATUS := preload("res://statuses/pinpoint.tres")

@export var duration: int = 2

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var pinpoint_status := PINPOINT_STATUS.duplicate()
	pinpoint_status.duration = duration

	status_effect.status = pinpoint_status
	status_effect.execute()

	return true

func description_arity() -> int:
	return 2

func get_description_values(_ctx: CardActionContext) -> Array:
	return [floori(PinpointStatus.MULT_VALUE * 100), duration]
