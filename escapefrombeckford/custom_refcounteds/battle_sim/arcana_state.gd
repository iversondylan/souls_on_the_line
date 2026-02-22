# arcana_state.gd
class_name ArcanaState extends RefCounted

# Headless ownership + per-arcana runtime fields.
# Keep it light: no Resources, no Nodes.
#
# Store either:
# - arcana_id: StringName (preferred)
# - proto_path: String (if you author them as .tres and want to load in Live only)
#
# In headless, you typically want arcana_id + a catalog outside the state.

class ArcanumEntry extends RefCounted:
	var id: StringName
	var type: int # Arcanum.Type enum int
	var charges: int = 0
	var cooldown: int = 0
	var data: Dictionary = {} # arbitrary per-arcanum state (stacks, flags, etc.)

	func _init(_id: StringName = &"", _type: int = -1) -> void:
		id = _id
		type = _type

# Ordered list = deterministic activation order
var list: Array[ArcanumEntry] = []

# Fast lookup
var by_id: Dictionary = {} # StringName -> ArcanumEntry

func clear() -> void:
	list.clear()
	by_id.clear()

func add_arcanum(id: StringName, type: int) -> void:
	if id == &"":
		return
	if by_id.has(id):
		return
	var e := ArcanumEntry.new(id, type)
	list.append(e)
	by_id[id] = e

func remove_arcanum(id: StringName) -> void:
	if !by_id.has(id):
		return
	var e: ArcanumEntry = by_id[id]
	by_id.erase(id)
	# remove from list
	for i in range(list.size()):
		if list[i] == e:
			list.remove_at(i)
			break

func get_by_type(type: int) -> Array[ArcanumEntry]:
	var out: Array[ArcanumEntry] = []
	for e: ArcanumEntry in list:
		if e and e.type == type:
			out.append(e)
	return out

func has_arcanum(id: StringName) -> bool:
	return by_id.has(id)

func get_entry(id: StringName) -> ArcanumEntry:
	return by_id.get(id, null)
