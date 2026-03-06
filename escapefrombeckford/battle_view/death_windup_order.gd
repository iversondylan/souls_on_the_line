# death_windup_order.gd
class_name DeathWindupOrder extends RefCounted

var duration: float = 0.12
var dead_id: int = 0

# visuals
var to_black: bool = true
var black_amount: float = 1.0 # if you later do partial dimming

var shrink: float = 1.0
var slump_px: float = 0.0
