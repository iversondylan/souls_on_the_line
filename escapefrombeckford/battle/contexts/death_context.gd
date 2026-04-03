# death_context.gd
class_name DeathContext extends RefCounted

var dead_id: int = 0
var killer_id: int = 0
var group_index: int = -1
var reason: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var event_extra := {}

var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()
var died: bool = false
