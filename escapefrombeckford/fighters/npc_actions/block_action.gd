# block_action.gd
class_name BlockAction extends NPCAction

@export var n_armor: int = 5
@export var delay_seconds: float = 0.6

func perform(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if !fighter:
		return

	var block_effect := BlockEffect.new()
	block_effect.targets = [fighter]
	block_effect.n_armor = n_armor
	block_effect.sound = sound
	block_effect.execute()

	# Delay resolution (matches your old timing)
	if delay_seconds > 0.0:
		fighter.get_tree().create_timer(delay_seconds, false).timeout.connect(
			func():
				fighter.resolve_action()
		)
	else:
		fighter.resolve_action()

func get_intent_values(ctx: NPCAIContext) -> Dictionary:
	return {
		"armor": n_armor
	}

func get_tooltip(ctx: NPCAIContext) -> String:
	return "[center]This character will gain %s armor.[/center]" % n_armor

func is_performable(ctx: NPCAIContext) -> bool:
	return true
