# status_pop_presentation_order.gd

class_name StatusPopPresentationOrder extends PresentationOrder

var source_id: int = 0
var target_id: int = 0
var status_id: StringName = &""
var pending: bool = false
var op: int = 0
var stacks: int = 0
var presentation_mode: StringName = &"full_status"
var embedded_in_summon: bool = false
