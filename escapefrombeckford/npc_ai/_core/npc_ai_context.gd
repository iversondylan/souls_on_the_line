# npc_ai_context.gd
class_name NPCAIContext extends RefCounted

# stable
var api: SimBattleAPI
var runtime: SimRuntime
#var combatant: Fighter
var cid: int = -1
var combatant_state: CombatantState
var combatant_data: CombatantData
#var battle_scene: BattleScene
var rng: RNG
var state: Dictionary      # persistent AI state

# per-effect
var params: Dictionary = {}
var forecast: bool = false
var preview_package_index: int = -1
