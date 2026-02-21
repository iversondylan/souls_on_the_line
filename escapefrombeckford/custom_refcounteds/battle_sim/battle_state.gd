# battle_state.gd

class_name BattleState extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

var battle_seed: int
var run_seed: int

# combat_id -> CombatantState
var units: Dictionary = {}  # int -> CombatantState

# group index -> GroupState
var groups: Array[GroupState] = [GroupState.new(), GroupState.new()]

# Turn model
var turn: TurnState = TurnState.new()

# Shared battle RNG (plus per-unit rng stored on CombatantState if you want)
var rng: RNG
