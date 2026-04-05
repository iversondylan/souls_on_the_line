# npc_ai_context.gd
class_name NPCAIContext extends RefCounted

# stable
var api: SimBattleAPI
var runtime: SimRuntime
var cid: int = -1
var combatant_state: CombatantState
var combatant_data: CombatantData
#var battle_scene: BattleScene
var rng: RNG
var state: Dictionary      # persistent AI state

# per-effect
var params: Dictionary = {}
var summoned_ids: PackedInt32Array = PackedInt32Array()
var affected_ids: PackedInt32Array = PackedInt32Array()
var forecast: bool = false
var preview_package_index: int = -1
var action_name: String = ""

func get_actor_id() -> int:
	if combatant_state != null:
		return int(combatant_state.id)
	if int(cid) > 0:
		return int(cid)
	return 0
