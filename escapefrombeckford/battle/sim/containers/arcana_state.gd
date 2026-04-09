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
	var charges: int = 0
	var cooldown: int = 0
	var data: Dictionary = {} # arbitrary per-arcanum state (intensity, flags, etc.)

	func _init(_id: StringName = &"") -> void:
		id = _id

# Ordered list = deterministic activation order
var list: Array[ArcanumEntry] = []

# Fast lookup
var by_id: Dictionary = {} # StringName -> ArcanumEntry

func clear() -> void:
	list.clear()
	by_id.clear()

func add_arcanum(id: StringName) -> ArcanumEntry:
	if id == &"":
		return null
	if by_id.has(id):
		return by_id[id]
	var e := ArcanumEntry.new(id)
	list.append(e)
	by_id[id] = e
	return e

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

func has_arcanum(id: StringName) -> bool:
	return by_id.has(id)

func get_entry(id: StringName) -> ArcanumEntry:
	return by_id.get(id, null)

func clone() -> ArcanaState:
	var c := ArcanaState.new()
	for entry: ArcanumEntry in list:
		if entry == null:
			continue

		var entry_clone := ArcanumEntry.new(entry.id)
		entry_clone.charges = entry.charges
		entry_clone.cooldown = entry.cooldown
		entry_clone.data = entry.data.duplicate(true)

		c.list.append(entry_clone)
		c.by_id[entry_clone.id] = entry_clone

	return c
