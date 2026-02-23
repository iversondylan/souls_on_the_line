# card_catalog.gd

class_name CardCatalog extends Resource

@export var templates: Array[CardData] = []
var by_id: Dictionary = {} # int -> CardData

func make_instance(template: CardData) -> CardData:
	if template == null:
		return null
	var c := template.duplicate(true) as CardData
	c.base_proto_path = template.resource_path
	c.ensure_uid()
	return c

#func build_index() -> void:
	#by_id.clear()
	#for c in cards:
		#if c == null: continue
		#assert(!by_id.has(c.id), "duplicate card id %s" % c.id)
		#by_id[c.id] = c

func get_card(id: int) -> CardData:
	return by_id.get(id, null)
