# npc_ai_context.gd
class_name NPCAIContext extends RefCounted
var combatant: Fighter
var battle_scene: BattleScene
var state: Dictionary      # persistent per-fighter AI state
var rng: RandomNumberGenerator
