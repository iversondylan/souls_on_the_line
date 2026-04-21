# status_applied_order.gd 

class_name StatusAppliedOrder extends RefCounted

var duration: float = 0.0

var source_id: int = 0
var target_id: int = 0
var status_id: StringName = &""
var pending: bool = false
var before_pending: bool = false
var after_pending: bool = false
var before_token_id: int = 0
var after_token_id: int = 0
var stacks: int = 1
