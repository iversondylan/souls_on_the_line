# pressure_barrier_action.gd

extends CardAction

const PRESSURE_BARRIER_STATUS := preload("res://statuses/pressure_barrier.tres")

@export var pressure_barrier_intensity: int = 2
@export var amplify_sound: Sound# = preload("res://audio/supercharge_application.tres")

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var pressure_barrier_status := PRESSURE_BARRIER_STATUS.duplicate()
	#amplify_status.stack_type = Status.StackType.DURATION
	#amplify_status.duration = amplify_duration
	#amplify_status.expiration_policy = Status.ExpirationPolicy.DURATION
	pressure_barrier_status.intensity = pressure_barrier_intensity
	status_effect.sound = amplify_sound
	status_effect.status = pressure_barrier_status
	status_effect.execute()

	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [pressure_barrier_intensity]
