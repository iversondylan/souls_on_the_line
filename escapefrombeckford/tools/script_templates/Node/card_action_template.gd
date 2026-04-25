# meta-name: CardAction
# meta-description: Create a card action (context-driven)

extends CardAction

@export_group("Action Parameters")
# Example parameters — delete or replace
@export var base_value: int = 0

# -------------------------------------------------
# EXECUTION
# -------------------------------------------------
#func activate(ctx: CardActionContext) -> bool:
	## Always pull targets from the resolved context
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	## Example effect (replace with real logic)
	#var effect := DamageEffect.new()
	#effect.targets = targets
	#effect.n_damage = base_value
	#effect.sound = ctx.card_data.sound
	#effect.execute(ctx.battle_scene.api)
#
	#return true


# -------------------------------------------------
# DESCRIPTION CONTRACT
# -------------------------------------------------
# Return the one value this action injects into a card description.
# If the card template runs out of `%s`, the base overflow marker is appended.
func get_description_value(_ctx: CardActionContext) -> String:
	return str(base_value)
