# removal_windup_order.gd

class_name RemovalWindupOrder extends RefCounted


var duration: float = 0.20
var target_id: int = 0
var removal_type: int = Removal.Type.DEATH

var hit_multiplicity: int = 1
var to_black: bool = true
var black_amount: float = 1.0
var shrink: float = 0.96
var slump_px: float = 10.0
