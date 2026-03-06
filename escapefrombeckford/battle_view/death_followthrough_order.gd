# death_followthrough_order.gd
class_name DeathFollowThroughOrder extends RefCounted

var duration: float = 0.12
var dead_id: int = 0
var group_index: int = -1
var after_order_ids: PackedInt32Array = PackedInt32Array()
