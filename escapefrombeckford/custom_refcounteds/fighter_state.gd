# fighter_state.gd

class_name FighterState extends RefCounted

var combat_id: int
var data: CombatantData              # duplicated per sim
var status_grid: StatusGrid          # data-side grid, not node-side
var status_grid_data: StatusGridData
var ai_state: Dictionary = {}
var rng: RNG    # seed + index / RNG
