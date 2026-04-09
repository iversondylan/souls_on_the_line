# removal_presentation_order.gd

class_name RemovalPresentationOrder extends PresentationOrder

const Removal = preload("res://core/keys_values/removal_values.gd")

var target_id: int = 0
var group_index: int = -1
var after_order_ids: PackedInt32Array = PackedInt32Array()
var removal_type: int = Removal.Type.DEATH
