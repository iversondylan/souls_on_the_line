# fighter_state.gd

class_name FighterState extends RefCounted

var combat_id: int
var data: CombatantData              # duplicated per sim
var status_grid: StatusGrid          # data-side grid, not node-side
var ai_state: Dictionary = {}
var ai_rng_state: Dictionary = {}    # seed + index / RNG
