# card_context.gd

class_name CardContext extends RefCounted

var api: SimBattleAPI
var runtime: SimRuntime
var source_id: int = 0
var card_data: CardData
var source_card: UsableCard

# resolved targeting / placement
var target_ids: PackedInt32Array = PackedInt32Array()
var insert_index: int = -1
var params: Dictionary = {}

# action bookkeeping
var action_states: Array[CardActionExecutionState] = []
var next_action_index: int = 0

# outputs accumulated over time
var affected_ids: PackedInt32Array = PackedInt32Array()
var summoned_ids: PackedInt32Array = PackedInt32Array()

# card lifecycle
var emitted_card_played: bool = false
var mana_spent: bool = false
var canceled: bool = false
var finished: bool = false
