# meta-name: CardAction
# meta-description: Create a card action (context-driven)

extends CardAction

@export_group("Action Parameters")
# Example parameters — delete or replace
@export var base_value: int = 0

# -------------------------------------------------
# EXECUTION
# -------------------------------------------------
func activate(ctx: CardActionContext) -> bool:
	# Always pull targets from the resolved context
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	# Example effect (replace with your real logic)
	var effect := DamageEffect.new()
	effect.targets = targets
	effect.n_damage = base_value
	effect.sound = ctx.card_data.sound
	effect.execute()

	return true


# -------------------------------------------------
# DESCRIPTION CONTRACT
# -------------------------------------------------
# Number of %s placeholders this action consumes
func description_arity() -> int:
	return 1


# Values to inject into the description
# Must return EXACTLY description_arity() values
func get_description_values(ctx: CardActionContext) -> Array:
	return [base_value]
