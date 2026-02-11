# amplify_action.gd

extends CardAction

const AMPLIFY_STATUS := preload("res://statuses/amplify.tres")

@export var amplify_duration: int = 2
@export var amplify_sound: Sound = preload("res://audio/supercharge_application.tres")

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var amplify_status := AMPLIFY_STATUS.duplicate()
	amplify_status.duration = amplify_duration
	status_effect.sound = amplify_sound
	status_effect.status = amplify_status
	status_effect.execute(BattleAPI.new())

	return true

func description_arity() -> int:
	return 2

func get_description_values(_ctx: CardActionContext) -> Array:
	return [floori(AmplifyStatus.MULT_VALUE*100), amplify_duration]
