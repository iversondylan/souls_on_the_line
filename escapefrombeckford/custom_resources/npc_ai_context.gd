# npc_ai_context.gd
class_name NPCAIContext extends RefCounted

# stable
var api: BattleAPI
var combatant: Fighter
var cid: int = -1
var combatant_state: CombatantState
var combatant_data: CombatantData
var battle_scene: BattleScene
var rng: RNG
var state: Dictionary      # persistent AI state

# per-effect
var params: Dictionary = {}
#var param_models: Array[ParamModel] = [] # and this?
var forecast: bool = false
