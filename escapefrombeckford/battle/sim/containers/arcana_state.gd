# arcana_state.gd
class_name ArcanaState extends RefCounted

const ArcanumEntry := preload("res://battle/sim/containers/arcanum_entry.gd")

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

		var entry_clone := entry.clone() as ArcanumEntry

		c.list.append(entry_clone)
		c.by_id[entry_clone.id] = entry_clone

	return c
