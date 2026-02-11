# summon_context.gd

class_name SummonContext extends RefCounted

var battle_scene: BattleScene # live-only convenience for now (can be removed later)
var group_index: int = 0
var insert_index: int = 0

var summon_data: CombatantData = null
var bound_card_data: CardData = null

var sfx: Sound = null

# outputs
var summoned_id: int = 0
var summoned_fighter: Fighter = null
