# card_context.gd

class_name CardContext extends RefCounted

var api: SimBattleAPI
var runtime: SimRuntime
var source_id: int = 0
var card_data: CardData
var source_card: UsableCard

var card_scope_id: int = 0
var card_scope_opened: bool = false
var card_play_committed: bool = false

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
var activation_committed_to_view: bool = false
var emitted_card_played: bool = false
var mana_spent: bool = false
var canceled: bool = false
var finished: bool = false
var current_action_index: int = -1
var escrow_action_index: int = -1
var confirm_action_index: int = -1
var waiting_async_action_index: int = -1
var waiting_async_request_id: int = 0
var interaction_payloads: Dictionary = {} # action_index -> Dictionary
