# card_action_context_sim.gd

class_name CardActionContextSim extends RefCounted

var api: SimBattleAPI
var card_data: CardData
var source_card: UsableCard
var source_id: int = 0

var resolved: CardResolvedTargetSim
var params: Dictionary = {}         # play request params merged here

# Optional outputs
var affected_ids: PackedInt32Array = PackedInt32Array()
var summoned_ids: PackedInt32Array = PackedInt32Array()
var insert_index: int
# If you want consistent RNG for effects
var rng_seed: int = 0
var emitted_card_played: bool = false
