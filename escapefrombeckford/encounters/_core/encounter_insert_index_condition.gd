
class_name EncounterInsertIndexCondition extends EncounterCondition

@export var accepted_indices: PackedInt32Array = PackedInt32Array()

func evaluate_match(ctx) -> bool:
	if ctx == null or accepted_indices.is_empty():
		return false
	return accepted_indices.has(ctx.get_insert_index())
