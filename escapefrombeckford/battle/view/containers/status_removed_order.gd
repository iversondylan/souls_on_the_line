# status_removed_order.gd 

class_name StatusRemovedOrder extends RefCounted

var duration: float = 0.0

var source_id: int = 0
var target_id: int = 0
var status_id: StringName = &""
var pending: bool = false
var intensity: int = 1
var removed_all: bool = false
