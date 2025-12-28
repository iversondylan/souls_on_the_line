# block_action.gd
class_name BlockAction extends NPCAction

@export var n_armor: int = 5
#@export var resolve_delay: float = 0.6

func perform(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if !fighter:
		return

	var block_effect := BlockEffect.new()
	block_effect.targets = [fighter]
	block_effect.n_armor = n_armor
	block_effect.sound = sound
	block_effect.execute()

	resolve_after_delay(ctx)

func get_intent_values(_ctx: NPCAIContext) -> Dictionary:
	return { "armor": n_armor }

func get_tooltip(_ctx: NPCAIContext) -> String:
	return "[center]This character will gain %s armor.[/center]" % n_armor

func is_performable(_ctx: NPCAIContext) -> bool:
	return true
