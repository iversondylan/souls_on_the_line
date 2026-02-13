# summon_context.gd
class_name SummonContext extends RefCounted

var group_index: int = 0
var insert_index: int = 0

var summon_data: CombatantData = null
var bound_card_data: CardData = null

var sfx: Sound = null

# outputs (filled by LiveBattleAPI; sim can fill only ids if you want)
var summoned_id: int = 0
var summoned_fighter: Fighter = null
