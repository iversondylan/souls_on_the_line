# battle_query_ctx.gd
#
# Lightweight read-only context that wraps BattleState for query-only code paths
# (modifier-token resolution, effective-status enumeration, etc.).
#
# Use this in place of a full SimBattleAPI when no write operations (writer,
# runtime, checkpoint) are needed.  Eliminates the per-call SimBattleAPI
# allocation and the circular data-layer → service-layer import it would create.

class_name BattleQueryCtx extends RefCounted

var state: BattleState


func _init(_state: BattleState = null) -> void:
	state = _state


func get_unit(id: int) -> CombatantState:
	return state.get_unit(id) if state != null else null


## Returns the group/team index (0 = FRIENDLY, 1 = ENEMY) for the given
## combat-id, or -1 if not found.
func get_group(id: int) -> int:
	var u := get_unit(id)
	return int(u.team) if u != null else -1


## Returns the player_id stored on the FRIENDLY group (index 0), or 0 if
## no state / group is present.
func get_player_id() -> int:
	if state == null or state.groups.is_empty():
		return 0
	return int(state.groups[0].player_id)
