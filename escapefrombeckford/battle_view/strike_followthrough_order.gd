# strike_followthrough_order

class_name StrikeFollowthroughOrder extends RefCounted

var duration: float = 0.20

var attacker_id: int = 0
var target_ids: Array[int] = []

var attack_mode: int = Attack.Mode.MELEE

# attack-level multiplicity
var strike_count: int = 1
var strike_index: int = 0
var total_hit_count: int = 1
var has_lethal_hit: bool = false

# ordered strike data for animators
var attack_info: AttackPresentationInfo = null

# “wide snap”
var x_scale: float = 1.22
var y_scale: float = 0.90

# small shake on snap (pixels)
var shake_px: float = 6.0

# how much of duration is the snap vs recover
var snap_ratio: float = 0.25
