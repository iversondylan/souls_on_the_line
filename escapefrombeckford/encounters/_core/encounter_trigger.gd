class_name EncounterTrigger extends Resource

@export var id: StringName = &""
@export var once: bool = true
@export var conditions: Array[EncounterCondition] = []
@export var actions: Array[EncounterAction] = []
