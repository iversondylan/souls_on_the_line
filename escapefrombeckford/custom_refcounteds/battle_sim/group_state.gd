# group_state.gd

class_name GroupState extends RefCounted

# Ordered front->back list of combat ids
var order: PackedInt32Array = PackedInt32Array()

# Optional: track that the player is “the anchor” for friendly group
var player_id: int = 0

func index_of(id: int) -> int:
	return order.find(id)

func front_id(units: Dictionary) -> int:
	for id in order:
		var u: CombatantState = units.get(id)
		if u and u.alive:
			return id
	return 0
	
