# arcana.gd

class_name Arcana extends Resource

##To populate the list of all arcana at
##the generated arcanum catalog / reward pool outputs, run the EditorScript at
##res://tools/editor/upkeep_run_me.gd
##.

@export var arcana: Array[Arcanum]

func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for arcanum: Arcanum in arcana:
		ids.push_back(String(arcanum.get_id()))
	return ids
	
