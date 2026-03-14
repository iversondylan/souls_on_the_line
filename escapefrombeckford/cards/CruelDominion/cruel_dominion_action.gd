extends CardAction

#const CRUEL_DOMINION_STATUS := preload("res://statuses/cruel_dominion.tres")

@export var cruel_dominion_intensity: int = 2
@export var sound: Sound = preload("res://audio/haunting_gloom.tres")


#func activate(ctx: CardActionContext) -> bool:
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	#var status_effect := StatusEffect.new()
	#status_effect.targets = targets
#
	##var cruel_dominion := CRUEL_DOMINION_STATUS.duplicate()
	#status_effect.intensity = cruel_dominion_intensity
#
	#status_effect.status_id = CruelDominionStatus.ID
	#status_effect.sound = sound
	#status_effect.execute(ctx.battle_scene.api)
#
	#return true


func description_arity() -> int:
	return 1


#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [cruel_dominion_intensity]
