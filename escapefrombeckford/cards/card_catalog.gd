# card_catalog.gd

class_name CardCatalog extends Resource

@export var cards: Array[CardData] = []
var by_id: Dictionary = {} # int -> CardData

func build_index() -> void:
	by_id.clear()
	for c in cards:
		if c == null: continue
		assert(!by_id.has(c.id), "duplicate card id %s" % c.id)
		by_id[c.id] = c

func get_card(id: int) -> CardData:
	return by_id.get(id, null)
