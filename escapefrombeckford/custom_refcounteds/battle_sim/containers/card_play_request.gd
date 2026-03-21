# card_play_request.gd

class_name CardPlayRequest extends RefCounted

var source_id: int = 0
var card: CardData
var source_card: UsableCard

# “resolved target” payload for sim
var target_ids: PackedInt32Array = PackedInt32Array()
#var combatant_datas: Array[CombatantData] = []
var insert_index: int = -1

# Optional extra params
var params: Dictionary = {}
