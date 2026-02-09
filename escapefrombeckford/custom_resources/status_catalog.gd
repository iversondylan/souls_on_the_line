# status_catalog.gd
class_name StatusCatalog extends Resource

@export var statuses: Array[Status] = []

var by_id: Dictionary = {}

func build_index() -> void:
	by_id.clear()
	for s in statuses:
		if s and s.id != "":
			print(s.id)
			by_id[s.id] = s

func get_proto(id: String) -> Status:
	return by_id.get(id, null)
