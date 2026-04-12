class_name EncounterDefinition extends Resource

@export var initial_step_id: StringName = &""
@export var initial_flags: Dictionary = {}
@export var no_shuffle: bool = false
@export var steps: Array[EncounterStep] = []
@export var triggers: Array[EncounterTrigger] = []

func get_step_by_id(step_id: StringName) -> EncounterStep:
	for step in steps:
		if step != null and step.id == step_id:
			return step
	return null
