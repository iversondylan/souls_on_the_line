
class_name EncounterGotoStepAction extends EncounterAction

@export var step_id: StringName = &""

func execute(ctx: EncounterRuleContext) -> void:
	if ctx == null or ctx.director == null or step_id == &"":
		return
	ctx.director.goto_step(step_id)
