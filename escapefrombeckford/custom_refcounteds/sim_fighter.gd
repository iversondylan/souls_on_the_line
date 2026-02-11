# sim_fighter.gd

class_name SimFighter extends RefCounted

var combat_id: int = -1
var group: int = 0
var team: int = 0
var alive: bool = true
var statuses: StatusGridData
var modifier_system: SimModifierSystem
# SimFighter needs numeric stats (health/armor/max_health), not just statuses.
# This could possibly be a shallower variant of CombatantData.

# Debug / identity
var debug_name: String = ""
var role: String = "" # "player", "enemy", "summon", "fighter"

func is_alive() -> bool:
	return alive
