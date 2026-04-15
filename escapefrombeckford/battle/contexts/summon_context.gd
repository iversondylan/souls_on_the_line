# summon_context.gd
class_name SummonContext extends RefCounted

var actor_id: int = 0
var group_index: int = 0
var insert_index: int = 0
var source_id: int = -1
var summon_data: CombatantData = null
var bound_card_data: CardData = null
var mortality: CombatantState.Mortality = CombatantState.Mortality.MORTAL

var sfx: Sound = null

# outputs (filled by LiveBattleAPI; sim can fill only ids if you want)
var summoned_id: int = 0
var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()
#var summoned_fighter: Fighter = null
#var before_order_ids: Array[int] = []
#var after_order_ids: Array[int] = []
var reason: String = ""
var bound_card_uid: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var origin_card_type: int = -1
var eligible_player_soul_summon: bool = false
# Optional snapshot used ONLY for windup positioning.
# For normal summon: leave empty.
# For summon-replace: set this to the order BEFORE the replaced unit was removed in SIM.
var windup_order_ids: PackedInt32Array = PackedInt32Array()
