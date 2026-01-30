class_name StatusOnSummonedAction extends CardAction

@export var status: Status

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.summoned_fighters
	if targets.is_empty():
		return false
	
	var status_effect := StatusEffect.new()
	status_effect.targets = targets
	
	var new_status := status.duplicate()
	
	status_effect.status = new_status
	status_effect.execute()

	return true
