# strike_presentation_info.gd
class_name StrikePresentationInfo extends RefCounted

var strike_index: int = 0

# normalized timing within the enclosing phase
var t0_ratio: float = 0.0
var t1_ratio: float = 1.0

# targets declared by the STRIKE event
var target_ids: Array[int] = []

# ordered resolved hits for this strike
var hits: Array[HitPresentationInfo] = []

var hit_count: int = 0
var has_lethal_hit: bool = false
