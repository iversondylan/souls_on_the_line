# combatant_state.gd

class_name CombatantState extends RefCounted

var id: int
var team: int  # 0 friendly, 1 enemy (you can keep team==group for now)
var alive: bool = true

# Stats (data-only)
var name: String
var max_health: int
var health: int
var armor: int
var mana_r: int
var mana_g: int
var mana_b: int

# Authoring refs (do NOT duplicate heavy resources in sim unless needed)
var data_proto_path: String # or ResourceUID, or reference to CombatantData prototype

# Systems (data-side)
var statuses: StatusState = StatusState.new()
var modifiers: ModifierCache = ModifierCache.new()

# AI (data-side)
var ai_state: Dictionary # AIState = AIState.new()

# RNG stream (deterministic per unit)
var rng: RNG
