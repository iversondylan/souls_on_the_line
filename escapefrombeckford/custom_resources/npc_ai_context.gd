# npc_ai_context.gd
class_name NPCAIContext extends RefCounted

# stable
var combatant: Fighter
var battle_scene: BattleScene
var rng: RandomNumberGenerator
var state: Dictionary      # persistent AI state

# per-effect
var params: Dictionary = {}
var forecast: bool = false
