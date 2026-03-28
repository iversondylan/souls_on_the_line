# arcana.gd

class_name Arcana extends Resource

##To populate the list of all arcana at
##res://arcana/arcana_catalog.tres
##, run the EditorScript at
##res://tools/editor/rebuild_arcana_catalog.gd
##.

@export var arcana: Array[Arcanum]

func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for arcanum: Arcanum in arcana:
		ids.push_back(String(arcanum.get_id()))
	return ids
		
