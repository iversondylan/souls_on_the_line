# ranged_fire_presentation_order.gd

class_name RangedFirePresentationOrder extends PresentationOrder

var strike_index: int = 0
var strikes_total: int = 1
var total_hit_count: int = 1
var has_lethal: bool = false
var projectile_scene_path: String = ""
var chained_from_previous: bool = false
var origin_strike_index: int = -1
var chain_source_target_id: int = 0
var has_chain_continuation: bool = false
