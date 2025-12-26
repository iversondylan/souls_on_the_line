extends CardAction

const CRUEL_DOMINION_STATUS := preload("res://statuses/cruel_dominion.tres")

@export var cruel_dominion_intensity: int = 2

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var status_effect := StatusEffect.new()
	status_effect.targets = targets

	var cruel_dominion := CRUEL_DOMINION_STATUS.duplicate()
	cruel_dominion.intensity = cruel_dominion_intensity

	status_effect.status = cruel_dominion
	status_effect.sound = ctx.card_data.sound
	status_effect.execute()

	return true


func get_description(_ctx: CardActionContext, base_text: String) -> String:
	return get_unmod_description(base_text)


func get_unmod_description(base_text: String) -> String:
	return base_text % str(cruel_dominion_intensity)
