# card_catalog.gd

class_name CardCatalog extends Resource

@export var templates: Array[CardData] = []
var by_uid: Dictionary = {} # String -> CardData

func make_instance(template: CardData) -> CardData:
	if template == null:
		return null
	var c := template.duplicate(true) as CardData
	c.base_proto_path = template.resource_path
	c.ensure_uid()
	return c

#func build_index() -> void:
	#by_uid.clear()
	#for c in cards:
		#if c == null: continue
		#assert(!by_uid.has(c.uid), "duplicate card uid %s" % c.uid)
		#by_uid[c.uid] = c

func get_card(uid: String) -> CardData:
	return by_uid.get(uid, null)
