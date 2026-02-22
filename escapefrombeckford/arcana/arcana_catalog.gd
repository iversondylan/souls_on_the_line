# arcana_catalog.gd
class_name ArcanaCatalog extends Resource

@export var arcana: Array[Arcanum] = []

var by_id: Dictionary = {}			# StringName -> Arcanum
var by_type: Dictionary = {}		# int (Arcanum.Type) -> Array[Arcanum]

func build_index() -> void:
	by_id.clear()
	by_type.clear()

	for a: Arcanum in arcana:
		if !a:
			continue

		var id := a.get_id()
		assert(id != &"", "Arcanum with empty id: %s" % a.resource_path)
		assert(!by_id.has(id), "Duplicate arcanum id: %s" % id)

		by_id[id] = a

		var t := int(a.type)
		if !by_type.has(t):
			by_type[t] = []
		(by_type[t] as Array).append(a)


func get_proto(id: StringName) -> Arcanum:
	return by_id.get(id, null)


func has_id(id: StringName) -> bool:
	return by_id.has(id)


func get_all() -> Array[Arcanum]:
	return arcana


func get_by_type(t: int) -> Array[Arcanum]:
	# Returns prototypes matching type; safe empty array if none.
	var arr : Array[Arcanum] = by_type.get(int(t), null)
	if arr == null:
		return []
	return arr


func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.resize(by_id.size())
	var i := 0
	for k in by_id.keys():
		ids[i] = k
		i += 1
	return ids
