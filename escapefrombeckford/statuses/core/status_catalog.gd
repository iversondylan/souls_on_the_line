# status_catalog.gd
class_name StatusCatalog extends Resource

@export var statuses: Array[Status] = []

var by_id: Dictionary = {}

func build_index() -> void:
	by_id.clear()
	for s in statuses:
		if !s:
			continue
		var id := s.get_id()
		assert(id != &"", "Status with empty id: %s" % s.resource_path)
		assert(!by_id.has(id), "Duplicate status id: %s" % id)
		by_id[id] = s

func get_proto(id: StringName) -> Status:
	
	var proto: Status = by_id.get(id, null)
	#print("status_catalog.gd get_proto() status is ", proto.get_id() if proto else &"NULL STATUS")
	return proto
