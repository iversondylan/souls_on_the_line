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


func get_description(description: String, _target_fighter: Fighter = null) -> String:
	return description % [
		str(floori(PinpointStatus.MULT_VALUE * 100)),
		str(duration)
	]


func get_unmod_description(description: String) -> String:
	return description % [
		str(floori(PinpointStatus.MULT_VALUE * 100)),
		str(duration)
	]
