# fade_context.gd
class_name FadeContext extends RefCounted

var actor_id: int = 0
var group_index: int = -1
var reason: String = "fade"
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""

var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()
var faded: bool = false
