# group_state.gd

class_name GroupState extends RefCounted

# Ordered front->back list of combat ids
var order: PackedInt32Array = PackedInt32Array()

# Optional: track player anchor
var player_id: int = -1

func index_of(id: int) -> int:
	return order.find(id)

func add(id: int, insert_index: int = -1) -> void:
	if id <= 0:
		return
	if order.has(id):
		return
	if insert_index < 0 or insert_index > order.size():
		order.append(id)
	else:
		order.insert(insert_index, id)

func remove(id: int) -> void:
	var idx := order.find(id)
	if idx != -1:
		order.remove_at(idx)
	if player_id == id:
		player_id = 0

func front_id(units: Dictionary) -> int:
	for id in order:
		var u: CombatantState = units.get(id)
		if u and u.alive and u.health > 0:
			return id
	return 0

func clone() -> GroupState:
	var g := GroupState.new()
	g.order = order.duplicate()
	g.player_id = player_id
	return g
