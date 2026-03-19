# summon_windup_presentation_order.gd

class_name SummonWindupPresentationOrder extends PresentationOrder

var summoned_id: int = 0
var group_index: int = -1
var insert_index: int = -1
var before_order_ids: PackedInt32Array = PackedInt32Array()
var summon_spec: Dictionary = {}
