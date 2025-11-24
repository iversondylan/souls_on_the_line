class_name Arcana extends Resource

@export var arcana: Array[Arcanum]

func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for arcanum: Arcanum in arcana:
		ids.push_back(arcanum.id)
	return ids
		
