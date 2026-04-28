# summon_pop_presentation_order.gd

class_name SummonPopPresentationOrder extends PresentationOrder

var summoned_id: int = 0
var group_index: int = -1
var insert_index: int = -1
var after_order_ids: PackedInt32Array = PackedInt32Array()
var summon_spec: Dictionary = {}
var summon_sound_uid: String = ""
