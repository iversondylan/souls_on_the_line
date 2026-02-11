class_name HealAction extends CardAction

@export var flat_amount : int = 0
@export var of_total : float = 0.0
@export var of_missing : float = 0.0

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false
#
	var heal_effect := HealEffect.new()
	heal_effect.targets = targets
	heal_effect.flat_amount = flat_amount
	heal_effect.of_total = of_total
	heal_effect.of_missing = of_missing
	heal_effect.execute(BattleAPI.new())

	return true
