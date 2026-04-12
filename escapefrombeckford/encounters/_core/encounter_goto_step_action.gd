extends "res://encounters/_core/encounter_action.gd"
class_name EncounterGotoStepAction

@export var step_id: StringName = &""

func execute(ctx) -> void:
	if ctx == null or ctx.director == null or step_id == &"":
		return
	ctx.director.goto_step(step_id)
