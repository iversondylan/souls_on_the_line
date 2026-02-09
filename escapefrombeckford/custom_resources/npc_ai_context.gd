# npc_ai_context.gd
class_name NPCAIContext extends RefCounted

# stable
var combatant: Fighter
var combatant_data: CombatantData
var battle_scene: BattleScene
var rng: AIRNG
var state: Dictionary      # persistent AI state

# per-effect
var params: Dictionary = {}
var forecast: bool = false
